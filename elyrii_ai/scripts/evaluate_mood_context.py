"""Generate synthetic English/French responses for rubric review with a pinned model.
Run from the repository root: python -m elyrii_ai.scripts.evaluate_mood_context --help
No production source data is loaded. Output is an evaluation artifact, not telemetry.
"""
import argparse
import asyncio
import json
from datetime import datetime
from pathlib import Path

import httpx
from elyrii_ai.chat_context import NativePromptBudget, safe_sections, bounded_json, verify_generation_model
from elyrii_ai.prompt.system_prompt import get_system_prompt


async def evaluate(args):
    budget = NativePromptBudget.load(args.tokenizer_dir, args.model)
    cases = json.loads((Path(__file__).parents[1] / "test/fixtures/mood_context_v1.json").read_text())
    identity = {"userId": "11111111-1111-4111-8111-111111111111", "conversationId": "evaluation", "sourceMessageId": "current"}
    observation = {"source": "mood_logs", "logId": "22222222-2222-4222-8222-222222222222", "userId": identity["userId"],
        "mood": "sad", "observedAt": "2030-04-01T10:00:00.123456Z", "freshUntil": "2030-04-03T10:00:00.123456Z", "timezone": "Europe/Paris"}
    results = []
    async with httpx.AsyncClient(base_url=args.url, timeout=300) as client:
        await verify_generation_model(client, budget)
        for case in cases:
            now = datetime.fromisoformat(case["now"].replace("Z", "+00:00"))
            response = {"version": 1, **identity, "sections": {"moodObservation":
                {**observation, **case["observation"]} if case["observation"] is not None else None}}
            instructions = get_system_prompt(1) + f"\nFor this synthetic scenario, today is {case['now']}. Respond in {case['language']}."
            body, counts = budget.compose(instructions, case["query"], safe_sections(response, identity, now), now)
            if counts["selectedMoodObservations"] != int(case["included"]):
                raise ValueError(f"Fixture mood did not fit or validate: {case['id']}")
            body["options"].update({"seed": 229, "temperature": 0})
            output = await bounded_json(client, "POST", "/api/generate", body, limit=200000)
            if output.get("done") is not True or not isinstance(output.get("response"), str): raise ValueError("Invalid generation")
            if output.get("prompt_eval_count", counts["inputTokens"]) + budget.response_tokens > budget.window:
                raise ValueError("Provider token accounting mismatch")
            results.append({"id": case["id"], "query": case["query"], "response": output["response"], "rubric": case["rubric"],
                "counts": counts, "review": "pending", "providerInputTokens": output.get("prompt_eval_count")})
        await verify_generation_model(client, budget)
    Path(args.output).write_text(json.dumps({"model": budget.model, "digest": budget.digest, "kind": "synthetic live responses; human rubric review required", "cases": results}, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tokenizer-dir", required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--url", default="http://localhost:11434")
    parser.add_argument("--output", default="/tmp/mood-response-evaluation.json")
    asyncio.run(evaluate(parser.parse_args()))
