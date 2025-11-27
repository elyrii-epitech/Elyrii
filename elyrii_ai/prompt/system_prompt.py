"""
Elyrii System Prompt Script
========================

Retrieve and construct system prompt based on version.
"""

import logging
import json
import os

__LATEST = int(os.getenv("PROMPT_VERSION", "1"))

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

def get_file_from_version(
    ext: str, version: int, name: str = "", subversion: int = -1
) -> str:
    """
    Constructs a filename string based on versioning parameters.

    Args:
        ext (str): The file extension (e.g., "json").
        version (int): The major version number.
        name (str, optional): A prefix name for the file. Defaults to "".
        subversion (int, optional): The sub-version number. If negative, it is ignored. Defaults to -1.

    Returns:
        str: The formatted filename. Returns an empty string if the version is negative.
    """
    file = ""

    if version < 0:
        logger.error("Version can't be negative")
        return file
    if subversion >= 0:
        file = f"{name}v{version}.{subversion}.{ext}"
    else:
        file = f"{name}v{version}.{ext}"
    return file


def get_system_prompt(version: int = __LATEST) -> str:
    """
    Loads and combines the persona and policy configuration files into a single system prompt.

    Args:
        version (int, optional): The version of the configuration files to load. Defaults to __LATEST.

    Returns:
        str: The combined system prompt string consisting of the first element of the persona and policy.

    Raises:
        RuntimeError: If there is an error loading either the persona or policy files.
    """
    try:
        path = os.path.join(BASE_DIR, "persona", get_file_from_version("json", version))
        persona = json.load(open(path))
    except Exception as e:
        logger.error(f"Error loading persona: {e}")
        raise RuntimeError
    try:
        path = os.path.join(BASE_DIR, "policy", get_file_from_version("json", version))
        policy = json.load(open(path))
    except Exception as e:
        logger.error(f"Error loading policy: {e}")
        raise RuntimeError

    prompt = f"{persona.get('persona', '')} {policy.get('policy', '')}"
    return prompt.strip()
