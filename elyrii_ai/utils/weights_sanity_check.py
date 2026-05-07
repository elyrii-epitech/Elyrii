import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel

base_model_id = "mistralai/Mistral-7B-Instruct-v0.3"
lora_weights_path = "./output/final_lora"

print(f"--- Loading Base Model: {base_model_id} ---")
tokenizer = AutoTokenizer.from_pretrained(base_model_id)
# We load in 16-bit to keep it simple; use device_map="auto" if you have a GPU
base_model = AutoModelForCausalLM.from_pretrained(
    base_model_id,
    torch_dtype=torch.bfloat16,
    device_map="auto"
)

print(f"--- Loading LoRA Weights from: {lora_weights_path} ---")
try:
    model = PeftModel.from_pretrained(base_model, lora_weights_path)
    model.eval()
    print("LoRA loaded successfully!")
except Exception as e:
    print(f"Error loading LoRA: {e}")
    exit()

# Test prompt using Mistral's Instruct format
prompt = "[INST] I'm very sad today... [/INST]"
inputs = tokenizer(prompt, return_tensors="pt").to("cuda" if torch.cuda.is_available() else "cpu")

print("\n--- Generating Response ---")
with torch.no_grad():
    outputs = model.generate(
        **inputs,
        max_new_tokens=100,
        min_new_tokens=20,
        temperature=0.9,
        do_sample=True,
        eos_token_id=99999,
    )

response = tokenizer.decode(outputs[0], skip_special_tokens=True)
print(f"Model Output:\n{response}")
