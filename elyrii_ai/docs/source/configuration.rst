Configuration Guide
===================

Environment Variables
---------------------

Deployment Settings
~~~~~~~~~~~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 20 15 65

   * - Variable
     - Default
     - Description
   * - ``DEPLOYMENT_MODE``
     - ``local``
     - Deployment environment: local, flyio, aws, gcp, azure, generic
   * - ``VLLM_BASE_URL``
     - ``http://localhost:8000/v1``
     - vLLM API endpoint URL
   * - ``AI_MODEL``
     - ``mistralai/Mistral-7B-Instruct-v0.2``
     - Model name/path from HuggingFace

Model Settings
~~~~~~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 20 15 65

   * - Variable
     - Default
     - Description
   * - ``HF_TOKEN``
     - None
     - HuggingFace token for gated models (Llama 2, etc.)
   * - ``AI_TEMPERATURE``
     - ``0.7``
     - Default sampling temperature (0.0-2.0)
   * - ``AI_MAX_TOKENS``
     - ``2048``
     - Maximum tokens to generate
   * - ``AI_TOP_P``
     - ``0.95``
     - Nucleus sampling parameter

Performance Settings
~~~~~~~~~~~~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 20 15 65

   * - Variable
     - Default
     - Description
   * - ``GPU_MEMORY_UTILIZATION``
     - ``0.85``
     - Fraction of GPU memory to use (0.0-1.0)
   * - ``TENSOR_PARALLEL_SIZE``
     - ``1``
     - Number of GPUs for tensor parallelism
   * - ``MAX_MODEL_LEN``
     - ``4096``
     - Maximum sequence length
   * - ``AI_TIMEOUT``
     - ``300``
     - Request timeout in seconds

Model Recommendations
---------------------

The configuration module includes recommendations for different hardware setups:

Small GPU (16GB VRAM)
~~~~~~~~~~~~~~~~~~~~~

.. code-block:: python

   AI_MODEL=mistralai/Mistral-7B-Instruct-v0.2
   GPU_MEMORY_UTILIZATION=0.85
   MAX_MODEL_LEN=4096

Medium GPU (24GB VRAM)
~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: python

   AI_MODEL=meta-llama/Llama-2-13b-chat-hf
   GPU_MEMORY_UTILIZATION=0.85
   MAX_MODEL_LEN=4096

Large GPU (40GB+ VRAM)
~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: python

   AI_MODEL=mistralai/Mixtral-8x7B-Instruct-v0.1
   GPU_MEMORY_UTILIZATION=0.90
   MAX_MODEL_LEN=8192

Code Specialization
~~~~~~~~~~~~~~~~~~~

.. code-block:: python

   AI_MODEL=codellama/CodeLlama-13b-Instruct-hf
   GPU_MEMORY_UTILIZATION=0.85
   MAX_MODEL_LEN=4096