API Reference
=============

.. module:: elyrii_ai

This section contains the detailed API documentation for all modules in the Elyrii AI package.

AI Module
---------

Main AI client for interacting with vLLM models, configuration classes and deployment settings.

.. automodule:: elyrii_ai.ai
   :members:
   :undoc-members:
   :show-inheritance:
   :member-order: bysource

.. automodule:: elyrii_ai.ai_config
   :members:
   :undoc-members:
   :show-inheritance:
   :member-order: bysource

Controller
----------

FastAPI controller for GPU machine lifecycle management.

.. automodule:: elyrii_ai.controller.controller
   :members:
   :undoc-members:
   :show-inheritance:
   :member-order: bysource

Training
--------

Training pipeline including data processing up to training evaluation.

.. automodule:: elyrii_ai.training.prepare_data
   :members:
   :undoc-members:
   :show-inheritance:
   :member-order: bysource

.. automodule:: elyrii_ai.training.train
   :members:
   :undoc-members:
   :show-inheritance:
   :member-order: bysource

.. automodule:: elyrii_ai.training.evaluate
   :members:
   :undoc-members:
   :show-inheritance:
   :member-order: bysource

Prompt
------

AI system prompt utility functions.

.. automodule:: elyrii_ai.prompt.system_prompt
   :members:
   :undoc-members:
   :show-inheritance:
   :member-order: bysource