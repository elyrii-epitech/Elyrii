"""Optional live generation evaluation using pinned artifacts and synthetic journal context.
This measures response behavior, not embedding relevance or production retrieval latency.
"""
import argparse
import asyncio
import json
import math
import os
import statistics
import time
from datetime import datetime
from pathlib import Path
import httpx
from elyrii_ai.chat_context import NativePromptBudget, safe_sections, bounded_json, verify_generation_model
from elyrii_ai.prompt.system_prompt import get_system_prompt

async def evaluate(args):
    budget = NativePromptBudget.load(args.tokenizer_dir, args.model)
    fixtures = json.loads((Path(__file__).parents[1] / 'test/fixtures/journal_recall_v1.json').read_text())
    results = []
    previous = os.environ.get('ENABLE_JOURNAL_RECALL')
    os.environ['ENABLE_JOURNAL_RECALL'] = 'true'
    try:
        async with httpx.AsyncClient(base_url=args.url, timeout=120) as client:
            await verify_generation_model(client, budget)
            for case in fixtures:
                now = datetime.fromisoformat(case['now'].replace('Z','+00:00'))
                response = case['response']
                identity = {key:response[key] for key in ['userId','conversationId','sourceMessageId']}
                sections = safe_sections(response, identity, now)
                body, counts = budget.compose(get_system_prompt(1) + '\nRespond in ' + case['language'] + '.', response['query'], sections, now)
                body['options'].update({'temperature':0, 'seed':231})
                started = time.monotonic()
                output = await bounded_json(client, 'POST', '/api/generate', body, limit=200000)
                if output.get('done') is not True or not isinstance(output.get('response'),str): raise ValueError('Invalid generation')
                if output.get('prompt_eval_count',counts['inputTokens']) + budget.response_tokens > budget.window: raise ValueError('Provider budget mismatch')
                results.append({'case':case['id'],'response':output['response'],'rubric':case['rubric'],'review':'pending',
                    'counts':counts,'generationMs':(time.monotonic()-started)*1000,'providerInputTokens':output.get('prompt_eval_count'),
                    'providerOutputTokens':output.get('eval_count')})
            await verify_generation_model(client, budget)
    finally:
        if previous is None: os.environ.pop('ENABLE_JOURNAL_RECALL',None)
        else: os.environ['ENABLE_JOURNAL_RECALL'] = previous
    durations = sorted(r['generationMs'] for r in results)
    Path(args.output).write_text(json.dumps({'kind':'live generation with synthetic preselected journal context; review required',
        'model':budget.model,'digest':budget.digest,'generationP50Ms':statistics.median(durations),
        'generationP95Ms':durations[math.ceil(.95*len(durations))-1],'cases':results},ensure_ascii=False,indent=2)+'\n')

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tokenizer-dir',required=True)
    parser.add_argument('--model',required=True)
    parser.add_argument('--url',default='http://localhost:11434')
    parser.add_argument('--output',default='/tmp/journal-recall-live.json')
    asyncio.run(evaluate(parser.parse_args()))
