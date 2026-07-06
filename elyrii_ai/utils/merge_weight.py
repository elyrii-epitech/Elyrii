from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel
import torch

base_model = "mistralai/Mistral-7B-Instruct-v0.3"
lora_path = "./output/final_lora"

model = AutoModelForCausalLM.from_pretrained(base_model, torch_dtype=torch.bfloat16, device_map="cpu")
tokenizer = AutoTokenizer.from_pretrained(base_model)

# Load LoRA
model = PeftModel.from_pretrained(model, lora_path)

# Merge
model = model.merge_and_unload()

# Save
model.save_pretrained("./elyrii-merged-bf16")
tokenizer.save_pretrained("./elyrii-merged-bf16")