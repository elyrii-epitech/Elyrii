# Overview

This document describes the infrastructure we set up to host the Mistral‑7B model for the Elyrii project. The architecture balances cost‑effectiveness (important for a student‑run prototype) with enough compute power to deliver responsive inference.

## Components

| Component         | Type / Size | Purpose                                                                                                                                                           | Cost (approx.)                             |
|-------------------|---|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------|
| Controller VM     | shared-cpu-1x (256 MB–512 MB RAM) | • Receives HTTP requests from the Chat micro‑service. <br/>• Performs authentication checks.<br/>• Triggers the GPU machine when a request arrives.                         | \$5 – \$10 / month (always‑on, cheap)      |
| GPU Machine       | gpu-a100-40gb (Fly GPU) | • Hosts the inference server (vLLM or Text Generation Inference).<br/>• Executes the actual generation of text.<br/>• Auto‑stops after 5 min of inactivity to save credits. | Pay‑as‑you‑go (≈ $0.70 / hour when active) |
| Persistent Volume | 50 GB block storage | • Holds the downloaded model weights permanently.<br/>• Prevents re‑downloading the ~45 GB checkpoint on every GPU start‑up.                                           | ≈ \$0.15 / GB → \$7.50 / month             |

## Deployment Flow

1. **Startup** – The Controller VM boots automatically and stays running 24/7.
2. **Request Arrival** – When the Chat service sends a `/generate` call, the Controller verifies the JWT and checks whether the GPU machine is active.
3. **GPU Activation** – If the GPU instance is idle, the Controller launches it (Fly GPU). The persistent volume is attached, giving the instance immediate access to the model files.
4. **Inference Server** – Inside the GPU machine we run either vLLM or Text Generation Inference (TGI). Both expose a simple `/generate` REST endpoint that the Controller proxies to.
5. **Auto‑Stop** – After the last request finishes, a watchdog timer starts. If no new request comes within 5 minutes, the GPU instance shuts down automatically, releasing compute credits.
6. **Shutdown** – The Controller remains alive, ready for the next request.

## Why This Setup?

- **Cost Efficiency** – Keeping only a tiny shared‑CPU VM always on costs less than $10/mo. The expensive GPU is only spun up on demand, dramatically reducing the monthly bill compared to a continuously running A100.
- **Fast Cold Starts** – The persistent 50 GB volume ensures the model is already on disk, so the GPU instance can start serving within seconds rather than minutes spent downloading weights.
- **Scalability for Demo** – For a project demo we rarely need more than a few concurrent generations. The auto‑stop policy prevents runaway charges while still delivering sub‑second latency once the GPU is warm.
- **Simplicity** – Using Fly.io’s built‑in VM types and volumes means we only manage a handful of YAML configs; no separate orchestration layer is required.

## Example Fly.toml (simplified)

```toml
# fly.toml – controller VM
app = "ai-assist-controller"
primary_region = "ams"

[env]
PORT = "8080"

[[services]]
  internal_port = 8080
  protocol = "tcp"
  [[services.ports]]
    port = 80
  [[services.ports]]
    port = 443
  [[services.tcp_checks]]
    interval = "30s"
    timeout = "2s"

# fly.gpu.toml – GPU machine (auto‑stop)
app = "ai-assist-gpu"
primary_region = "ams"

[vm]
  size = "gpu-a100-40gb"
  cpu_kind = "shared"

[mounts]
  source = "model-volume"
  destination = "/model"
  type = "volume"

[experimental]
  auto_stop = true
  auto_stop_timeout = "300s"   # 5 minutes
```

The actual files in the repository contain the full configuration, startup scripts for vLLM/TGI, and health‑check endpoints.

## Monitoring & Maintenance

- **Health Checks** – Both the Controller and GPU services expose `/health` endpoints that Fly.io probes every 30 seconds.
- **Logs** – `fly logs` streams stdout/stderr; we pipe GPU inference logs to a separate file for later analysis.
- **Metrics** – (Optional) Export Prometheus metrics from the inference server to monitor request latency and GPU utilisation.

## Estimated Monthly Cost (Typical Academic Use)

| Item | Approx. Monthly Cost |
|---|---|
| Controller VM (always‑on) | $7 |
| Persistent Volume (50 GB) | $7.50 |
| GPU runtime (≈ 20 hrs total per month) | $14 |
| Total | ≈ $28.50 |

Even with a higher usage pattern (≈ 40 hrs GPU time) the total stays under $55, well within a student budget.

## Closing Remarks

The chosen architecture demonstrates a practical, production‑like deployment while respecting the limited resources for the first phase of the project. It showcases how on‑demand GPU provisioning, persistent storage, and a lightweight controller can be combined to deliver a performant AI service without incurring prohibitive costs.
