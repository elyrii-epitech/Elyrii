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
import json
from typing import Dict, Any, List
from datasets import load_dataset, concatenate_datasets
from transformers import AutoTokenizer
from elyrii_ai.prompt.system_prompt import get_system_prompt
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

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
    Uses the 'conversation' list if available, or fallback to prompt/utterance.
    """
    messages = []
    
    if "conversation" in example and isinstance(example["conversation"], list) and len(example["conversation"]) > 0:
        # Reconstruct the conversation from the list of strings
        # Assume user starts
        for i, turn in enumerate(example["conversation"]):
            role = "user" if i % 2 == 0 else "assistant"
            messages.append({"role": role, "content": str(turn)})
    else:
        # Fallback to older format or generic columns
        prompt = example.get("prompt", "")
        utterance = example.get("utterance", "")
        context = example.get("context", "")
        
        user_content = (
            f"{prompt} (Context: {context})"
            if context
            else prompt
        )
        
        messages = [
            {"role": "user", "content": user_content},
            {"role": "assistant", "content": utterance},
        ]

    return {"messages": messages}


def format_emobench(
    example: Dict[str, Any],
) -> Dict[str, List[Dict[str, str]]]:
    """
    Converts EmoBench row to ChatML-style messages.
    """
    # Create a descriptive prompt from the scenario and choices
    scenario = example.get("scenario", "")
    choices = example.get("choices", [])
    
    choices_str = "\n".join([f"- {c}" for c in choices])
    
    user_content = (
        f"Scenario: {scenario}\n\n"
        f"What is the best course of action among the following choices?\n"
        f"{choices_str}"
    )
    
    assistant_content = example.get("label", "")
    
    return {
        "messages": [
            {"role": "user", "content": user_content},
            {"role": "assistant", "content": assistant_content},
        ]
    }


def format_esconv(
    example: Dict[str, Any],
) -> Dict[str, List[Dict[str, str]]]:
    """
    Converts ESConv row to ChatML-style messages.
    """
    messages = []
    
    # Context
    situation = example.get("situation", "")
    problem_type = example.get("problem_type", "")
    emotion_type = example.get("emotion_type", "")
    
    # Try to extract the first user message to append the context
    dialog_str = example.get("dialog", "[]")
    try:
        dialog = json.loads(dialog_str)
    except json.JSONDecodeError:
        dialog = []
        
    for i, turn in enumerate(dialog):
        # 'usr' is the seeker, 'sys' is the supporter
        speaker = turn.get("speaker", "")
        role = "user" if speaker == "usr" else "assistant"
        
        content = turn.get("text", "")
        
        # Prepend context to the very first user message
        if i == 0 and role == "user":
            context = f"Problem: {problem_type} | Emotion: {emotion_type} | Situation: {situation}"
            content = f"{content}\n\n(Context: {context})"
            
        messages.append({"role": role, "content": content})
        
    # If the parsing failed or dialog was empty, create a dummy fallback to avoid errors downstream
    if not messages:
        messages = [
            {"role": "user", "content": "Hello."},
            {"role": "assistant", "content": "Hi, how can I help you?"},
        ]
        
    # Mistral's apply_chat_template strictly requires conversation to start with 'user'
    if messages and messages[0]["role"] == "assistant":
        # Insert a dummy user message to satisfy the template constraint
        messages.insert(0, {"role": "user", "content": "Hi."})
        
    return {"messages": messages}


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


def filter_english(example: Dict[str, Any]) -> bool:
    """Filters datasets to keep only English examples (for EmoBench)."""
    if "language" in example:
        return example["language"] == "en"
    return True  # If no language column, assume it's valid


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
    parser.add_argument(
        "--data_base_dir",
        type=str,
        default="./datasets",
        help="Base directory containing the raw local datasets",
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

    # 1. Load EmpatheticDialogues (Local Parquet)
    logger.info("📚 Loading local 'empathetic_dialogues'...")
    ed_path = os.path.join(args.data_base_dir, "Jithendra-k_EmpatheticDialogues", "train-00000-of-00001.parquet")
    if os.path.exists(ed_path):
        try:
            ds_en = load_dataset("parquet", data_files=ed_path, split="train")
            ds_en = ds_en.map(
                format_empathetic_dialogues, remove_columns=ds_en.column_names
            )
            datasets_to_merge.append(ds_en)
        except Exception as e:
            logger.warning(f"⚠️  Could not load empathetic_dialogues: {e}")
    else:
        logger.warning(f"⚠️  Local empathetic_dialogues not found at {ed_path}")

    # 2. Load EmoBench (Local JSONL)
    logger.info("📚 Loading local 'EmoBench'...")
    eb_paths = [
        os.path.join(args.data_base_dir, "SahandSab_EmoBench", "EA.jsonl"),
        os.path.join(args.data_base_dir, "SahandSab_EmoBench", "EU.jsonl")
    ]
    # Filter only existing ones
    eb_paths = [p for p in eb_paths if os.path.exists(p)]
    
    if eb_paths:
        try:
            ds_eb = load_dataset("json", data_files=eb_paths, split="train")
            
            # Filter non-English
            initial_count = len(ds_eb)
            ds_eb = ds_eb.filter(filter_english)
            logger.info(f"Filtered EmoBench from {initial_count} to {len(ds_eb)} rows (English only).")

            ds_eb = ds_eb.map(format_emobench, remove_columns=ds_eb.column_names)
            datasets_to_merge.append(ds_eb)
        except Exception as e:
            logger.warning(f"⚠️  Could not load EmoBench: {e}")
    else:
        logger.warning(f"⚠️  Local EmoBench files not found at {os.path.join(args.data_base_dir, 'SahandSab_EmoBench')}")
        
    # 3. Load ESConv (Local Parquet)
    logger.info("📚 Loading local 'ESConv'...")
    esconv_path = os.path.join(args.data_base_dir, "giliit_esconv", "train-00000-of-00001.parquet")
    if os.path.exists(esconv_path):
        try:
            ds_esconv = load_dataset("parquet", data_files=esconv_path, split="train")
            ds_esconv = ds_esconv.map(format_esconv, remove_columns=ds_esconv.column_names)
            datasets_to_merge.append(ds_esconv)
        except Exception as e:
            logger.warning(f"⚠️  Could not load ESConv: {e}")
    else:
        logger.warning(f"⚠️  Local ESConv not found at {esconv_path}")

    if not datasets_to_merge:
        logger.error("❌ No datasets loaded. Exiting.")
        return

    # Merge Datasets
    full_dataset = concatenate_datasets(datasets_to_merge)
    logger.info(f"📊 Total examples: {len(full_dataset)}")

    # Apply Chat Template
    logger.info("📝 Applying chat template...")
    full_dataset = full_dataset.map(
        functools.partial(apply_chat_template, tokenizer=tokenizer),
        desc="Formatting chat template",
    )

    # Tokenize
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

    # Split and Save
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
