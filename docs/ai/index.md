# Elyrii AI Documentation

Welcome to the AI component of Elyrii. This section provides an overview of the architecture, capabilities, and workflow of the custom Mistral‑7B‑based language model that powers the chatbot.

Below you’ll find links to detailed guides covering deployment, hosting, and model training.

## 📖 Table of Contents

1. [Overview](#overview) – High‑level description of the AI service.
2. [Architecture](#architecture) – How the model integrates with the backend micro‑services.
3. [Endpoints](#endpoints) – API contract for sending prompts and receiving responses.
4. [Key Consideration](#key-consideration) - Performance, scaling, and privacy basics.

## Detailed Guides

- Hosting of the Model – [hosting.md](hosting.md)
  - Description of the deployment environment, hardware choices, and cost estimation.
- Training & Fine‑Tuning – [training.md](training.md)
  - Summary of the dataset preparation, fine‑tuning methodology, training platform choice, and cost estimation

## Overview

The AI service provides a conversational assistant tailored for young users experiencing isolation. It leverages a fine‑tuned Mistral‑7B model, offering:

- Context‑aware replies with a maximum token limit of 2048.
- Sentiment detection to adapt tone (supportive, encouraging, neutral).
- Built‑in safety filters to prevent harmful or disallowed content.

The service runs as TODO, then returns a generated response.

## Architecture

```
TODO
```

- Chat Service forwards user messages to the AI Inference API.
- AI Inference API loads the serialized Mistral‑7B checkpoint (or LoRA‑adapted weights) into memory and performs generation using the 🤗 Transformers pipeline.
- The inference layer can be scaled horizontally behind a load balancer (NGINX, Traefik, or Cloud‑native LB).

## Endpoints

## Key Consideration


- Performance – On a single RTX 3080 the model serves responses within ~250 ms for typical 128‑token outputs, sufficient for interactive demo sessions.
- Scaling – For larger class‑room deployments, additional replicas can be added behind an NGINX round‑robin proxy; request throttling is handled via a shared Redis bucket.
- Privacy – Conversation snippets are stored only for the active session (max 24 h) unless the user explicitly opts‑in to retain history. All traffic is TLS‑encrypted, meeting basic GDPR expectations for a research prototype.


## Next Steps

- Review [hosting.md](hosting.md) to understand the hardware and configuration choices made for this project.
- Read [training.md](training.md) for the dataset curation, fine‑tuning process, and the reasons behind each decision.

Feel free to raise issues or pull requests in the repository if you discover gaps or have improvements to suggest.
