"""Optional training-stack integration; no GPU/model downloads or remote judge."""
import copy
import importlib.util
import json
import sys
import unittest
from unittest.mock import patch

DEPENDENCIES=('torch','transformers','peft','pandas','dotenv')
MISSING=[name for name in DEPENDENCIES if importlib.util.find_spec(name) is None]
if not MISSING:
    import torch
    import pandas as pd
    from elyrii_ai.training import evaluate
    from elyrii_ai.training.prompt_suite import load_test_prompts
    from elyrii_ai.training.benchmark.build import ROOT


@unittest.skipIf(MISSING,'Optional evaluation dependencies missing: '+', '.join(MISSING))
class EvaluationIntegrationTests(unittest.TestCase):
    def test_tokenizer_receives_only_fixed_messages_and_model_only_generates_continuation(self):
        case=next(c for c in load_test_prompts(ROOT/'cases.json') if len(c['messages'])>1)
        before=copy.deepcopy(case)
        captured={}

        class Tokenizer:
            eos_token_id=2
            pad_token_id=2

            def apply_chat_template(self,messages,**kwargs):
                captured['messages']=messages
                captured['template_kwargs']=kwargs
                return {'input_ids':torch.tensor([[1,3,4]]),'attention_mask':torch.ones((1,3),dtype=torch.long)}

            def decode(self,ids,**kwargs):
                captured['decoded_ids']=ids.tolist()
                return ' new response '

        class Model:
            device=torch.device('cpu')

            def generate(self,**kwargs):
                captured['generation']=kwargs
                return torch.cat((kwargs['input_ids'],torch.tensor([[7,2]])),dim=1)

        self.assertEqual(evaluate.generate_response(Model(),Tokenizer(),case),'new response')
        self.assertEqual(captured['decoded_ids'],[7,2])
        self.assertEqual(captured['messages'][1:],case['messages'][1:])
        self.assertEqual(captured['messages'][0]['content'],evaluate.SYSTEM_PROMPT+'\n\n'+case['messages'][0]['content'])
        self.assertNotIn('expected_behaviors',json.dumps(captured['messages']))
        self.assertTrue(captured['template_kwargs']['add_generation_prompt'])
        self.assertEqual(case,before)

    def test_main_preserves_case_context_and_saves_it_without_gemini(self):
        case=next(c for c in load_test_prompts(ROOT/'cases.json') if len(c['messages'])>1)
        argv=['evaluate','--adapter_path','final_lora','--no_gemini','--no_summary','--language','both']
        with patch.object(sys,'argv',argv), patch.object(evaluate,'load_test_prompts',return_value=[case]) as loader, patch.object(evaluate,'load_model_and_tokenizer',return_value=(None,None)), patch.object(evaluate,'pipeline'), patch.object(evaluate,'generate_response',return_value='response') as generate, patch.object(evaluate,'score_empathy',return_value=3), patch.object(evaluate,'score_toxicity',return_value=.01), patch.object(evaluate,'GEMINI_AVAILABLE',True), patch.object(evaluate,'GEMINI_API_KEY','dummy'), patch.object(evaluate,'evaluate_with_gemini') as judge, patch.object(evaluate.time,'sleep') as sleep, patch.object(pd.DataFrame,'to_csv',autospec=True) as save, patch.object(pd.DataFrame,'to_markdown',return_value='preview'):
            evaluate.main()
        generate.assert_called_once_with(None,None,case)
        judge.assert_not_called();sleep.assert_not_called()
        self.assertEqual(loader.call_args.args[2:],('development','all'))
        frame=save.call_args.args[0]
        self.assertEqual(json.loads(frame.iloc[0]['Conversation']),case['messages'])
        self.assertEqual(frame.iloc[0]['Split'],'development')


if __name__=='__main__': unittest.main()
