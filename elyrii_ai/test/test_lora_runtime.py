import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
import httpx
from elyrii_ai.lora_runtime import inspect_adapter, load_bundle, serve_command, sha256
from elyrii_ai.lora_evaluation import verify_loaded_adapter, generate

try:
    import numpy as np
    from safetensors.numpy import save_file
except ImportError:
    np = None


@unittest.skipIf(np is None, 'optional requirements-lora.txt dependencies not installed')
class AdapterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.config = {'peft_type': 'LORA', 'base_model_name_or_path': 'base', 'r': 2, 'lora_alpha': 4}
        self.tensors = {'layer.lora_A.weight': np.ones((2, 3), dtype=np.float32),
                        'layer.lora_B.weight': np.ones((4, 2), dtype=np.float32)}
        self.save()

    def save(self):
        (self.root / 'adapter_config.json').write_text(json.dumps(self.config))
        save_file(self.tensors, self.root / 'adapter_model.safetensors')

    def test_standard_adapter(self):
        audit = inspect_adapter(self.root, 'base')
        self.assertEqual(audit['pairs'], 1)
        self.assertFalse(audit['allUpdatesZero'])

    def test_wrong_base(self):
        with self.assertRaisesRegex(ValueError, 'base_model_name'):
            inspect_adapter(self.root, 'different')

    def test_zero_checkpoint_requires_override(self):
        self.tensors['layer.lora_B.weight'][:] = 0
        self.save()
        with self.assertRaisesRegex(ValueError, 'Every adapter update is zero'):
            inspect_adapter(self.root, 'base')
        self.assertTrue(inspect_adapter(self.root, 'base', True)['allUpdatesZero'])

    def test_missing_pair_and_nonfinite_rejected(self):
        del self.tensors['layer.lora_B.weight']
        self.save()
        with self.assertRaisesRegex(ValueError, 'LoRA pair'):
            inspect_adapter(self.root, 'base')
        self.tensors['layer.lora_A.weight'][0, 0] = float('nan')
        self.save()
        with self.assertRaisesRegex(ValueError, 'nonfinite'):
            inspect_adapter(self.root, 'base')

    def test_unsupported_variant_rejected(self):
        self.config['use_dora'] = True
        self.save()
        with self.assertRaisesRegex(ValueError, 'use_dora'):
            inspect_adapter(self.root, 'base')


class BundleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.base = self.root / 'base with spaces.gguf'
        self.base.write_bytes(b'base fixture')
        (self.root / 'adapter.gguf').write_bytes(b'adapter fixture')
        self.manifest = {'version': 1, 'baseModelPath': str(self.base),
                         'baseModelSha256': sha256(self.base), 'adapterSha256': sha256(self.root / 'adapter.gguf'),
                         'audit': {'allUpdatesZero': False}}
        self.save()

    def save(self):
        (self.root / 'manifest.json').write_text(json.dumps(self.manifest))

    def test_changed_base_and_adapter_rejected(self):
        self.assertEqual(load_bundle(self.root), self.manifest)
        self.base.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'Artifact changed'):
            load_bundle(self.root)
        self.base.write_bytes(b'base fixture')
        (self.root / 'adapter.gguf').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'Artifact changed'):
            load_bundle(self.root)

    def test_zero_bundle_requires_explicit_launch_override(self):
        self.manifest['audit']['allUpdatesZero'] = True
        self.save()
        with self.assertRaisesRegex(ValueError, 'Zero-update'):
            load_bundle(self.root)
        self.assertEqual(load_bundle(self.root, True), self.manifest)

    def test_launcher_preserves_paths_as_arguments(self):
        command = serve_command(SimpleNamespace(bundle=self.root, allow_zero_adapter=False,
                    context_window=4096, llama_server='/server with spaces', host='127.0.0.1', port=11436, gpu_layers=0))
        self.assertEqual(command[0], '/server with spaces')
        self.assertEqual(command[2], str(self.base))
        self.assertIn('--lora', command)
        self.assertNotIn('shell', command)


class ServingTests(unittest.IsolatedAsyncioTestCase):
    async def test_server_must_report_exact_base_adapter_scale_and_context(self):
        adapter = [{'path': '/bundle/adapter.gguf', 'scale': 1.0}]
        props = {'model_path': '/base.gguf', 'default_generation_settings': {'n_ctx': 4096}}
        def handler(request):
            return httpx.Response(200, json=adapter if request.url.path == '/lora-adapters' else props)
        async with httpx.AsyncClient(base_url='http://test', transport=httpx.MockTransport(handler)) as client:
            budget = SimpleNamespace(window=4096)
            await verify_loaded_adapter(client, '/bundle', {'baseModelPath': '/base.gguf'}, budget)
            for invalid in [[], [{'path': '/bundle/adapter.gguf', 'scale': 0}], [{'path': '/other', 'scale': 1}]]:
                adapter[:] = invalid
                with self.assertRaises(ValueError):
                    await verify_loaded_adapter(client, '/bundle', {'baseModelPath': '/base.gguf'}, budget)
            adapter[:] = [{'path': '/bundle/adapter.gguf', 'scale': 1}]
            props['model_path'] = '/wrong'
            with self.assertRaises(ValueError):
                await verify_loaded_adapter(client, '/bundle', {'baseModelPath': '/base.gguf'}, budget)
            props['model_path'] = '/base.gguf'
            props['default_generation_settings']['n_ctx'] = 512
            with self.assertRaises(ValueError):
                await verify_loaded_adapter(client, '/bundle', {'baseModelPath': '/base.gguf'}, budget)

    async def test_budget_checked_before_generation_and_truncation_rejected(self):
        requests = []
        token_count = 20
        output = {'content': 'reply', 'truncated': False, 'tokens_evaluated': 20, 'tokens_predicted': 2}
        def handler(request):
            requests.append(request.url.path)
            return httpx.Response(200, json={'tokens': [1] * token_count} if request.url.path == '/tokenize' else output)
        async with httpx.AsyncClient(base_url='http://test', transport=httpx.MockTransport(handler)) as client:
            budget = SimpleNamespace(window=64, response_tokens=16)
            self.assertEqual((await generate(client, {'prompt': 'test'}, budget))['response'], 'reply')
            token_count = 60
            requests.clear()
            with self.assertRaisesRegex(ValueError, 'before generation'):
                await generate(client, {'prompt': 'test'}, budget)
            self.assertEqual(requests, ['/tokenize'])
            token_count = 20
            output['truncated'] = True
            with self.assertRaisesRegex(ValueError, 'truncated'):
                await generate(client, {'prompt': 'test'}, budget)
