Deployment Guide
================

This guide covers deploying Elyrii AI in various environments.

Local Development
-----------------

1. Install dependencies:

.. code-block:: bash

   pip install -r requirements.txt

2. Set environment variables:

.. code-block:: bash

   export DEPLOYMENT_MODE=local
   export VLLM_BASE_URL=http://localhost:8000/v1
   export AI_MODEL=mistralai/Mistral-7B-Instruct-v0.2

3. Run the application:

.. code-block:: python

   from ai import AI

   ai = AI()
   response = ai.send_message("Hello!")

Fly.io Deployment
-----------------

The project includes Fly.io configuration for GPU-powered deployments.

GPU Machine Setup
~~~~~~~~~~~~~~~~~

1. Deploy GPU machine:

.. code-block:: bash

   fly deploy -c fly_gpu.toml

2. Deploy controller:

.. code-block:: bash

   fly deploy -c fly_controller.toml

3. Set secrets:

.. code-block:: bash

   fly secrets set FLY_API_TOKEN=your_token
   fly secrets set HF_TOKEN=your_hf_token

Docker Deployment
-----------------

Build Docker Image
~~~~~~~~~~~~~~~~~~

.. code-block:: bash

   docker build -f Dockerfile -t elyrii-ai:latest .

Run Container
~~~~~~~~~~~~~

.. code-block:: bash

   docker run -d \
     --gpus all \
     -p 8000:8000 \
     -e AI_MODEL=mistralai/Mistral-7B-Instruct-v0.2 \
     -e GPU_MEMORY_UTILIZATION=0.85 \
     elyrii-ai:latest

Health Monitoring
-----------------

Check Service Health
~~~~~~~~~~~~~~~~~~~~

.. code-block:: python

   from ai import AI

   ai = AI()
   is_healthy = ai.check_health()
   print(f"Service healthy: {is_healthy}")

Get Available Models
~~~~~~~~~~~~~~~~~~~~

.. code-block:: python

   models = ai.get_models()
   print(f"Available models: {models}")