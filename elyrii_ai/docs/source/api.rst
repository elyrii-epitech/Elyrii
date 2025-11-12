API Reference
=============

This section contains the detailed API documentation for all modules in the Elyrii AI package.

AI Module
---------

.. automodule:: ai
   :members:
   :undoc-members:
   :show-inheritance:

AI Class
~~~~~~~~

.. autoclass:: ai.AI
   :members:
   :undoc-members:
   :special-members: __init__
   :show-inheritance:

   .. automethod:: __init__
   .. automethod:: send_message
   .. automethod:: generate_completion
   .. automethod:: reset_conversation
   .. automethod:: get_models
   .. automethod:: check_health

Configuration Module
--------------------

.. automodule:: config
   :members:
   :undoc-members:
   :show-inheritance:

AIConfig Class
~~~~~~~~~~~~~~

.. autoclass:: config.AIConfig
   :members:
   :undoc-members:
   :special-members: __init__
   :show-inheritance:

DeploymentMode Enum
~~~~~~~~~~~~~~~~~~~

.. autoclass:: config.DeploymentMode
   :members:
   :undoc-members:
   :show-inheritance:

Controller Module
-----------------

.. automodule:: controller
   :members:
   :undoc-members:
   :show-inheritance:

GPUManager Class
~~~~~~~~~~~~~~~~

.. autoclass:: controller.GPUManager
   :members:
   :undoc-members:
   :special-members: __init__
   :show-inheritance:

Request/Response Models
~~~~~~~~~~~~~~~~~~~~~~~

.. autoclass:: controller.ChatRequest
   :members:
   :undoc-members:

.. autoclass:: controller.ChatResponse
   :members:
   :undoc-members: