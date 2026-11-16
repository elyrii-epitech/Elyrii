import unittest
from pydantic import ValidationError
from elyrii_ai.context_sources import SourceResult


class SourceContractTests(unittest.TestCase):
    def payload(self):
        return {"version": 2, "eventId": "11111111-1111-4111-8111-111111111111",
                "userId": "22222222-2222-4222-8222-222222222222", "generation": 0,
                "source": {"kind": "journal", "id": "33333333-3333-4333-8333-333333333333", "revision": 2},
                "candidates": [{"kind": "memory", "content": "Graduated in Paris", "origin": "explicit", "retention": "long_term", "eventAt": None}]}

    def test_journal_contract_needs_no_conversation(self):
        payload = self.payload()
        self.assertEqual(SourceResult.model_validate(payload).model_dump(), payload)
        payload["source"]["kind"] = "chat"
        self.assertEqual(SourceResult.model_validate(payload).source.kind, "chat")

    def test_rejects_unversioned_or_injected_provenance_and_expiry(self):
        for override in [{"version": 1}, {"conversationId": "invented"}, {"generation": -1}, {"sourceMessageId": "fake"}]:
            with self.assertRaises(ValidationError): SourceResult.model_validate({**self.payload(), **override})
        for revision in [0, -1, True, "1"]:
            payload = self.payload(); payload["source"]["revision"] = revision
            with self.assertRaises(ValidationError): SourceResult.model_validate(payload)
        for key, value in [("expiresAt", "2099-01-01T00:00:00Z"), ("sourceMessageId", "fake"), ("validFrom", "2030-01-01T00:00:00Z")]:
            payload = self.payload(); payload["candidates"][0][key] = value
            with self.assertRaises(ValidationError): SourceResult.model_validate(payload)
