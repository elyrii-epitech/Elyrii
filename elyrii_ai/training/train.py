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
import logging

from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    BitsAndBytesConfig,
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
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

def parse_args() -> argparse.Namespace:
    """Parses command-line arguments for training configuration."""
    parser = argparse.ArgumentParser(description="Fine-tune a Mistral model for Elyrii using QLoRA")

    parser.add_argument(
        "--epochs",
        type=int,
        default=3,
        help="Number of training epochs."
    )
    parser.add_argument(
        "--lr",
        type=float,
        default=2e-4,
        help="Learning rate."
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

    return parser.parse_args()

def main():
    """Main training execution flow."""
    args = parse_args()

    logger.info(f"🚀 Initializing training for model: {args.model_id}")
    logger.info(f"📂 Data directory: {args.data_dir}")
    logger.info(f"💾 Output directory: {args.output_dir}")

    # Use AutoTokenizer for better compatibility
    tokenizer = AutoTokenizer.from_pretrained(args.model_id, use_fast=False)

    # Mistral/Llama tokenizers often lack a pad token.
    # Setting it to eos_token is a standard workaround.
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    # QLoRA configuration using 4-bit quantization
    quantization_config = BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_quant_type="nf4",
        bnb_4bit_compute_dtype=torch.bfloat16,
        bnb_4bit_use_double_quant=True,
    )

    model = AutoModelForCausalLM.from_pretrained(
        args.model_id,
        quantization_config=quantization_config,
        device_map="auto",
    )

    # Prepare model for k-bit training (casts layer norms and head to float32 for stability)
    model = prepare_model_for_kbit_training(model)

    # LoRA configuration
    lora_cfg = LoraConfig(
        r=16,
        lora_alpha=32,
        target_modules=["q_proj", "v_proj"],
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
        fp16=True, # Use fp16 for mixed-precision training on your GPU
        eval_strategy="steps", # Use the correct argument name
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
