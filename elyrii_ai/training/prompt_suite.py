"""CPU-only benchmark loading and generation-input isolation."""
import copy
import json
from pathlib import Path

DEFAULT_PROMPTS_FILE = Path(__file__).with_name('benchmark') / 'cases.json'


def validate_messages(messages):
    if not isinstance(messages, list) or not messages or len(messages) % 2 != 1:
        raise ValueError('Messages must contain alternating fixed turns ending in a user turn')
    for index, message in enumerate(messages):
        if not isinstance(message, dict) or set(message) != {'role', 'content'}:
            raise ValueError('Messages require exactly role and content')
        if message['role'] != ('user' if index % 2 == 0 else 'assistant'):
            raise ValueError('Messages must alternate user/assistant, starting with user')
        if not isinstance(message['content'], str) or not message['content'].strip():
            raise ValueError('Message content must be nonempty text')


def generation_messages(case_or_prompt, system_prompt):
    """Only messages enter the model; rubric, labels and review metadata never do."""
    messages = ([{'role':'user','content':case_or_prompt}] if isinstance(case_or_prompt,str)
                else copy.deepcopy(case_or_prompt['messages']))
    validate_messages(messages)
    # Mistral's template accepts alternating user/assistant roles. Preserve the
    # existing persona placement, once, in the first user turn.
    messages[0]['content'] = system_prompt + '\n\n' + messages[0]['content']
    return messages


def load_test_prompts(prompts_file, language='both', split='development', subset='all'):
    if language not in {'english','french','both'} or split not in {'development','held_out','all'} or subset not in {'all','smoke'}:
        raise ValueError('Unsupported language, split, or subset')
    payload = json.loads(Path(prompts_file).read_text())
    versioned = isinstance(payload,dict) and 'cases' in payload
    if versioned:
        from elyrii_ai.training.benchmark.validate import validate_cases
        validate_cases(payload)
        raw = payload['cases']
    else:
        raw = payload.get('prompts') if isinstance(payload,dict) else payload
        if not isinstance(raw,list):
            raise ValueError("Expected a prompt list, 'prompts' list, or versioned 'cases' suite")
        if subset != 'all' or split == 'held_out':
            raise ValueError('Legacy prompt files have no smoke tags or held-out split')
    result=[]
    seen=set()
    for index,item in enumerate(raw,1):
        if not isinstance(item,dict): raise ValueError('Prompt must be an object')
        lang=item.get('language','').lower()
        if lang not in {'english','french'}: raise ValueError('Unsupported prompt language')
        if versioned:
            case=copy.deepcopy(item)
            if split!='all' and case['split']!=split: continue
            if subset=='smoke' and 'smoke' not in case['tags']: continue
        else:
            prompt=item.get('prompt')
            if not isinstance(prompt,str) or not prompt.strip(): raise ValueError('Prompt must be nonempty text')
            case={'id':str(item.get('id',f'prompt_{index}')), 'language':lang,
                  'category':str(item.get('category','uncategorized')),
                  'messages':[{'role':'user','content':prompt.strip()}]}
        if case['id'] in seen: raise ValueError('Duplicate prompt ID: '+case['id'])
        seen.add(case['id'])
        if language!='both' and lang!=language: continue
        case['prompt']=case['messages'][-1]['content']
        result.append(case)
    if not result: raise ValueError('No prompts match the requested language/split/subset')
    return result
