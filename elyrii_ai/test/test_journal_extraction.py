import copy
import json
import unittest
from pathlib import Path
from unittest.mock import AsyncMock
import httpx
from pydantic import ValidationError
from elyrii_ai.journal_extraction import JournalInput, JournalExtractor, validate_journal_output, ExtractionError
from elyrii_ai.journal_extraction_worker import process_job
CASES = json.loads((Path(__file__).parent / 'fixtures/journal_extraction_v1.json').read_text())

class JournalTests(unittest.IsolatedAsyncioTestCase):
    def test_bilingual_contract_fixtures(self):
        for case in CASES:
            request = JournalInput.model_validate(case['input'])
            self.assertEqual(validate_journal_output(json.dumps(case['output']), request).model_dump(), case['output'])

    def test_whole_entry_limits_include_tail(self):
        data = copy.deepcopy(CASES[3]['input'])
        data['source']['body'] = 'x' * 20000 + '\n' + CASES[3]['input']['source']['body']
        validate_journal_output(json.dumps(CASES[3]['output']), JournalInput.model_validate(data))
        for body in ['x' * 24000, 'é' * 12000]:
            data['source']['body'] = body
            with self.assertRaises(ValidationError): JournalInput.model_validate(data)

    def test_invalid_fragment_rejects_entire_result(self):
        data = copy.deepcopy(CASES[0]['output'])
        bad = copy.deepcopy(data['candidates'][0]); bad['evidence'] = 'invented claim'
        data['candidates'].append(bad)
        with self.assertRaises(ExtractionError): validate_journal_output(json.dumps(data), JournalInput.model_validate(CASES[0]['input']))
        data = copy.deepcopy(CASES[1]['output']); data['candidates'][0]['candidate']['eventAt'] = '2026-10-20T00:00:00Z'
        with self.assertRaises(ExtractionError): validate_journal_output(json.dumps(data), JournalInput.model_validate(CASES[1]['input']))

    async def test_http_schema_and_incomplete_output(self):
        async def handler(request):
            body = json.loads(request.content)
            self.assertEqual(body['options']['temperature'], 0)
            self.assertEqual(body['options']['num_ctx'], 32768)
            self.assertIn('UNTRUSTED', body['messages'][0]['content'])
            return httpx.Response(200,json={'done':True,'done_reason':'length','message':{'content':json.dumps(CASES[0]['output'])}})
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler),base_url='http://model.test') as client:
            with self.assertRaises(ExtractionError): await JournalExtractor(client,'test').extract(JournalInput.model_validate(CASES[0]['input']))

    async def test_worker_failure_redelivery_and_empty(self):
        request=CASES[0]['input']
        job={'version':2,'jobId':'22222222-2222-4222-8222-222222222222','eventId':'33333333-3333-4333-8333-333333333333','userId':'44444444-4444-4444-8444-444444444444','generation':0,
             'source':{k:request['source'][k] for k in ('kind','id','revision')},'extractorVersion':'journal-v1','attempt':1,'input':request}
        extractor=AsyncMock(); publish=AsyncMock(); extractor.extract.side_effect=RuntimeError('private content')
        await process_job(json.dumps(job).encode(),extractor,publish)
        self.assertEqual(publish.call_args.args[1]['error'],'inference_failed')
        self.assertNotIn('private',json.dumps(publish.call_args.args[1]))
        extractor.extract.side_effect=None
        extractor.extract.return_value=validate_journal_output('{"promptVersion":"journal-v1","candidates":[]}',JournalInput.model_validate(request))
        publish.side_effect=RuntimeError('offline')
        with self.assertRaises(RuntimeError): await process_job(json.dumps(job).encode(),extractor,publish)
        publish.side_effect=None
        await process_job(json.dumps(job).encode(),extractor,publish)
        self.assertEqual(publish.call_args.args[1]['output']['candidates'],[])
