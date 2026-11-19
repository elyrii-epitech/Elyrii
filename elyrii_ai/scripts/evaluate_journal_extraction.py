"""Live synthetic evaluation; deterministic fixtures are expectations, never model results."""
import argparse
import asyncio
import json
import statistics
import time
from datetime import datetime, timezone
from pathlib import Path
import httpx
from elyrii_ai.journal_extraction import JournalExtractor, JournalInput, CONTEXT_TOKENS, MAX_GENERATION_TOKENS

class EvaluationExtractor(JournalExtractor):
    """Capture only synthetic fixture output for inspecting rejected proposals."""
    raw_output = None
    async def _infer(self, body):
        self.raw_output = await super()._infer(body)
        return self.raw_output

async def evaluate(args):
    cases = json.loads((Path(__file__).parents[1] / 'test/fixtures/journal_extraction_v1.json').read_text())
    rows = []
    async with httpx.AsyncClient(base_url=args.url, timeout=60) as client:
        # Record the resolved artifact digest instead of assuming a mutable tag is pinned.
        tags = (await client.get('/api/tags')).raise_for_status().json()
        model = next((m for m in tags.get('models', []) if m.get('name') in [args.model, args.model + ':latest']), None)
        if not model or not model.get('digest'): raise ValueError('Requested model artifact unavailable')
        extractor = EvaluationExtractor(client, args.model, timeout=60)
        for case in cases:
            start = time.monotonic()
            extractor.raw_output = None
            try:
                output = await extractor.extract(JournalInput.model_validate(case['input']))
                eligible = [p for p in output.candidates if p.certainty == 'certain' and p.candidate.origin == 'explicit' and p.subject == 'author' and p.assertion == 'affirmed']
                categories = sorted({p.category for p in eligible})
                expected = [case['expectedCategory']] if case['expectedCategory'] else []
                temporal_error = any(p.temporalExpression != case['expectedTemporalExpression'] for p in eligible)
                rows.append({'id':case['id'], 'status':'validated', 'classificationError':categories != expected,
                    'temporalError':temporal_error, 'evidenceQuotesExact':True, 'output':output.model_dump(),
                    'latencyMs':round((time.monotonic()-start)*1000), 'semanticEvidenceReview':'pending'})
            except Exception as exc:
                cause = exc
                while cause.__cause__ is not None: cause = cause.__cause__
                error = 'timeout' if isinstance(cause, asyncio.TimeoutError) else 'invalid_output' if extractor.raw_output is not None else 'provider_failed'
                rows.append({'id':case['id'], 'status':'extraction_failed', 'error':error,
                    'rawSyntheticOutput':extractor.raw_output, 'latencyMs':round((time.monotonic()-start)*1000)})
            print(json.dumps({k: rows[-1][k] for k in ('id', 'status', 'latencyMs')}), flush=True)
        final_tags = (await client.get('/api/tags')).raise_for_status().json()
        if not any(m.get('name') == model['name'] and m.get('digest') == model['digest'] for m in final_tags.get('models', [])):
            raise ValueError('Model artifact changed during evaluation')
    valid = [r for r in rows if r['status'] == 'validated']
    report = {'kind':'live_model_synthetic_journal_extraction', 'model':args.model, 'digest':model['digest'],
        'evaluatedAt':datetime.now(timezone.utc).isoformat(), 'cases':rows,
        'configuration':{'contextTokens':CONTEXT_TOKENS, 'evaluationTimeoutSeconds':60, 'generationTokens':MAX_GENERATION_TOKENS},
        'metrics':{'total':len(rows), 'validated':len(valid), 'failures':len(rows)-len(valid),
            'validatedEvidenceQuoteCount':sum(len(r['output']['candidates']) for r in valid),
            'exactEvidenceRateAmongValidated':1.0 if any(r['output']['candidates'] for r in valid) else None,
            'classificationErrors':sum(r['classificationError'] for r in valid), 'temporalErrors':sum(r['temporalError'] for r in valid),
            'medianLatencyMs':statistics.median(r['latencyMs'] for r in rows),
            'exceededWorkerDefault20s':sum(r['latencyMs'] > 20000 for r in rows)},
        'limitations':'Exact quotation is not semantic entailment. Review every output against its synthetic fixture for author attribution, polarity, uncertainty and unsupported claims. These metrics are separate from mocked tests.'}
    Path(args.output).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url',default='http://localhost:11434')
    parser.add_argument('--model',required=True)
    parser.add_argument('--output',default='/tmp/journal-extraction-evaluation.json')
    asyncio.run(evaluate(parser.parse_args()))
