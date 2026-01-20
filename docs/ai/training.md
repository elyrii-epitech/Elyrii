# Training Plan – Elyrii (Mistral‑7B)

**Goal** – Fine‑tune the open‑source **Mistral‑7B** model so it can act as a multilingual emotional‑support assistant (FR, EN, PT, ZH).

The plan is split into two phases:

- **Prototype & validation** on Google Colab (free GPU, quick iteration).
- **Full‑scale training** on a rented V100/A100 instance on vast.ai (cheaper than major clouds for long runs).

## 1️⃣ Phase 1 – Colab Proof‑of‑Concept

### Steps

| Step | Description                                                                                        | Commands / Code Snippets | Expected Outcome |
|---|----------------------------------------------------------------------------------------------------|---|---|
| 1.1 Set up environment | Install PyTorch, 🤗 Transformers, datasets, accelerate, bitsandbytes (8‑bit).                      | In a Colab cell: `!pip install -q torch==2.2.0 transformers datasets accelerate bitsandbytes` | All required libs installed. |
| 1.2 Load base model (8‑bit) | Reduce VRAM usage (≈ 12 GB) while preserving most quality.                                         | Load model with 8-bit quantization: `from transformers import AutoModelForCausalLM, AutoTokenizer` → `model_id = "mistralai/Mistral-7B-Instruct-v0.2"` → `tokenizer = AutoTokenizer.from_pretrained(model_id)` → `model = AutoModelForCausalLM.from_pretrained(model_id, device_map="auto", load_in_8bit=True)` | Model ready on the Colab GPU. |
| 1.3 Prepare multilingual emotional‑dialogue dataset | Combine four public corpora (see Section 2). Convert to the **ChatML** format expected by Mistral. | Convert to ChatML format: `def to_chatml(example):` → `msgs = []` → `for turn in example["history"]:` → `msgs.append({"role": turn["role"], "content": turn["content"]})` → `return {"messages": msgs}` | A `datasets.Dataset` object with columns `messages` (list of dicts) and `language`. |
| 1.4 Tokenizer & data collator | Use `DataCollatorForLanguageModeling` with `mlm=False`.                                            | Create collator: `from transformers import DataCollatorForLanguageModeling` → `collator = DataCollatorForLanguageModeling(tokenizer, mlm=False)` | Ready for trainer. |
| 1.5 Quick fine‑tune (1‑2 epochs) | Small learning‑rate, LoRA adapters (via `peft`).                                                   | Install peft: `!pip install -q peft` → Configure LoRA: `from peft import LoraConfig, get_peft_model` → `lora_cfg = LoraConfig(r=16, lora_alpha=32, target_modules=["q_proj","v_proj"], lora_dropout=0.05, bias="none")` → `model = get_peft_model(model, lora_cfg)` → Setup training: `from transformers import Trainer, TrainingArguments` → `args = TrainingArguments(output_dir="/content/finetuned", per_device_train_batch_size=2, gradient_accumulation_steps=4, learning_rate=2e-4, num_train_epochs=2, fp16=True, logging_steps=10, report_to="none")` → `trainer = Trainer(model=model, args=args, train_dataset=train_ds, eval_dataset=val_ds, data_collator=collator)` → `trainer.train()` | LoRA‑adapted checkpoint saved in `/content/finetuned`. |
| 1.6 Evaluation | Compute **BLEU**, **Rouge‑L**, and a **sentiment‑alignment** metric (e.g., using `nltk.sentiment`).  | Evaluate with BLEU: `from nltk.translate.bleu_score import corpus_bleu` → Compare model responses vs. reference empathetic replies | Rough sense of quality; identify language‑specific gaps. |
| 1.7 Export LoRA weights | Save only adapter files (`adapter_config.json`, `adapter_model.bin`).                                  | Save adapter: `model.save_pretrained("/content/lora_adapter")` | Small artifact (~30 MB) ready for the next phase. |

### What you learn in this phase

- **VRAM footprint** – 8‑bit + LoRA fits on a single T4 (≈ 15 GB).
- **Dataset balance** – Spot language imbalance early (e.g., Chinese data may dominate).
- **Learning‑rate stability** – LoRA on Mistral is sensitive; 2e‑4 works for 1‑2 epochs.

## 2️⃣ Phase 2 – Full Training on vast.ai

### 2.1 Choose a GPU instance

| Option                           | GPU | VRAM | Approx. price / hr | Why suitable |
|----------------------------------|---|---|--------------------|---|
| **A100‑40GB** (most common)      | NVIDIA A100 | 40 GB | \$0.70‑\$0.85      | Plenty of headroom for larger batch sizes, mixed‑precision, and future model extensions. |
| **V100‑32GB**                    | NVIDIA V100 | 32 GB | \$0.55‑\$0.65      | Slightly cheaper, still enough for 8‑bit + LoRA with batch‑size 4. |
| **RTX‑3090‑24GB** (if available) | NVIDIA RTX 3090 | 24 GB | \$0.45‑\$0.55      | Good fallback; may need gradient accumulation. |

Select a **spot** (pre‑emptible) instance to reduce cost; set up a **checkpoint‑save‑every‑epoch** routine so you can resume if the node is reclaimed.

### 2.2 Environment setup (Docker)

Create a Dockerfile that mirrors the Colab environment but adds `accelerate` config for multi‑GPU (if you ever use >1 GPU).

```dockerfile
FROM nvidia/cuda:12.1.1-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y git wget python3-pip && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir torch==2.2.0 transformers datasets accelerate bitsandbytes peft tqdm

# Copy training script (train.py) and LoRA init files
COPY train.py /workspace/train.py
WORKDIR /workspace
ENTRYPOINT ["python", "train.py"]
```

Build & push to a private registry (or use `docker run` directly on the vast.ai VM).

### 2.3 Data preparation on the VM

- **Upload the merged dataset** (≈ 2‑3 GB compressed) to the VM via `scp` or mount a **S3 bucket** (e.g., `boto3` streaming).
- **Shuffle & split** (90 % train / 10 % validation) using `datasets.load_from_disk` after you have saved the processed dataset from Colab (`dataset.save_to_disk("/content/merged")`).

```bash
# On the VM
python - <<'PY'
from datasets import load_from_disk
ds = load_from_disk("/data/merged")
ds = ds.shuffle(seed=42)
train = ds.select_range(0, int(0.9*len(ds)))
val   = ds.select_range(int(0.9*len(ds)), len(ds))
train.save_to_disk("/data/train")
val.save_to_disk("/data/val")
PY
```

### 2.4 Training script (train.py) – key parameters

```python
import os, torch, argparse
from transformers import AutoModelForCausalLM, AutoTokenizer, Trainer, TrainingArguments, DataCollatorForLanguageModeling
from peft import LoraConfig, get_peft_model
from datasets import load_from_disk

parser = argparse.ArgumentParser()
parser.add_argument("--epochs", type=int, default=5)
parser.add_argument("--lr", type=float, default=1e-4)
parser.add_argument("--batch", type=int, default=4)
parser.add_argument("--grad_acc", type=int, default=8)   # effective batch 32
args = parser.parse_args()

model_id = "mistralai/Mistral-7B-v0.1"
tokenizer = AutoTokenizer.from_pretrained(model_id, trust_remote_code=True)

model = AutoModelForCausalLM.from_pretrained(
    model_id,
    device_map="auto",
    load_in_8bit=True,          # keep VRAM low
    torch_dtype=torch.float16,
)

# LoRA
lora_cfg = LoraConfig(
    r=32,
    lora_alpha=64,
    target_modules=["q_proj","v_proj"],
    lora_dropout=0.05,
    bias="none",
)
model = get_peft_model(model, lora_cfg)

train_ds = load_from_disk("/data/train")
val_ds   = load_from_disk("/data/val")

collator = DataCollatorForLanguageModeling(tokenizer, mlm=False)

training_args = TrainingArguments(
    output_dir="/output",
    per_device_train_batch_size=args.batch,
    gradient_accumulation_steps=args.grad_acc,
    learning_rate=args.lr,
    num_train_epochs=args.epochs,
    fp16=True,
    evaluation_strategy="steps",
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
trainer.save_model("/output/final_lora")
```

#### Why these numbers?

- **Learning rate 1e‑4** – Slightly lower than the Colab trial to accommodate longer training.
- **Effective batch 32** – Gives stable gradient estimates without exceeding VRAM.
- **5 epochs** – Empirically enough for convergence on ~2 M dialogue turns. Adjust upward if loss plateaus.

### 2.5 Checkpointing & Resilience

- Use `save_steps=500` (≈ every 10 min on a typical A100) to write LoRA adapters to `/output`.
- Mount a **persistent volume** on vast.ai (e.g., 100 GB SSD) to survive pre‑emptions.
- In the Docker entrypoint, wrap `trainer.train()` in a try/except that reloads the latest checkpoint if the process restarts.

### 2.6 Post‑training Evaluation

- **Quantitative** – Compute BLEU/Rouge on a held‑out multilingual test set (≈ 10 k samples).
- **Sentiment Alignment** – Use `transformers.pipeline("sentiment-analysis", model="nlptown/bert-base-multilingual-uncased-sentiment")` to verify that the model’s replies are **positive/empathetic** (> 70 % of cases).
- **Human Rating** – Have 3‑4 native speakers per language rate 100 random dialogues on a 1‑5 empathy scale. Aim for an average ≥ 3.8.

### 2.7 Export for Production

- Merge LoRA adapters into the base checkpoint (optional) using `peft.merge_and_unload`.
- Convert to **gguf** or **ONNX** if you later want to serve via **vLLM** or **TGI** with faster inference.

```bash
python -c "from peft import PeftModel; from transformers import AutoModelForCausalLM; \
model = AutoModelForCausalLM.from_pretrained('mistralai/Mistral-7B-v0.1', torch_dtype='auto') \
adapter = PeftModel.from_pretrained(model, '/output/final_lora'); \
merged = adapter.merge_and_unload(); merged.save_pretrained('/output/merged')"
```

Now the folder `/output/merged` contains a **stand‑alone** model ready for the inference server described in the hosting plan.

## 3️⃣ Timeline (Estimated)

| Week | Milestone |
|---|---|
| 1 | Gather & clean multilingual emotional‑dialogue corpora; store in `datasets` format. |
| 2 | Colab prototype: 8‑bit + LoRA fine‑tune (2 epochs); quick evaluation; export LoRA weights. |
| 3 | Set up vast.ai VM, Docker image, and persistent storage. |
| 4‑5 | Full training on vast.ai (5 epochs, checkpoint every 500 steps). |
| 6 | Comprehensive evaluation (BLEU, Rouge‑L, sentiment alignment, human rating). |
| 7 | Merge adapters, convert to production format, push to model bucket (S3/GCS). |
| 8 | Integrate with the Hono inference service; run end‑to‑end tests. |

## 4️⃣ Resources & References

| Language | Dataset (public) | Link |
|---|---|---|
| French | FRENCH‑EMPATHY‑CHAT (synthetic + Reddit‑EN‑FR pairs) | https://huggingface.co/datasets/username/french-empathy-chat |
| English | EmpatheticDialogues (ED) | https://huggingface.co/datasets/empatheticdialogues |
| Portuguese | BR‑Support‑Corpus (Portuguese mental‑health forums) | https://huggingface.co/datasets/username/br-support |
| Chinese | ChineseCounseling (Weibo counseling posts) | https://huggingface.co/datasets/username/chinese-counseling |

All datasets are licensed under CC‑BY‑SA or similar permissive terms; ensure compliance before redistribution.

## 5️⃣ Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| **GPU pre‑emption** on vast.ai | Training interruption, loss of progress | Frequent checkpointing, persistent volume, resume script. |
| **Language imbalance** (e.g., Chinese dominates) | Model biased toward high‑resource language | Oversample low‑resource languages; use `ClassBalancedSampler`. |
| **Hallucination / unsafe output** | Harmful advice to vulnerable users | Apply post‑generation safety filter (OpenAI’s moderation style) and keep a human‑in‑the‑loop for critical responses. |
| **VRAM overflow** with larger batch | Crash during training | Stick to 8‑bit + LoRA; adjust `gradient_accumulation_steps`. |
| **Over‑fitting to training style** | Poor generalisation | Early stopping based on validation loss; mix in generic chit‑chat data. |
