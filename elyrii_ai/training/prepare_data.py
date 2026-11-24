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
import logging
import json
from typing import Dict, Any, List

from datasets import Dataset
from pathlib import Path
import hashlib
import subprocess
import importlib.metadata
from tqdm import tqdm
from elyrii_ai.training.preprocessing import (
    InvalidExample, format_emobench, filter_english, prepare_source,
    validate_training_messages, grouped_split_indices,
)
from transformers import AutoTokenizer, LlamaTokenizer
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
            if not isinstance(turn, str) or not turn.strip():
                raise InvalidExample("invalid_conversation_turn")
            role = "user" if i % 2 == 0 else "assistant"
            messages.append({"role": role, "content": turn})
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
    
    # The 'dialog' field might be a JSON string or an already-parsed list.
    dialog_data = example.get("dialog", [])
    dialog = []
    if isinstance(dialog_data, str):
        try:
            dialog = json.loads(dialog_data)
        except json.JSONDecodeError:
            raise InvalidExample("invalid_dialog_json")
    elif isinstance(dialog_data, list):
        dialog = dialog_data

    if not isinstance(dialog, list):
        raise InvalidExample("invalid_dialog_type")
        
    for i, turn in enumerate(dialog):
        if not isinstance(turn, dict):
            raise InvalidExample("invalid_dialog_turn")
        # 'usr' is the seeker, 'sys' is the supporter
        speaker = turn.get("speaker", "")
        if speaker not in {"usr", "sys"}:
            raise InvalidExample("unknown_speaker")
        role = "user" if speaker == "usr" else "assistant"
        
        content = turn.get("text", "")
        if not isinstance(content, str) or not content.strip():
            raise InvalidExample("blank_dialog_turn")
        
        # Prepend context to the very first user message
        if i == 0 and role == "user":
            context = f"Problem: {problem_type} | Emotion: {emotion_type} | Situation: {situation}"
            content = f"{content}\n\n(Context: {context})"
            
        messages.append({"role": role, "content": content})
        
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
    validate_training_messages(messages)

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
        add_special_tokens=False,  # The chat template already supplies BOS/EOS.
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
    parser.add_argument(
        "--data_base_dir",
        type=str,
        default="./datasets",
        help="Base directory containing the raw local datasets",
    )
    parser.add_argument("--local_files_only", action="store_true", help="Use cached/local tokenizer files only")
    args = parser.parse_args()
    output = Path(args.output_dir)
    if output.exists():
        raise FileExistsError(f"Use a new output directory; refusing to overwrite {output}")
    import pyarrow.parquet as pq
    source_specs = [
        ("empathetic_dialogues", "Jithendra-k_EmpatheticDialogues/train-00000-of-00001.parquet", format_empathetic_dialogues),
        ("emobench_ea", "SahandSab_EmoBench/EA.jsonl", None),
        ("emobench_eu", "SahandSab_EmoBench/EU.jsonl", None),
        ("esconv", "giliit_esconv/train-00000-of-00001.parquet", format_esconv),
    ]
    examples, reports = [], []
    for source, relative, formatter in source_specs:
        path = Path(args.data_base_dir) / relative
        if not path.is_file():
            raise FileNotFoundError(f"Required source missing: {path}")
        rows = pq.read_table(path).to_pylist() if path.suffix == '.parquet' else [
            json.loads(line) for line in path.read_text().splitlines() if line.strip()
        ]
        accepted, report = prepare_source(rows, source=source, formatter=formatter)
        report.update(path=relative, sha256=hashlib.sha256(path.read_bytes()).hexdigest())
        reports.append(report)
        examples.extend(accepted)
        logger.info("%s: %s accepted rows, %s rejected, %s excluded, %s examples",
                    source, report['accepted_rows'], report['rejected_rows'],
                    report['excluded_rows'], report['accepted_examples'])
    if not examples:
        raise ValueError("No usable training examples")
    tokenizer = LlamaTokenizer.from_pretrained(
        args.model_path, use_fast=False, legacy=False,
        local_files_only=args.local_files_only, token=HF_TOKEN,
    )
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    # Validate and render before tokenization. Every accepted example is checked
    # again at the template boundary, including non-EmoBench sources.
    texts = [apply_chat_template(example, tokenizer)['text']
             for example in tqdm(examples, desc="Rendering validated conversations")]
    data = Dataset.from_dict({'text': texts})
    data = data.map(
        lambda batch: tokenize_function(batch, tokenizer), batched=True,
        remove_columns=['text'], desc="Tokenizing", load_from_cache_file=False,
        keep_in_memory=True,
    )
    indices = grouped_split_indices(examples)
    provenance = []
    for split, selected in indices.items():
        for index in selected:
            provenance.append(dict({k: examples[index][k] for k in
                                    ('example_id','group_id','source','source_row','task')}, split=split))
    project = Path(__file__).resolve().parents[2]
    def git(*arguments):
        return subprocess.check_output(['git', *arguments], cwd=project, text=True).strip()
    code_files = [Path(__file__), Path(__file__).with_name('preprocessing.py')]
    manifest = {
        'preprocessing_version': 2, 'status': 'complete',
        'git_revision': git('rev-parse','HEAD'), 'git_dirty': bool(git('status','--porcelain')),
        'code_sha256': {str(p.relative_to(project)): hashlib.sha256(p.read_bytes()).hexdigest() for p in code_files},
        'sources': reports, 'tokenizer_source': args.model_path,
        'tokenizer_sha256': hashlib.sha256(json.dumps(tokenizer.get_vocab(), sort_keys=True).encode()).hexdigest(),
        'chat_template_sha256': hashlib.sha256(tokenizer.get_chat_template().encode()).hexdigest(),
        'system_prompt_sha256': hashlib.sha256(SYSTEM_PROMPT.encode()).hexdigest(),
        'max_length': MAX_LENGTH, 'truncation': True,
        'split': {'method':'seeded_source_group', 'seed':42, 'validation_group_fraction':0.1,
                  'train_examples':len(indices['train']), 'val_examples':len(indices['val'])},
        'accepted_examples': len(examples), 'empty_assistant_targets': 0,
        'packages': {name: importlib.metadata.version(name) for name in
                     ('datasets','transformers','sentencepiece','pyarrow')},
    }
    output.mkdir(parents=True, exist_ok=False)
    for split, selected in indices.items():
        data.select(selected).save_to_disk(str(output / split))
    with (output/'example_provenance.jsonl').open('w') as handle:
        for row in provenance:
            handle.write(json.dumps(row)+'\n')
    (output/'preprocessing_manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    logger.info("Saved %s train and %s validation examples to %s",
                len(indices['train']), len(indices['val']), output)


if __name__ == "__main__":
    main()
