"""Verified local llama.cpp inference for the journal evaluation harness."""
from pathlib import Path
from .chat_context import bounded_json


async def verify_loaded_adapter(client, bundle, manifest, budget):
    adapters = await bounded_json(client, 'GET', '/lora-adapters', limit=64000)
    expected = str(Path(bundle).resolve() / 'adapter.gguf')
    if (not isinstance(adapters, list) or len(adapters) != 1
            or adapters[0].get('path') != expected or adapters[0].get('scale') != 1.0):
        raise ValueError('Expected exactly the pinned adapter loaded at scale 1.0')
    properties = await bounded_json(client, 'GET', '/props')
    if properties.get('model_path') != manifest['baseModelPath']:
        raise ValueError('Serving base model path does not match the adapter bundle')
    if properties.get('default_generation_settings', {}).get('n_ctx', 0) < budget.window:
        raise ValueError('Serving context window is smaller than the pinned tokenizer budget')


async def generate(client, body, budget):
    tokens = await bounded_json(client, 'POST', '/tokenize', {'content': body['prompt'], 'add_special': True})
    ids = tokens.get('tokens')
    if not isinstance(ids, list) or not ids or any(type(token) is not int for token in ids):
        raise ValueError('Invalid provider tokenization')
    if len(ids) + budget.response_tokens > budget.window:
        raise ValueError('Provider budget mismatch before generation')
    output = await bounded_json(client, 'POST', '/completion', {
        'prompt': body['prompt'], 'n_predict': budget.response_tokens,
        'temperature': 0, 'seed': 231, 'stream': False, 'cache_prompt': False,
    }, limit=200000)
    if (not isinstance(output.get('content'), str) or output.get('truncated') is not False
            or type(output.get('tokens_evaluated')) is not int
            or type(output.get('tokens_predicted')) is not int
            or output['tokens_evaluated'] <= 0
            or output['tokens_evaluated'] + budget.response_tokens > budget.window
            or not 0 <= output['tokens_predicted'] <= budget.response_tokens):
        raise ValueError('Invalid, truncated or over-budget generation')
    return {'done': True, 'response': output['content'], 'prompt_eval_count': output['tokens_evaluated'],
            'eval_count': output['tokens_predicted'], 'done_reason': output.get('stop_type')}
