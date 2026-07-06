"""
Elyrii Training Script
======================

This script fine-tunes a Mistral-7B model using QLoRA (Quantized Low-Rank Adaptation)
for the Elyrii emotional assistant.

It expects a dataset prepared by `prepare_data.py` containing tokenized chat sessions.
The training uses 4-bit quantization to fit within consumer/cloud GPU VRAM limits.

Usage:
    python train.py --data_dir ./data --output_dir ./output

"""

import os, torch, argparse
import numpy as np
import logging
from dataclasses import dataclass
from typing import Any, Dict, List, Sequence

from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    BitsAndBytesConfig,
    Trainer,
    TrainingArguments,
    PreTrainedTokenizerBase,
)
from peft import (
    LoraConfig,
    get_peft_model,
    prepare_model_for_kbit_training,
    TaskType
)
from datasets import load_from_disk
from dotenv import load_dotenv

torch.serialization.add_safe_globals([
    np._core.multiarray._reconstruct,
    np.ndarray,
    np.dtype,
    np.dtypes.UInt32DType,
    np.core.multiarray._reconstruct # Adding the older path just in case
])

# Load environment variables from .env file
load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

LORA_TARGET_PRESETS = {
    "qv": ["q_proj", "v_proj"],
    "attention": ["q_proj", "k_proj", "v_proj", "o_proj"],
    "mlp": ["gate_proj", "up_proj", "down_proj"],
    "all-linear": [
        "q_proj",
        "k_proj",
        "v_proj",
        "o_proj",
        "gate_proj",
        "up_proj",
        "down_proj",
    ],
}


def preferred_compute_dtype() -> torch.dtype:
    if torch.cuda.is_available() and torch.cuda.is_bf16_supported():
        return torch.bfloat16
    return torch.float16


def _find_subsequence(sequence: Sequence[int], pattern: Sequence[int], start: int = 0) -> int:
    """Return the first index of pattern in sequence, or -1 if absent."""
    if not pattern or len(pattern) > len(sequence):
        return -1

    max_start = len(sequence) - len(pattern)
    for idx in range(start, max_start + 1):
        if list(sequence[idx : idx + len(pattern)]) == list(pattern):
            return idx
    return -1


def _find_first_subsequence(
    sequence: Sequence[int], patterns: Sequence[Sequence[int]], start: int = 0
) -> tuple[int, int]:
    """Return the first index and matched length for any pattern."""
    best_idx = -1
    best_len = 0

    for pattern in patterns:
        idx = _find_subsequence(sequence, pattern, start)
        if idx != -1 and (best_idx == -1 or idx < best_idx):
            best_idx = idx
            best_len = len(pattern)

    return best_idx, best_len


@dataclass
class AssistantOnlyDataCollator:
    """Pads examples and masks loss to assistant completions only.

    Mistral Instruct chat templates use [INST] ... [/INST] assistant_text. The
    default language-modeling collator trains on the prompt too, which can make a
    small LoRA overfit template/user tokens and collapse generation. This collator
    only labels tokens after each [/INST] marker until the next [INST] marker.
    """

    tokenizer: PreTrainedTokenizerBase
    label_pad_token_id: int = -100
    train_on_inputs: bool = False

    def __post_init__(self) -> None:
        self.response_template_ids = [
            self.tokenizer.encode(marker, add_special_tokens=False)
            for marker in ("[/INST]", " [/INST]", "[/INST] ", " [/INST] ")
        ]
        self.instruction_template_ids = [
            self.tokenizer.encode(marker, add_special_tokens=False)
            for marker in ("[INST]", " [INST]", "[INST] ", " [INST] ")
        ]

    def __call__(self, features: List[Dict[str, Any]]) -> Dict[str, torch.Tensor]:
        batch = self.tokenizer.pad(
            features,
            padding=True,
            return_tensors="pt",
        )

        input_ids = batch["input_ids"]
        labels = input_ids.clone()

        if self.train_on_inputs:
            labels[batch["attention_mask"] == 0] = self.label_pad_token_id
            batch["labels"] = labels
            return batch

        labels.fill_(self.label_pad_token_id)

        for row_idx, attention_mask in enumerate(batch["attention_mask"]):
            seq_len = int(attention_mask.sum().item())
            ids = input_ids[row_idx, :seq_len].tolist()
            search_from = 0

            while True:
                response_marker, marker_len = _find_first_subsequence(
                    ids, self.response_template_ids, search_from
                )
                if response_marker == -1:
                    break

                response_start = response_marker + marker_len
                next_instruction, _ = _find_first_subsequence(
                    ids, self.instruction_template_ids, response_start
                )
                response_end = next_instruction if next_instruction != -1 else seq_len

                if response_start < response_end:
                    labels[row_idx, response_start:response_end] = input_ids[
                        row_idx, response_start:response_end
                    ]

                search_from = response_end

        batch["labels"] = labels
        return batch


def parse_args() -> argparse.Namespace:
    """Parses command-line arguments for training configuration."""
    parser = argparse.ArgumentParser(description="Fine-tune a Mistral model for Elyrii using QLoRA")

    parser.add_argument(
        "--epochs",
        type=int,
        default=1,
        help="Number of training epochs. Keep low for style/persona LoRAs to avoid response collapse."
    )
    parser.add_argument(
        "--lr",
        type=float,
        default=5e-5,
        help="Learning rate. Lower defaults reduce overfitting and silent LoRA collapse."
    )
    parser.add_argument(
        "--batch",
        type=int,
        default=1,
        help="Per-device training batch size."
    )
    parser.add_argument(
        "--grad_acc",
        type=int,
        default=16,
        help="Gradient accumulation steps. (Effective batch = batch * grad_acc)"
    )
    parser.add_argument(
        "--lora_r",
        type=int,
        default=16,
        help="LoRA rank."
    )
    parser.add_argument(
        "--lora_alpha",
        type=int,
        default=4,
        help="LoRA alpha. Effective adapter scale is lora_alpha / lora_r."
    )
    parser.add_argument(
        "--lora_dropout",
        type=float,
        default=0.10,
        help="LoRA dropout. Higher values make the adapter less brittle on small datasets."
    )
    parser.add_argument(
        "--target_preset",
        type=str,
        default="all-linear",
        choices=sorted(LORA_TARGET_PRESETS.keys()),
        help="LoRA target module preset. 'all-linear' is stronger than q/v but keeps alpha modest."
    )
    parser.add_argument(
        "--target_modules",
        type=str,
        default=None,
        help="Optional comma-separated LoRA target modules. Overrides --target_preset."
    )
    parser.add_argument(
        "--train_on_inputs",
        action="store_true",
        help="Use the old behavior: train loss on prompt/template tokens as well as assistant responses."
    )
    parser.add_argument(
        "--data_dir",
        type=str,
        default="./data",
        help="Directory containing 'train' and 'val' dataset folders."
    )
    parser.add_argument(
        "--output_dir",
        type=str,
        default="./output",
        help="Directory to save checkpoints and the final model."
    )
    parser.add_argument(
        "--model_id",
        type=str,
        default="mistralai/Mistral-7B-Instruct-v0.3",
        help="Hugging Face model ID to fine-tune.",
    )
    parser.add_argument(
        "--resume_from_checkpoint",
        type=str,
        default=None,
        help="Path to a specific checkpoint to resume from (e.g., ./output/checkpoint-3000) or 'True' to find the latest.",
    )

    return parser.parse_args()

def main():
    """Main training execution flow."""
    args = parse_args()

    logger.info(f"Initializing training for model: {args.model_id}")
    logger.info(f"Data directory: {args.data_dir}")
    logger.info(f"Output directory: {args.output_dir}")

    # Use AutoTokenizer for better compatibility
    tokenizer = AutoTokenizer.from_pretrained(args.model_id, use_fast=False)

    # Mistral/Llama tokenizers often lack a pad token.
    # Setting it to eos_token is a standard workaround.
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    # QLoRA configuration using 4-bit quantization
    compute_dtype = preferred_compute_dtype()
    use_bf16 = compute_dtype == torch.bfloat16
    logger.info(f"QLoRA compute dtype: {compute_dtype}")

    quantization_config = BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_quant_type="nf4",
        bnb_4bit_compute_dtype=compute_dtype,
        bnb_4bit_use_double_quant=True,
    )

    model = AutoModelForCausalLM.from_pretrained(
        args.model_id,
        quantization_config=quantization_config,
        device_map="auto",
    )

    # Avoid use_cache warnings and unnecessary memory during gradient checkpointed training.
    model.config.use_cache = False

    # Prepare model for k-bit training (casts layer norms and head to float32 for stability)
    model = prepare_model_for_kbit_training(model)

    if args.target_modules:
        target_modules = [
            module.strip() for module in args.target_modules.split(",") if module.strip()
        ]
    else:
        target_modules = LORA_TARGET_PRESETS[args.target_preset]

    if not target_modules:
        raise ValueError("At least one LoRA target module must be configured.")

    logger.info(f"LoRA target modules: {target_modules}")
    logger.info(f"LoRA effective scale: {args.lora_alpha / args.lora_r:.4f}")

    # LoRA configuration. Defaults are intentionally moderate; targeting all
    # linear transformer projections gives the adapter more capacity without
    # returning to the previous alpha=32 scale that caused response collapse.
    lora_cfg = LoraConfig(
        r=args.lora_r,
        lora_alpha=args.lora_alpha,
        target_modules=target_modules,
        lora_dropout=args.lora_dropout,
        bias="none",
        task_type=TaskType.CAUSAL_LM
    )
    model = get_peft_model(model, lora_cfg)
    model.print_trainable_parameters()

    try:
        train_ds = load_from_disk(os.path.join(args.data_dir, "train"))
        val_ds = load_from_disk(os.path.join(args.data_dir, "val"))
    except FileNotFoundError as e:
        logger.error(f"Error loading datasets: {e}")
        logger.error("   Make sure you ran 'prepare_data.py' first.")
        exit(1)

    collator = AssistantOnlyDataCollator(
        tokenizer=tokenizer,
        train_on_inputs=args.train_on_inputs,
    )

    training_args = TrainingArguments(
        output_dir=args.output_dir,
        per_device_train_batch_size=args.batch,
        gradient_accumulation_steps=args.grad_acc,
        learning_rate=args.lr,
        num_train_epochs=args.epochs,
        fp16=not use_bf16,
        bf16=use_bf16,
        eval_strategy="steps", # Use the correct argument name
        eval_steps=500,
        save_steps=500,
        logging_steps=100,
        load_best_model_at_end=True,
        metric_for_best_model="eval_loss",
        report_to="none",
        save_total_limit=2,
        max_grad_norm=0.3,
        warmup_ratio=0.03,
        lr_scheduler_type="cosine",
    )

    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=train_ds,
        eval_dataset=val_ds,
        data_collator=collator,
    )

    logger.info("Starting training...")

    resume_path = args.resume_from_checkpoint
    if resume_path == "True" or resume_path == "true":
        resume_path = True

    trainer.train(resume_from_checkpoint=resume_path)

    final_path = os.path.join(args.output_dir, "final_lora")
    logger.info(f"Training complete. Saving adapter to {final_path}")
    trainer.save_model(final_path)

if __name__ == "__main__":
    main()
