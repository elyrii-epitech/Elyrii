import asyncio
import json
import math
import unittest
from unittest.mock import AsyncMock

import httpx
from pydantic import ValidationError
from elyrii_ai.embeddings import EmbeddingJob, OllamaEmbeddingAdapter, ModelMismatch, InvalidEmbeddingInput, model_spec
from elyrii_ai.embedding_worker import process_job


class EmbeddingTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.spec = model_spec("a" * 64)
        self.job = EmbeddingJob(version=1, jobId="11111111-1111-4111-8111-111111111111",
            memoryId="22222222-2222-4222-8222-222222222222", userId="33333333-3333-4333-8333-333333333333",
            model=self.spec.id, contentRevision=2, attempt=1, spec=self.spec, content="J’ai obtenu mon diplôme.")

    async def embed(self, handler, content=None, timeout=1):
        async with httpx.AsyncClient(base_url="http://ollama.test", transport=httpx.MockTransport(handler)) as client:
            return await OllamaEmbeddingAdapter(client, self.spec, timeout).embed(content or self.job.content)

    def tags(self, digest=None):
        return httpx.Response(200, json={"models": [{"name": self.spec.providerModel, "digest": digest or self.spec.digest}]})

    def response(self, vector):
        return httpx.Response(200, json={"model": self.spec.providerModel, "embeddings": [vector]})

    async def test_readable_multilingual_text_and_exact_metadata_reach_provider(self):
        calls = []
        def handler(request):
            calls.append(request.url.path)
            if request.url.path == "/api/tags": return self.tags()
            body = json.loads(request.content)
            self.assertEqual(body["input"], self.job.content)
            self.assertEqual(body["model"], "embeddinggemma:300m")
            self.assertEqual(body["dimensions"], 768)
            self.assertFalse(body["truncate"])
            return self.response([3, 4] + [0] * 766)
        vector = await self.embed(handler)
        self.assertEqual(vector[:2], [0.6, 0.8])
        self.assertAlmostEqual(math.hypot(*vector), 1)
        self.assertEqual(calls, ["/api/tags", "/api/embed", "/api/tags"])

    async def test_missing_or_changed_artifact_fails_closed(self):
        for after in [False, True]:
            tags = 0
            def handler(request):
                nonlocal tags
                if request.url.path == "/api/tags":
                    tags += 1
                    return self.tags("b" * 64 if not after or tags == 2 else None)
                return self.response([1] + [0] * 767)
            with self.subTest(after=after), self.assertRaises(ModelMismatch):
                await self.embed(handler)

    async def test_wrong_dimensions_nonnumeric_nonfinite_and_zero_vectors_are_rejected(self):
        for vector in [[1, 2, 3], [0] * 768, [True] + [0] * 767, ["1"] + [0] * 767]:
            def handler(request):
                return self.tags() if request.url.path == "/api/tags" else self.response(vector)
            with self.subTest(vector=vector[:3]), self.assertRaises(ValueError):
                await self.embed(handler)
        for raw in [b'{"embeddings":[[NaN]]}', b'{"embeddings":[[1e999]]}', b'not json', b'[]', b'x' * 256001]:
            with self.subTest(raw=raw[:30]), self.assertRaises(ValueError):
                await self.embed(lambda request: self.tags() if request.url.path == "/api/tags" else httpx.Response(200, content=raw))

    async def test_context_overflow_is_terminal_and_timeouts_are_bounded(self):
        with self.assertRaises(InvalidEmbeddingInput):
            await self.embed(lambda request: self.tags() if request.url.path == "/api/tags" else httpx.Response(400))
        async def slow(request):
            await asyncio.sleep(0.1)
            return self.tags()
        with self.assertRaises(asyncio.TimeoutError):
            await self.embed(slow, timeout=0.01)
        with self.assertRaises(InvalidEmbeddingInput):
            await self.embed(lambda _: self.fail("Must reject before HTTP"), content="x" * 10001)

    async def test_worker_preserves_revision_and_replays_publish_failure(self):
        adapter = AsyncMock(); adapter.spec = self.spec; adapter.embed.return_value = [1] + [0] * 767
        publish = AsyncMock(side_effect=RuntimeError("Kafka down"))
        with self.assertRaises(RuntimeError):
            await process_job(self.job.model_dump_json().encode(), adapter, publish)
        publish.side_effect = None
        await process_job(self.job.model_dump_json().encode(), adapter, publish)
        result = publish.call_args.args[1]
        self.assertEqual(result["contentRevision"], 2)
        self.assertEqual(result["model"], self.spec.id)
        self.assertNotIn("content", result)
        self.assertEqual(publish.call_count, 2)

    async def test_failures_are_sanitized_and_model_versions_are_not_mixed(self):
        adapter = AsyncMock(); adapter.spec = self.spec
        publish = AsyncMock()
        for error, expected in [(RuntimeError("private"), "provider_failed"), (ModelMismatch("private"), "model_mismatch"),
                                (InvalidEmbeddingInput("private"), "invalid_input")]:
            adapter.embed.side_effect = error
            await process_job(self.job.model_dump_json().encode(), adapter, publish)
            result = publish.call_args.args[1]
            self.assertEqual(result["error"], expected)
            self.assertNotIn("private", json.dumps(result))
        adapter.spec = model_spec("b" * 64); publish.reset_mock(); adapter.embed.reset_mock()
        await process_job(self.job.model_dump_json().encode(), adapter, publish)
        adapter.embed.assert_not_called(); publish.assert_not_called()

    async def test_malformed_jobs_do_not_invoke_provider(self):
        adapter = AsyncMock(); publish = AsyncMock()
        for raw in [b'[]', b'null', b'{}', b'x' * 65537]:
            await process_job(raw, adapter, publish)
        adapter.embed.assert_not_called(); publish.assert_not_called()
        with self.assertRaises(ValidationError):
            model_spec("mutable-tag")


if __name__ == "__main__":
    unittest.main()
