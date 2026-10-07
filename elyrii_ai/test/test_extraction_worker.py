import copy
import json
import unittest
from pathlib import Path
from unittest.mock import AsyncMock

from elyrii_ai.extraction import ExtractionError, ExtractionResult
from elyrii_ai.extraction_worker import process_job


class WorkerTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        fixture = json.loads((Path(__file__).parent / "fixtures/extraction_v1.json").read_text())[0]
        self.job = {"version": 1, "jobId": "22222222-2222-4222-8222-222222222222",
                    "requestId": "33333333-3333-4333-8333-333333333333", "userId": "44444444-4444-4444-8444-444444444444",
                    "conversationId": "a", "sourceMessageId": fixture["request"]["source"]["id"],
                    "extractorVersion": "v1", "attempt": 1, "input": fixture["request"]}
        self.output = ExtractionResult.model_validate(fixture["output"])
        self.extractor = AsyncMock()
        self.extractor.extract.return_value = self.output
        self.publish = AsyncMock()

    async def test_success_preserves_correlation_without_echoing_input(self):
        await process_job(json.dumps(self.job).encode(), self.extractor, self.publish)
        owner, result = self.publish.call_args.args
        self.assertEqual(owner, self.job["userId"])
        self.assertEqual(result, {**{k: v for k, v in self.job.items() if k != "input"},
                                  "status": "success", "output": self.output.model_dump()})

    async def test_model_outage_emits_bounded_failure(self):
        self.extractor.extract.side_effect = ExtractionError("private model output")
        await process_job(json.dumps(self.job).encode(), self.extractor, self.publish)
        result = self.publish.call_args.args[1]
        self.assertEqual(result["error"], "inference_failed")
        self.assertNotIn("private", json.dumps(result))
        self.assertNotIn("output", result)

    async def test_publish_failure_escapes_for_redelivery(self):
        self.publish.side_effect = RuntimeError("Kafka down")
        with self.assertRaises(RuntimeError):
            await process_job(json.dumps(self.job).encode(), self.extractor, self.publish)
        self.publish.side_effect = None
        await process_job(json.dumps(self.job).encode(), self.extractor, self.publish)
        self.assertEqual(self.publish.call_count, 2)

    async def test_untrusted_envelopes_do_not_run_inference(self):
        invalid = copy.deepcopy(self.job)
        invalid["sourceMessageId"] = invalid["jobId"]
        for raw in [b"not json", b"[]", b"x" * 65537, json.dumps(invalid).encode()]:
            await process_job(raw, self.extractor, self.publish)
        self.extractor.extract.assert_not_called()
        self.publish.assert_not_called()

    async def test_empty_result_is_success(self):
        self.extractor.extract.return_value = ExtractionResult(promptVersion="v1", candidates=[])
        await process_job(json.dumps(self.job).encode(), self.extractor, self.publish)
        self.assertEqual(self.publish.call_args.args[1]["output"]["candidates"], [])


if __name__ == "__main__":
    unittest.main()
