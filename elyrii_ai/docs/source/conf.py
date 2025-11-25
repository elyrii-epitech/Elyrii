
# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

import os
import sys

# Add the parent directory to sys.path to enable autodoc to find the modules

sys.path.insert(0, os.path.abspath('../../..'))

sys.path.insert(0, os.path.abspath('../..'))
sys.path.insert(0, os.path.abspath('../../controller'))
sys.path.insert(0, os.path.abspath('../../training'))

autodoc_mock_imports = [
    "torch",
    "transformers",
    "peft",
    "datasets",
    "pandas",
    "tqdm",
    "tabulate",
    'fastapi',
    'uvicorn',
    'httpx',
    'pydantic',
    'requests'
]

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = 'Elyrii AI'
copyright = '2025, Elyrii Team'
author = 'Elyrii Team'
release = '1.0.0'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [
    'sphinx.ext.autodoc',       # Auto-generate docs from docstrings
    'sphinx.ext.napoleon',      # Support for Google/NumPy docstrings
    'sphinx.ext.viewcode',      # Add links to highlighted source code
    'sphinx.ext.githubpages',   # Create .nojekyll file for GitHub Pages
    'sphinx.ext.intersphinx',   # Link to other project's documentation
    'sphinx.ext.todo',          # Support for todo items
    'sphinx.ext.coverage',      # Check documentation coverage
]

# Napoleon settings for Google-style docstrings
napoleon_google_docstring = True
napoleon_numpy_docstring = False
napoleon_include_init_with_doc = True
napoleon_include_private_with_doc = False
napoleon_include_special_with_doc = True
napoleon_use_admonition_for_examples = False
napoleon_use_admonition_for_notes = False
napoleon_use_admonition_for_references = False
napoleon_use_ivar = False
napoleon_use_param = True
napoleon_use_rtype = True
napoleon_type_aliases = None
napoleon_attr_annotations = True

# Autodoc settings
autodoc_default_options = {
    'members': True,
    'member-order': 'bysource',
    'special-members': '__init__',
    'undoc-members': True,
    'exclude-members': '__weakref__'
}

# Don't show type hints in signature (they're in the description)
autodoc_typehints = 'description'
autodoc_typehints_description_target = 'documented'

# Intersphinx mapping
intersphinx_mapping = {
    'python': ('https://docs.python.org/3', None),
    'requests': ('https://requests.readthedocs.io/en/latest/', None),
}

templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = 'sphinx_rtd_theme'  # ReadTheDocs theme
html_static_path = ['_static']

# Theme options
html_theme_options = {
    'navigation_depth': 4,
    'collapse_navigation': False,
    'sticky_navigation': True,
    'includehidden': True,
    'titles_only': False
}

# Additional options
html_show_sourcelink = True
html_show_sphinx = True
html_show_copyright = True

# Output file base name for HTML help builder
htmlhelp_basename = 'ElyriiAIdoc'
