import asyncio
import json
import unittest
from unittest.mock import AsyncMock

import httpx
from pydantic import ValidationError
from tokenizers import Tokenizer
from tokenizers.models import WordLevel
from tokenizers.pre_tokenizers import Whitespace

from elyrii_ai.summary import RollingSummarizer, SummaryJob, SummaryInputTooLarge
from elyrii_ai.summary_worker import process_job


def job_data():
    return {"version": 1, "jobId": "22222222-2222-4222-8222-222222222222",
            "userId": "33333333-3333-4333-8333-333333333333", "conversationId": "a", "revision": 0,
            "attempt": 1, "model": "test-model", "timezone": "Europe/Paris",
            "policy": {"messageThreshold": 2, "tokenThreshold": 20, "maxInputTokens": 3000, "maxOutputTokens": 64},
            "priorSummary": None, "priorThroughMessageId": None,
            "messages": [
                {"id": "11111111-1111-4111-8111-111111111111", "role": "user", "content": "I might have an exam tomorrow; I feel sad today.", "messageAt": "2030-01-01T00:30:00+01:00"},
                {"id": "11111111-1111-4111-8111-111111111112", "role": "assistant", "content": "You could try a walk. I cannot know your exam date.", "messageAt": "2030-01-01T00:30:00+01:00"},
            ]}


class SummaryTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        # A real, local tokenizer for the mocked generation model; no downloads.
        self.tokenizer = Tokenizer(WordLevel({"[UNK]": 0}, unk_token="[UNK]"))
        self.tokenizer.pre_tokenizer = Whitespace()
        self.job = SummaryJob.model_validate(job_data())

    async def run_model(self, handler, job=None, timeout=1):
        async with httpx.AsyncClient(base_url="http://ollama.test", transport=httpx.MockTransport(handler)) as client:
            summarizer = RollingSummarizer(client, "test-model", self.tokenizer, timeout=timeout)
            return await summarizer.summarize(job or self.job)

    async def test_prior_summary_speaker_uncertainty_and_timezone_are_preserved_in_prompt(self):
        data = job_data()
        data.update(priorSummary="The user tentatively planned to study.", priorThroughMessageId="11111111-1111-4111-8111-111111111110")
        def handler(request):
            self.assertEqual(request.url.path, "/api/generate")
            body = json.loads(request.content)
            self.assertTrue(body["raw"])
            self.assertEqual(body["options"]["num_predict"], 64)
            self.assertIn("UNTRUSTED DATA", body["prompt"])
            payload = json.loads("{" + body["prompt"].split("\n\n{", 1)[1])
            self.assertEqual(payload["priorSummary"], data["priorSummary"])
            self.assertEqual(payload["messages"], data["messages"])
            self.assertEqual(payload["timezone"], "Europe/Paris")
            return httpx.Response(200, json={"done": True, "response": "The user may have an exam tomorrow and feels sad today. The assistant suggested a walk."})
        output = await self.run_model(handler, SummaryJob.model_validate(data))
        self.assertEqual(output["throughMessageId"], data["messages"][-1]["id"])
        self.assertEqual(output["outputTokens"], len(self.tokenizer.encode(output["summary"], add_special_tokens=False).ids))

    async def test_thresholds_use_message_count_or_actual_tokens(self):
        data = job_data(); data["policy"].update(messageThreshold=3, tokenThreshold=100)
        handler = lambda _: self.fail("Below thresholds must not call inference")
        self.assertEqual(await self.run_model(handler, SummaryJob.model_validate(data)), {"status": "skipped"})
        data["policy"]["tokenThreshold"] = 1
        output = await self.run_model(lambda _: httpx.Response(200, json={"done": True, "response": "User described uncertainty."}), SummaryJob.model_validate(data))
        self.assertEqual(output["status"], "success")

    async def test_token_budget_selects_only_a_contiguous_prefix(self):
        data = job_data()
        data["messages"].append({**data["messages"][0], "id": "11111111-1111-4111-8111-111111111113", "content": "Long message " * 500})
        async with httpx.AsyncClient() as client:
            summarizer = RollingSummarizer(client, "test-model", self.tokenizer)
            job = SummaryJob.model_validate(data)
            data["policy"]["maxInputTokens"] = summarizer.tokens(summarizer.input_prompt(job, job.messages[:2]), special=True)
        def handler(request):
            body = json.loads(request.content)
            self.assertNotIn("Long message", body["prompt"])
            self.assertLessEqual(len(self.tokenizer.encode(body["prompt"]).ids), data["policy"]["maxInputTokens"])
            return httpx.Response(200, json={"done": True, "response": "User is uncertain; assistant offered a suggestion."})
        output = await self.run_model(handler, SummaryJob.model_validate(data))
        self.assertEqual(output["throughMessageId"], data["messages"][1]["id"])

    async def test_oversized_first_source_is_not_skipped_or_truncated(self):
        data = job_data(); data["messages"][0]["content"] = "word " * 1000; data["policy"]["maxInputTokens"] = 256
        with self.assertRaises(SummaryInputTooLarge):
            await self.run_model(lambda _: self.fail("Must not infer"), SummaryJob.model_validate(data))

    async def test_output_bound_uses_tokenizer_not_character_estimate(self):
        data = job_data(); data["policy"]["maxOutputTokens"] = 16
        with self.assertRaises(ValueError):
            await self.run_model(lambda _: httpx.Response(200, json={"done": True, "response": "word " * 17}), SummaryJob.model_validate(data))
        # This long Unicode string is one token with the test generation tokenizer.
        output = await self.run_model(lambda _: httpx.Response(200, json={"done": True, "response": "é" * 200}), SummaryJob.model_validate(data))
        self.assertEqual(output["outputTokens"], 1)

    async def test_incomplete_malformed_oversized_and_timed_out_inference(self):
        for response in [httpx.Response(503), httpx.Response(200, json={"done": True, "done_reason": "length", "response": "Partial"}),
                         httpx.Response(200, json={"done": False}), httpx.Response(200, json=[]),
                         httpx.Response(200, json={"done": True, "response": " "}), httpx.Response(200, content=b"x" * 100001)]:
            with self.subTest(response=response), self.assertRaises((ValueError, httpx.HTTPError)):
                await self.run_model(lambda _: response)
        async def slow(request):
            await asyncio.sleep(0.1)
            return httpx.Response(200, json={"done": True, "response": "Late"})
        with self.assertRaises(asyncio.TimeoutError):
            await self.run_model(slow, timeout=0.01)

    def test_duplicate_empty_and_invalid_temporal_inputs_fail_validation(self):
        for mutate in [lambda d: d.update(messages=[]), lambda d: d["messages"].append(d["messages"][0]),
                       lambda d: d.update(timezone="Mars/Test"), lambda d: d["messages"][0].update(messageAt="2030-01-01")]:
            data = job_data(); mutate(data)
            with self.assertRaises(ValidationError):
                SummaryJob.model_validate(data)

    async def test_worker_preserves_identity_and_replays_publish_failure(self):
        summarizer = AsyncMock(); summarizer.model = "test-model"
        summarizer.summarize.return_value = {"status": "success", "summary": "User described uncertainty.", "throughMessageId": self.job.messages[-1].id, "outputTokens": 4}
        publish = AsyncMock(side_effect=RuntimeError("Kafka down"))
        with self.assertRaises(RuntimeError):
            await process_job(self.job.model_dump_json().encode(), summarizer, publish)
        publish.side_effect = None
        await process_job(self.job.model_dump_json().encode(), summarizer, publish)
        result = publish.call_args.args[1]
        self.assertEqual(result["jobId"], self.job.jobId)
        self.assertNotIn("messages", result)
        self.assertEqual(publish.call_count, 2)

    async def test_worker_emits_failure_without_private_exception_text(self):
        summarizer = AsyncMock(); summarizer.model = "test-model"
        summarizer.summarize.side_effect = ValueError("private source text")
        publish = AsyncMock()
        await process_job(self.job.model_dump_json().encode(), summarizer, publish)
        result = publish.call_args.args[1]
        self.assertEqual(result["error"], "inference_failed")
        self.assertNotIn("private", json.dumps(result))
        summarizer.model = "different-model"
        await process_job(self.job.model_dump_json().encode(), summarizer, publish)
        self.assertEqual(publish.call_args.args[1]["error"], "invalid_input")


if __name__ == "__main__":
    unittest.main()
