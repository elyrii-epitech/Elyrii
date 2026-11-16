# Loading a LoRA adapter locally

Use the repository's `lora_runtime` commands to convert a standard PEFT adapter and
serve it with llama.cpp. The adapter is applied at inference at scale 1; base weights
are never merged or overwritten. This is the supported local evaluation path when
Ollama rejects `ADAPTER` imports (observed with Ollama 0.40.8).

This server exposes llama.cpp APIs, **not Ollama APIs**. Use the journal evaluator's
`--backend llama` option below. Do not point the existing Kafka bridge, extraction
workers, or embedding worker at this endpoint: they still speak Ollama's protocol.
The legacy adapter setup in `docker-compose-vm.yml` requires an Ollama release that
supports imports; this workflow does not change that deployment or enable recall.

## Dependencies and inputs

Run commands from the repository root. Create a Python environment and install
`elyrii_ai/requirements-lora.txt`. To avoid downloading CUDA libraries when only
converting weights, install CPU PyTorch first:

```sh
python3 -m venv .venv-lora
.venv-lora/bin/pip install torch --index-url https://download.pytorch.org/whl/cpu
.venv-lora/bin/pip install -r elyrii_ai/requirements-lora.txt
```

Supply:

- A trusted llama.cpp checkout containing `convert_lora_to_gguf.py`. Conversion was
  tested at revision `eb4e244be77a906a183cd4a00fd51d9ad3200955`.
- A compatible `llama-server` executable. The server bundled with Ollama 0.40.8 was
  tested. Its GPU backend libraries must also be available if using GPU offload.
- A base GGUF from the **same model revision used for training**, and a local
  directory containing that model's Hugging Face `config.json`.
- An adapter directory containing `adapter_config.json` and
  `adapter_model.safetensors` (for example `elyrii_lora`).

Preparation checks the declared base model ID and architecture dimensions, rejects
nonfinite/malformed or unsupported tensors, and records hashes. Matching dimensions
alone cannot prove checkpoint identity; the operator must supply the correct base
revision. Standard Mistral/Llama LoRA is supported; DoRA, rank/alpha patterns, bias
updates, and other variants are rejected rather than silently ignored.

## Prepare and serve

```sh
.venv-lora/bin/python -m elyrii_ai.lora_runtime prepare \
  --adapter-dir elyrii_lora \
  --base-model /path/to/mistral-v0.3.gguf \
  --base-model-id mistralai/Mistral-7B-Instruct-v0.3 \
  --base-config /path/to/mistral-v0.3-config \
  --llama-cpp-dir /path/to/llama.cpp \
  --output-dir models/elyrii-lora-bundle

.venv-lora/bin/python -m elyrii_ai.lora_runtime serve \
  --bundle models/elyrii-lora-bundle \
  --llama-server /path/to/llama-server \
  --port 11436 --context-window 4096 --gpu-layers 0
```

Use a new output directory for each preparation. The bundle contains `adapter.gguf`
and `manifest.json`; the base GGUF remains at its original absolute path. Serving
rehashes both artifacts and refuses modifications. Keep artifacts immutable while
serving; stop with Ctrl-C before changing them. The command uses one inference slot
and binds to localhost by default. Set `--gpu-layers 99` to request full GPU offload
when the installed runtime supports your GPU; inspect its logs to confirm placement.

Zero-update adapters are rejected by default. The supplied October 2026 checkpoint
has 224 all-zero B matrices. To reproduce that diagnostic run, explicitly add
`--allow-zero-adapter` to **prepare, serve, and evaluate**. This does not make the
checkpoint trained. Validation detects zero A/B factors; it is not a training-quality
assessment and does not exhaustively test matrix-product cancellation.

## Evaluate journal recall

Use the pinned generation-tokenizer bundle for the base model, including
`manifest.json`, `tokenizer.json`, `tokenizer_config.json`, and `chat_template.jinja`.
The model name below must match that tokenizer manifest. The adapter identity is
recorded separately; it is not represented by the base Ollama digest.

```sh
.venv-lora/bin/python -m elyrii_ai.scripts.evaluate_journal_recall \
  --backend llama --url http://127.0.0.1:11436 \
  --adapter-bundle models/elyrii-lora-bundle \
  --tokenizer-dir /path/to/generation-tokenizer \
  --model mistral:7b-instruct \
  --output /tmp/journal-recall-lora.json
```

Use this against the local server launched above, with the same filesystem paths.
The evaluator checks `/lora-adapters` for the exact adapter and scale, `/props` for
the base path and context size, and provider tokenization before each generation.
It rejects truncation and oversized prompts, and checks artifacts again at the end.
No fallback to the base-only model is performed if verification fails. The local
server's reported paths are trusted; this does not attest a remote server's weights.
Responses still need qualitative review. Backend changes can affect outputs and
latency even with identical weights and seed.

```sh
.venv-lora/bin/python -m unittest elyrii_ai.test.test_lora_runtime
```
