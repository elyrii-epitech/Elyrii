import os, torch, argparse
from transformers import AutoModelForCausalLM, AutoTokenizer, Trainer, TrainingArguments, DataCollatorForLanguageModeling
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training, TaskType
from datasets import load_from_disk

parser = argparse.ArgumentParser()
parser.add_argument("--epochs", type=int, default=5)
parser.add_argument("--lr", type=float, default=1e-4)
parser.add_argument("--batch", type=int, default=4)
parser.add_argument("--grad_acc", type=int, default=8)   # effective batch 32
parser.add_argument("--data_dir", type=str, default="/data")
parser.add_argument("--output_dir", type=str, default="/output")
args = parser.parse_args()

model_id = "mistralai/Mistral-7B-v0.1"
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

train_ds = load_from_disk(os.path.join(args.data_dir, "train"))
val_ds   = load_from_disk(os.path.join(args.data_dir, "val"))

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
)

trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=train_ds,
    eval_dataset=val_ds,
    data_collator=collator,
)

trainer.train()
trainer.save_model(os.path.join(args.output_dir, "final_lora"))
