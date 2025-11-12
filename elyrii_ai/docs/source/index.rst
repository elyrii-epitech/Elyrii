Welcome to Elyrii AI Documentation
===================================

Elyrii AI is a Python module for interacting with vLLM-powered AI models through an OpenAI-compatible API.
It provides high-throughput inference with efficient batching and supports both streaming and non-streaming responses.

Features
--------

* **OpenAI-compatible API**: Drop-in replacement for OpenAI's API using local models
* **High-throughput inference**: Efficient batching with vLLM backend
* **Streaming support**: Real-time response streaming for better UX
* **Conversation history**: Automatic management of chat context
* **Cloud-agnostic**: Works with Fly.io, AWS, GCP, Azure, and local deployments
* **Health monitoring**: Built-in health checks and model availability detection

Quick Start
-----------

Installation
~~~~~~~~~~~~

.. code-block:: bash

   pip install -r requirements.txt

Basic Usage
~~~~~~~~~~~

.. code-block:: python

   from ai import AI

   # Initialize the AI client
   ai = AI(
       base_url="http://localhost:8000/v1",
       model="mistralai/Mistral-7B-Instruct-v0.2"
   )

   # Send a message
   response = ai.send_message("Hello, how are you?")
   print(response)

   # Generate a completion
   completion = ai.generate_completion("Once upon a time")
   print(completion)

Configuration
~~~~~~~~~~~~~

The module supports flexible configuration through environment variables:

.. code-block:: bash

   export VLLM_BASE_URL="http://localhost:8000/v1"
   export AI_MODEL="mistralai/Mistral-7B-Instruct-v0.2"
   export AI_TEMPERATURE="0.7"
   export AI_MAX_TOKENS="2048"

Contents
--------

.. toctree::
   :maxdepth: 2
   :caption: Documentation:

   api
   configuration
   deployment

Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`
```
