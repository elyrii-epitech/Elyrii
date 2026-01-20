"""
Elyrii Training Script
======================

This script fine-tunes the Mistral-7B-Instruct-v0.2 model using QLoRA (Quantized Low-Rank Adaptation)
for the Elyrii emotional assistant.

It expects a dataset prepared by `prepare_data.py` containing tokenized chat sessions.
The training uses 8-bit quantization to fit within consumer/cloud GPU VRAM limits (approx 16-24GB).

Usage:
    python train.py --data_dir ./data --output_dir ./output --epochs 3

Attributes:
    model_id (str): The HuggingFace ID of the base model.
"""

import os, torch, argparse
import logging
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    Trainer,
    TrainingArguments,
    DataCollatorForLanguageModeling
)
from peft import (
    LoraConfig,
    get_peft_model,
    prepare_model_for_kbit_training,
    TaskType
)
from datasets import load_from_disk

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

def parse_args() -> argparse.Namespace:
    """Parses command-line arguments for training configuration."""
    parser = argparse.ArgumentParser(description="Fine-tune Mistral-7B for Elyrii")

    parser.add_argument(
        "--epochs",
        type=int,
        default=5,
        help="Number of training epochs."
    )
    parser.add_argument(
        "--lr",
        type=float,
        default=1e-4,
        help="Learning rate."
    )
    parser.add_argument(
        "--batch",
        type=int,
        default=4,
        help="Per-device training batch size."
    )
    parser.add_argument(
        "--grad_acc",
        type=int,
        default=8,
        help="Gradient accumulation steps. (Effective batch = batch * grad_acc)"
    )
    parser.add_argument(
        "--data_dir",
        type=str,
        default="/data",
        help="Directory containing 'train' and 'val' dataset folders."
    )
    parser.add_argument(
        "--output_dir",
        type=str,
        default="/output",
        help="Directory to save checkpoints and the final model."
    )

    return parser.parse_args()

def main():
    """Main training execution flow."""
    args = parse_args()

    model_id = "mistralai/Mistral-7B-v0.2"

    logger.info(f"🚀 Initializing training for {model_id}")
    logger.info(f"📂 Data directory: {args.data_dir}")
    logger.info(f"💾 Output directory: {args.output_dir}")

    tokenizer = AutoTokenizer.from_pretrained(model_id, trust_remote_code=True)

    # Mistral/Llama tokenizers often lack a pad token.
    # Setting it to eos_token as is standard workaround.
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    model = AutoModelForCausalLM.from_pretrained(
        model_id,
        device_map="auto",
        load_in_8bit=True,
        torch_dtype=torch.float16,
    )

    model = prepare_model_for_kbit_training(model)

    # LoRA
    lora_cfg = LoraConfig(
        r=32,
        lora_alpha=64,
        target_modules=["q_proj","v_proj"],
        lora_dropout=0.05,
        bias="none",
        task_type=TaskType.CAUSAL_LM
    )
    model = get_peft_model(model, lora_cfg)
    model.print_trainable_parameters()

    try:
        train_ds = load_from_disk(os.path.join(args.data_dir, "train"))
        val_ds = load_from_disk(os.path.join(args.data_dir, "val"))
    except FileNotFoundError as e:
        logger.error(f"❌ Error loading datasets: {e}")
        logger.error("   Make sure you ran 'prepare_data.py' first.")
        exit(1)

    collator = DataCollatorForLanguageModeling(tokenizer, mlm=False)

    training_args = TrainingArguments(
        output_dir=args.output_dir,
        per_device_train_batch_size=args.batch,
        gradient_accumulation_steps=args.grad_acc,
        learning_rate=args.lr,
        num_train_epochs=args.epochs,
        fp16=True,
        eval_strategy="steps",
        eval_steps=500,
        save_steps=500,
        logging_steps=100,
        load_best_model_at_end=True,
        metric_for_best_model="eval_loss",
        report_to="none",
        save_total_limit=2,
    )

    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=train_ds,
        eval_dataset=val_ds,
        data_collator=collator,
    )

    logger.info("🔥 Starting training...")
    trainer.train()

    final_path = os.path.join(args.output_dir, "final_lora")
    logger.info(f"✅ Training complete. Saving adapter to {final_path}")
    trainer.save_model(final_path)

if __name__ == "__main__":
    main()
