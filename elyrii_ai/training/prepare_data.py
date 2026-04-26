"""
Elyrii Data Preparation Script
==============================

This script processes raw datasets (EmpatheticDialogues, custom CSVs) into
tokenized, chat-formatted examples ready for fine-tuning Mistral-7B-Instruct.

It performs the following steps:
1. Loads raw datasets.
2. Formats them into standard message dictionaries (role/content).
3. Applies the specific chat template for the model (including system prompts).
4. Tokenizes the text.
5. Splits into Train/Validation sets.
6. Saves to disk for efficient loading during training.

Usage:
    # Ensure .env variables are set or exported
    python prepare_data.py --output_dir ./data
"""

import os
import argparse
import functools
import logging
from typing import Dict, Any, List
from datasets import load_dataset, concatenate_datasets
from transformers import AutoTokenizer
from elyrii_ai.prompt.system_prompt import get_system_prompt

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# --- Constants from Environment ---
# Defaults match the .env.local template
MAX_LENGTH = int(os.getenv("MAX_MODEL_LEN", "4096"))
HF_TOKEN = os.getenv("HF_TOKEN")  # Required for gated models on HF hub

SYSTEM_PROMPT = get_system_prompt()


def format_empathetic_dialogues(
    example: Dict[str, Any],
) -> Dict[str, List[Dict[str, str]]]:
    """
    Converts an EmpatheticDialogues row to ChatML-style messages.

    Args:
        example: A dictionary containing 'prompt', 'utterance', and optionally 'context'.

    Returns:
        A dictionary with a 'messages' key containing the conversation history.
    """
    # EmpatheticDialogues structure: 'prompt' (user), 'utterance' (assistant)
    # We prepend the context to the user prompt to give the model more info about the situation.
    user_content = (
        f"{example['prompt']} (Context: {example['context']})"
        if "context" in example
        else example["prompt"]
    )

    return {
        "messages": [
            {"role": "user", "content": user_content},
            {"role": "assistant", "content": example["utterance"]},
        ]
    }


def format_custom_dataset(example):
    """
    Example formatter for a generic CSV/JSON dataset.
    Assumes columns 'instruction' and 'response'.
    """
    return {
        "messages": [
            {"role": "user", "content": example["instruction"]},
            {"role": "assistant", "content": example["response"]},
        ]
    }


def apply_chat_template(
    example: Dict[str, Any], tokenizer: AutoTokenizer
) -> Dict[str, str]:
    """
    Applies the model's chat template to the messages.
    Injects the system prompt into the first user message for Instruct models.

    Args:
        example: Dictionary with 'messages' list.
        tokenizer: The initialized tokenizer.

    Returns:
        Dictionary with 'text' key containing the formatted string.
    """
    messages = example["messages"]

    # Inject System Prompt into the first user message
    # Mistral Instruct v0.2 works best when system instructions are part of the first [INST] block.
    if messages and messages[0]["role"] == "user":
        messages = [msg.copy() for msg in messages]
        messages[0]["content"] = f"{SYSTEM_PROMPT}\n\n{messages[0]['content']}"

    # Apply the tokenizer's template (adds <s>, [INST], [/INST], </s>)
    # We set add_generation_prompt=False because we are training, so we include the assistant's answer.
    formatted_text = tokenizer.apply_chat_template(
        messages, tokenize=False, add_generation_prompt=False
    )

    return {"text": formatted_text}


def tokenize_function(
    examples: Dict[str, List[str]], tokenizer: AutoTokenizer
) -> Dict[str, Any]:
    """
    Tokenizes the text content.
    """
    return tokenizer(
        examples["text"],
        truncation=True,
        max_length=MAX_LENGTH,
        padding=False,  # Dynamic padding in DataCollator is more efficient
    )


def main():
    """Main execution flow for data preparation."""
    parser = argparse.ArgumentParser(description="Prepare dataset for Elyrii training")
    parser.add_argument(
        "--output_dir",
        type=str,
        default="./data",
        help="Where to save the processed dataset",
    )
    parser.add_argument(
        "--model_path",
        type=str,
        default=os.getenv("AI_MODEL", "./model/mistral_7B_instruct_v0.3"),
        help="Path to the base model or HF ID",
    )
    args = parser.parse_args()

    logger.info(f"🏗️  Loading tokenizer: {args.model_path}")
    try:
        tokenizer = AutoTokenizer.from_pretrained(args.model_path, token=HF_TOKEN)
    except OSError as e:
        logger.error(
            f"Failed to load tokenizer for {args.model_path}. Check your path, HF_TOKEN, or internet connection."
        )
        raise e

    # Fix for Mistral tokenizers lacking a default pad_token
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    datasets_to_merge = []

    # 1. Load EmpatheticDialogues (English)
    logger.info("📚 Loading 'empathetic_dialogues'...")
    try:
        ds_en = load_dataset("empathetic_dialogues", split="train")
        ds_en = ds_en.map(
            format_empathetic_dialogues, remove_columns=ds_en.column_names
        )
        datasets_to_merge.append(ds_en)
    except Exception as e:
        logger.warning(f"⚠️  Could not load empathetic_dialogues: {e}")

    # 2. Load Custom/Local Datasets (e.g., French, Portuguese)
    # Uncomment and adapt the following lines when you have your files:
    # if os.path.exists("french_empathy.csv"):
    #     print("📚 Loading local 'french_empathy.csv'...")
    #     ds_fr = load_dataset("csv", data_files="french_empathy.csv", split="train")
    #     ds_fr = ds_fr.map(format_custom_dataset, remove_columns=ds_fr.column_names)
    #     datasets_to_merge.append(ds_fr)

    if not datasets_to_merge:
        logger.error("❌ No datasets loaded. Exiting.")
        return

    # 3. Merge Datasets
    full_dataset = concatenate_datasets(datasets_to_merge)
    logger.info(f"📊 Total examples: {len(full_dataset)}")

    # 4. Apply Chat Template
    logger.info("📝 Applying chat template...")
    full_dataset = full_dataset.map(
        functools.partial(apply_chat_template, tokenizer=tokenizer),
        desc="Formatting chat template",
    )

    # 5. Tokenize
    logger.info("🔢 Tokenizing...")
    cols_to_remove = [
        c
        for c in full_dataset.column_names
        if c not in ["input_ids", "attention_mask", "labels"]
    ]

    tokenized_dataset = full_dataset.map(
        functools.partial(tokenize_function, tokenizer=tokenizer),
        batched=True,
        remove_columns=cols_to_remove,
        desc="Tokenizing",
    )

    # 6. Split and Save
    logger.info("✂️  Splitting Train (90%) / Val (10%)...")
    split_dataset = tokenized_dataset.train_test_split(test_size=0.1, seed=42)

    train_path = os.path.join(args.output_dir, "train")
    val_path = os.path.join(args.output_dir, "val")

    logger.info(f"💾 Saving to {args.output_dir}...")
    split_dataset["train"].save_to_disk(train_path)
    split_dataset["test"].save_to_disk(val_path)

    logger.info("✅ Done! Ready for training.")


if __name__ == "__main__":
    main()
