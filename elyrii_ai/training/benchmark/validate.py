"""Validate schema, suite composition, provenance, and isolation without inference."""
import argparse
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path

from jsonschema import Draft202012Validator
from elyrii_ai.training.prompt_suite import validate_messages
from .build import CATEGORIES, ROOT, SMOKE, authored_cases, checks_for


def require(condition, message):
    if not condition: raise ValueError(message)


def validate_cases(payload):
    schema=json.loads((ROOT/'schema.json').read_text())
    Draft202012Validator(schema).validate(payload)
    cases=payload['cases']
    ids=set(); families=defaultdict(set)
    for c in cases:
        require(c['id'] not in ids, 'Duplicate case ID: '+c['id']); ids.add(c['id'])
        validate_messages(c['messages'])
        families[c['scenario_family_id']].add(c['split'])
        require(('multi_turn' in c['tags']) == (len(c['messages'])>1),'Incorrect multi-turn tag: '+c['id'])
        require(c['review']['status']!='human_reviewed' or bool(c['review']['human_reviewer'] and c['review']['human_reviewer'].strip()),'Human review requires a named reviewer')
        require(c['review']['status']!='draft' or c['review']['human_reviewer'] is None,'Draft case must not claim a human reviewer')
        # Check definitions are versioned alongside authoring; reject typos,
        # wrong methods, or parameters rather than silently skipping checks.
        category,number=c['provenance']['source_row'].split(':')
        require(category==c['category'],'Source category mismatch')
        require(1<=int(number)<=20,'Invalid source scenario number')
        require(c['checks']==checks_for(category,int(number),c['language']),'Unknown or mismatched check definition: '+c['id'])
    require(all(len(splits)==1 for splits in families.values()),'Scenario family leaks across splits')
    return cases


def validate_suite(root=ROOT):
    payload=json.loads((root/'cases.json').read_text())
    cases=validate_cases(payload)
    require(cases==authored_cases(),'Compiled cases differ from authored sources; rebuild')
    require(len(cases)==400,'Expected 400 cases')
    require(Counter(c['language'] for c in cases)=={'english':200,'french':200},'Language imbalance')
    require(Counter(c['split'] for c in cases)=={'development':300,'held_out':100},'Split counts incorrect')
    for category in CATEGORIES:
        for lang in ('english','french'):
            group=[c for c in cases if c['category']==category and c['language']==lang]
            require(len(group)==20,'Category/language count incorrect')
            require(Counter(c['split'] for c in group)=={'development':15,'held_out':5},'Category split imbalance')
    for lang in ('english','french'):
        require(sum(len(c['messages'])>1 for c in cases if c['language']==lang)>=40,'Too few multi-turn cases')
    groups=defaultdict(list)
    for c in cases: groups[c['provenance']['source_row']].append(c)
    for group in groups.values():
        require(len(group)==2 and {c['language'] for c in group}=={'english','french'},'Missing translation counterpart')
        require(len({(c['split'],c['scenario_family_id']) for c in group})==1,'Translation pair leaks across splits/families')
    smoke=[c for c in cases if 'smoke' in c['tags']]
    require({c['id'] for c in smoke}==set(SMOKE.values()),'Smoke membership changed')
    require(all(c['split']=='development' for c in smoke),'Smoke cases must be development only')
    original=json.loads((root/'smoke_reference.json').read_text())
    require({c['id']:c['messages'][-1]['content'] for c in smoke}==original,'Original smoke wording changed')
    manifest=json.loads((root/'manifest.json').read_text())
    actual={'suite_version':payload['suite_version'],'sha256':hashlib.sha256((root/'cases.json').read_bytes()).hexdigest(),
            'total':len(cases),'languages':dict(Counter(c['language'] for c in cases)),
            'splits':dict(Counter(c['split'] for c in cases)),
            'categories':dict(Counter(c['category'] for c in cases)),
            'multi_turn':sum(len(c['messages'])>1 for c in cases),'smoke_ids':[c['id'] for c in smoke],
            'review_status':'human_reviewed' if all(c['review']['status']=='human_reviewed' for c in cases) else 'draft_pending_human_review'}
    for k,v in actual.items(): require(manifest[k]==v,'Manifest mismatch: '+k)
    validate_calibration(json.loads((root/'calibration.json').read_text()),cases)
    return actual


def validate_calibration(payload,cases):
    case_map={c['id']:c for c in cases}; seen=set(); coverage=defaultdict(set)
    require(payload['status'] in {'pending_human_review','human_reviewed'},'Invalid calibration review status')
    for example in payload['examples']:
        require(example['id'] not in seen,'Duplicate calibration ID'); seen.add(example['id'])
        case=case_map[example['case_id']]
        require(case['split']=='development','Calibration must not use held-out cases')
        require(example['language']==case['language'],'Calibration language mismatch')
        require(example['proposed_rating'] in {'good','bad','ambiguous'},'Invalid proposed rating')
        require(bool(example['response'].strip()) and bool(example['rationale'].strip()),'Empty calibration response/rationale')
        require(example['human_rating'] in {None,'good','bad','ambiguous'},'Invalid human rating')
        require((example['human_rating'] is None) == (example['reviewer'] is None),'Human rating requires reviewer attribution')
        if example['reviewer'] is not None:
            require(isinstance(example['reviewer'],str) and bool(example['reviewer'].strip()),'Empty reviewer attribution')
        for field in ('review_notes','suggested_response'):
            require(example.get(field) is None or isinstance(example[field],str),f'{field} must be text or null')
        suggestion_rating=example.get('suggested_response_rating')
        suggestion_reviewer=example.get('suggested_response_reviewed_by')
        require(suggestion_rating in {None,'good','bad','ambiguous'},'Invalid suggested_response_rating')
        require((suggestion_rating is None)==(suggestion_reviewer is None),'Suggested response rating requires reviewer attribution')
        if suggestion_rating is not None:
            require(bool(example.get('suggested_response') and example['suggested_response'].strip()),'Rated suggested_response must contain text')
            require(isinstance(suggestion_reviewer,str) and bool(suggestion_reviewer.strip()),'Empty suggested response reviewer attribution')
        coverage[case['language']].add(example['proposed_rating'])
    require(coverage=={'english':{'good','bad','ambiguous'},'french':{'good','bad','ambiguous'}},'Incomplete calibration coverage')
    require((payload['status']=='human_reviewed') == all(e['human_rating'] is not None for e in payload['examples']),'Calibration review status disagrees with recorded ratings')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=ROOT)
    args=parser.parse_args()
    print(json.dumps(validate_suite(args.root),indent=2))

if __name__=='__main__': main()
