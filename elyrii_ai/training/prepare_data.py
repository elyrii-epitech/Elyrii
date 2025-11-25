import os
import argparse
import functools
from datasets import load_dataset, concatenate_datasets, Dataset
from transformers import AutoTokenizer

# Configuration
MODEL_ID = "mistralai/Mistral-7B-Instruct-v0.2"
MAX_LENGTH = 2048
SYSTEM_PROMPT = (
    "You are Elyrii, an empathetic and non-judgmental emotional assistant. "
    "Your goal is to provide support, listen actively, and help users process "
    "their emotions in a safe space. Always respond with kindness and patience."
)


def format_empathetic_dialogues(example):
    """
    Converts EmpatheticDialogues row to ChatML-style messages.
    """
    # EmpatheticDialogues structure: 'prompt' (user), 'utterance' (assistant)
    # We prepend the context to the user prompt to give the model more info about the situation.
    user_content = f"{example['prompt']} (Context: {example['context']})" if 'context' in example else example['prompt']

    return {
        "messages": [
            {"role": "user", "content": user_content},
            {"role": "assistant", "content": example["utterance"]}
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
            {"role": "assistant", "content": example["response"]}
        ]
    }


def apply_chat_template(example, tokenizer):
    """
    Applies the Mistral Instruct chat template to the messages.
    """
    messages = example["messages"]

    # Inject System Prompt into the first user message
    # Mistral Instruct v0.2 works best when system instructions are part of the first [INST] block.
    if messages and messages[0]["role"] == "user":
        original_content = messages[0]["content"]
        messages[0]["content"] = f"{SYSTEM_PROMPT}\n\n{original_content}"

    # Apply the tokenizer's template (adds <s>, [INST], [/INST], </s>)
    # We set add_generation_prompt=False because we are training, so we include the assistant's answer.
    formatted_text = tokenizer.apply_chat_template(
        messages,
        tokenize=False,
        add_generation_prompt=False
    )

    return {"text": formatted_text}


def tokenize_function(examples, tokenizer):
    return tokenizer(
        examples["text"],
        truncation=True,
        max_length=MAX_LENGTH,
        padding=False,  # Dynamic padding in DataCollator is more efficient
    )


def main():
    parser = argparse.ArgumentParser(description="Prepare dataset for Elyrii training")
    parser.add_argument("--output_dir", type=str, default="./data", help="Where to save the processed dataset")
    args = parser.parse_args()

    print(f"🏗️  Loading tokenizer: {MODEL_ID}")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)

    # Fix for Mistral tokenizers lacking a default pad_token
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    datasets_to_merge = []

    # 1. Load EmpatheticDialogues (English)
    print("📚 Loading 'empathetic_dialogues'...")
    try:
        ds_en = load_dataset("empathetic_dialogues", split="train")
        ds_en = ds_en.map(format_empathetic_dialogues, remove_columns=ds_en.column_names)
        datasets_to_merge.append(ds_en)
    except Exception as e:
        print(f"⚠️  Could not load empathetic_dialogues: {e}")

    # 2. Load Custom/Local Datasets (e.g., French, Portuguese)
    # Uncomment and adapt the following lines when you have your files:
    # if os.path.exists("french_empathy.csv"):
    #     print("📚 Loading local 'french_empathy.csv'...")
    #     ds_fr = load_dataset("csv", data_files="french_empathy.csv", split="train")
    #     ds_fr = ds_fr.map(format_custom_dataset, remove_columns=ds_fr.column_names)
    #     datasets_to_merge.append(ds_fr)

    if not datasets_to_merge:
        print("❌ No datasets loaded. Exiting.")
        return

    # 3. Merge Datasets
    full_dataset = concatenate_datasets(datasets_to_merge)
    print(f"📊 Total examples: {len(full_dataset)}")

    # 4. Apply Chat Template
    print("📝 Applying Mistral chat template...")
    # Using batched=False to handle one by one safely for complex logic, or True for speed if logic allows
    full_dataset = full_dataset.map(
        functools.partial(apply_chat_template, tokenizer=tokenizer),
        desc="Formatting chat template"
    )

    # 5. Tokenize
    print("🔢 Tokenizing...")
    tokenized_dataset = full_dataset.map(
        functools.partial(tokenize_function, tokenizer=tokenizer),
        batched=True,
        remove_columns=["messages", "text", "context"] if "context" in full_dataset.column_names else ["messages",
                                                                                                       "text"],
        desc="Tokenizing"
    )

    # 6. Split and Save
    print("✂️  Splitting Train (90%) / Val (10%)...")
    split_dataset = tokenized_dataset.train_test_split(test_size=0.1, seed=42)

    train_path = os.path.join(args.output_dir, "train")
    val_path = os.path.join(args.output_dir, "val")

    print(f"💾 Saving to {args.output_dir}...")
    split_dataset["train"].save_to_disk(train_path)
    split_dataset["test"].save_to_disk(val_path)

    print("✅ Done! Ready for training.")


if __name__ == "__main__":
    main()