"""CPU-only contract, isolation, migration and corruption regressions for #281."""
import copy
import json
import unittest
from pathlib import Path
from unittest.mock import patch

from jsonschema import ValidationError
from elyrii_ai.training.benchmark.build import ROOT, authored_cases
from elyrii_ai.training.benchmark.overlap import audit, read_training, similarity
from elyrii_ai.training.benchmark.validate import validate_cases, validate_suite, validate_calibration
from elyrii_ai.training.prompt_suite import generation_messages, load_test_prompts


class EvaluationSuiteTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.payload=json.loads((ROOT/'cases.json').read_text())
        cls.calibration=json.loads((ROOT/'calibration.json').read_text())

    def test_compiled_suite_manifest_and_smoke_reference(self):
        report=validate_suite()
        self.assertEqual(report['total'],400)
        self.assertEqual(report['multi_turn'],80)

    def test_default_excludes_held_out_and_filters_language_and_smoke(self):
        cases=load_test_prompts(ROOT/'cases.json')
        self.assertEqual(len(cases),300)
        self.assertEqual({c['split'] for c in cases},{'development'})
        self.assertEqual(len(load_test_prompts(ROOT/'cases.json','french')),150)
        self.assertEqual(len(load_test_prompts(ROOT/'cases.json',split='held_out')),100)
        self.assertEqual(len(load_test_prompts(ROOT/'cases.json',subset='smoke')),6)
        with self.assertRaises(ValueError):
            load_test_prompts(ROOT/'cases.json',split='held_out',subset='smoke')

    def test_generation_isolates_metadata_and_preserves_fixed_turns(self):
        case=copy.deepcopy(next(c for c in self.payload['cases'] if len(c['messages'])==3))
        before=copy.deepcopy(case)
        case['expected_behaviors']=['SECRET_EXPECTED_ANSWER']
        case['review']={'secret':'SECRET_RATING'}
        result=generation_messages(case,'PERSONA_POLICY')
        self.assertEqual([m['role'] for m in result],['user','assistant','user'])
        self.assertEqual(result[1:],before['messages'][1:])
        self.assertEqual(result[0]['content'],'PERSONA_POLICY\n\n'+before['messages'][0]['content'])
        self.assertNotIn('SECRET_',json.dumps(result))
        self.assertEqual(case['messages'],before['messages'])
        self.assertEqual(generation_messages('hello','system'),[{'role':'user','content':'system\n\nhello'}])

    def test_legacy_list_and_wrapper_still_load(self):
        rows=[{'language':'english','prompt':' Hello ','id':'old'}]
        for value in (rows,{'prompts':rows}):
            with patch.object(Path,'read_text',return_value=json.dumps(value)):
                loaded=load_test_prompts('unused.json')
                self.assertEqual(loaded[0]['messages'],[{'role':'user','content':'Hello'}])
                with self.assertRaises(ValueError): load_test_prompts('unused.json',split='held_out')
                with self.assertRaises(ValueError): load_test_prompts('unused.json',subset='smoke')

    def test_schema_rejects_unknown_fields_and_empty_expectations(self):
        for key,value in [('unrecognized',True),('expected_behaviors',[]),('generation','all_turns')]:
            payload=copy.deepcopy(self.payload);payload['cases'][0][key]=value
            with self.assertRaises(ValidationError): validate_cases(payload)

    def test_duplicate_ids_and_cross_split_families_are_rejected(self):
        payload=copy.deepcopy(self.payload)
        payload['cases'][1]['id']=payload['cases'][0]['id']
        with self.assertRaisesRegex(ValueError,'Duplicate'): validate_cases(payload)
        payload=copy.deepcopy(self.payload)
        payload['cases'][1]['split']='held_out'
        with self.assertRaisesRegex(ValueError,'leaks'): validate_cases(payload)

    def test_invalid_roles_missing_multiturn_tag_and_check_typo_are_rejected(self):
        for mutation in ('roles','tag','check'):
            payload=copy.deepcopy(self.payload)
            case=next(c for c in payload['cases'] if len(c['messages'])>1)
            if mutation=='roles': case['messages'][1]['role']='user'
            elif mutation=='tag': case['tags'].remove('multi_turn')
            else: case['checks'][0]['id']='nonemptty'
            with self.assertRaises(ValueError): validate_cases(payload)

    def test_unattributed_human_review_rejected(self):
        payload=copy.deepcopy(self.payload)
        payload['cases'][0]['review']['status']='human_reviewed'
        with self.assertRaisesRegex(ValueError,'reviewer'): validate_cases(payload)

    def test_calibration_is_development_only_and_not_falsely_human_rated(self):
        validate_calibration(self.calibration,self.payload['cases'])
        self.assertEqual(len(self.calibration['examples']),18)
        payload=copy.deepcopy(self.calibration)
        payload['examples'][0]['case_id']=next(c['id'] for c in self.payload['cases'] if c['split']=='held_out')
        with self.assertRaisesRegex(ValueError,'held-out'): validate_calibration(payload,self.payload['cases'])
        payload=copy.deepcopy(self.calibration);payload['status']='human_reviewed'
        with self.assertRaisesRegex(ValueError,'status'): validate_calibration(payload,self.payload['cases'])

    def test_contrast_pairs_stay_together(self):
        groups={}
        for case in self.payload['cases']:
            for tag in case['tags']:
                if tag.startswith('contrast:'): groups.setdefault(tag,[]).append(case)
        self.assertEqual(len(groups),4)
        for group in groups.values():
            self.assertEqual(len(group),4)
            self.assertEqual(len({c['scenario_family_id'] for c in group}),1)
            self.assertEqual(len({c['split'] for c in group}),1)

    def test_overlap_scanner_detects_normalized_exact_and_near_matches(self):
        cases=copy.deepcopy(self.payload['cases'][:2])
        cases[0]['messages']=[{'role':'user','content':'I need a little support with my difficult exam today'}]
        cases[1]['messages']=[{'role':'user','content':'I need a little support with my difficult exam tomorrow'}]
        cases[1]['split']='held_out'
        with patch('elyrii_ai.training.benchmark.overlap.read_training',return_value=iter([('train:0','I NEED A LITTLE SUPPORT WITH MY DIFFICULT EXAM TODAY!')])), patch.object(Path,'read_bytes',return_value=b'train'):
            report=audit(cases,[Path('train.json')])
        self.assertTrue(report['suite_findings'][0]['cross_split'])
        self.assertTrue(any(f['exact'] for f in report['training_findings']))
        self.assertEqual(audit(cases)['training_status'],'not_established_no_training_exports_supplied')
        self.assertEqual(similarity('Bonjour !','bonjour'),1)

    def test_training_import_fails_loudly_on_unsupported_records(self):
        for content in ('[{"unknown": "text"}]','[{"messages":[{"role":"user"}]}]'):
            with patch.object(Path,'read_text',return_value=content):
                with self.assertRaises(ValueError): list(read_training(Path('train.json')))


if __name__=='__main__': unittest.main()
