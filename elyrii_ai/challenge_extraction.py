"""Helpers for extracting AI-generated challenge proposals from chat text."""

import json
import re
from typing import Any

CHALLENGE_BLOCK_RE = re.compile(r"<challenge>(.*?)</challenge>", re.DOTALL)


def extract_challenge_payload(ai_response: str) -> dict[str, Any] | None:
    """Return the first valid challenge JSON payload in an AI response."""
    match = CHALLENGE_BLOCK_RE.search(ai_response)
    if not match:
        return None

    try:
        payload = json.loads(match.group(1).strip())
    except json.JSONDecodeError:
        return None

    if not isinstance(payload, dict):
        return None
    if not isinstance(payload.get("title"), str) or not payload["title"].strip():
        return None

    return payload


def strip_challenge_blocks(ai_response: str) -> str:
    """Remove hidden challenge proposal blocks before showing text to users."""
    return CHALLENGE_BLOCK_RE.sub("", ai_response).strip()
