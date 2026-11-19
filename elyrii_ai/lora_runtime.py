"""Local PEFT-to-GGUF preparation and verified llama.cpp adapter serving.

Optional tooling dependencies live in requirements-lora.txt, not the Kafka bridge.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def inspect_adapter(folder, base_model_id, allow_zero=False):
    import numpy as np
    from safetensors.numpy import load_file

    root = Path(folder)
    config = json.loads((root / 'adapter_config.json').read_text())
    if config.get('base_model_name_or_path') != base_model_id:
        raise ValueError('Adapter base_model_name_or_path does not match --base-model-id')
    if config.get('peft_type') != 'LORA' or config.get('bias', 'none') != 'none':
        raise ValueError('Only standard LoRA without bias updates is supported')
    for option in ('use_dora', 'use_rslora', 'modules_to_save', 'rank_pattern', 'alpha_pattern',
                   'alora_invocation_tokens', 'use_qalora', 'layer_replication', 'target_parameters', 'fan_in_fan_out'):
        if config.get(option):
            raise ValueError(f'Unsupported adapter option: {option}')
    rank, alpha = config.get('r'), config.get('lora_alpha')
    if type(rank) is not int or rank <= 0 or type(alpha) not in (int, float) or not math.isfinite(alpha) or alpha <= 0:
        raise ValueError('Adapter rank and alpha must be positive finite values')
    tensors = load_file(root / 'adapter_model.safetensors')
    pairs = {}
    for name, tensor in tensors.items():
        suffix = next((s for s in ('.lora_A.weight', '.lora_B.weight') if name.endswith(s)), None)
        if suffix is None or tensor.ndim != 2 or not np.isfinite(tensor).all():
            raise ValueError(f'Unsupported or nonfinite adapter tensor: {name}')
        pairs.setdefault(name[:-len(suffix)], {})[suffix[6]] = tensor
    if not pairs:
        raise ValueError('Empty adapter')
    zero_updates = 0
    for name, pair in pairs.items():
        if set(pair) != {'A', 'B'} or pair['A'].shape[0] != rank or pair['B'].shape[1] != rank:
            raise ValueError(f'Missing or incompatible LoRA pair: {name}')
        if not np.any(pair['A']) or not np.any(pair['B']):
            zero_updates += 1
    all_zero = zero_updates == len(pairs)
    if all_zero and not allow_zero:
        raise ValueError('Every adapter update is zero. Supply a trained checkpoint, or --allow-zero-adapter for diagnostics.')
    if all_zero:
        print('WARNING: adapter is loaded but all updates are zero; this does not evaluate a fine-tuned model.', file=sys.stderr)
    return {'baseModelId': base_model_id, 'rank': rank, 'alpha': alpha, 'pairs': len(pairs),
            'zeroUpdatePairs': zero_updates, 'allUpdatesZero': all_zero,
            'sourceWeightsSha256': sha256(root / 'adapter_model.safetensors'),
            'sourceConfigSha256': sha256(root / 'adapter_config.json')}


def validate_base(model, config_dir):
    from gguf import GGUFReader
    config = json.loads((Path(config_dir) / 'config.json').read_text())
    if config.get('model_type') not in ('mistral', 'llama'):
        raise ValueError('This loader currently supports Mistral/Llama base models')
    reader = GGUFReader(str(model))
    if reader.fields['general.architecture'].contents() != 'llama':
        raise ValueError('Base GGUF architecture does not match Mistral/Llama')
    for field, key in [('block_count', 'num_hidden_layers'), ('embedding_length', 'hidden_size'),
                       ('feed_forward_length', 'intermediate_size'), ('attention.head_count', 'num_attention_heads'),
                       ('attention.head_count_kv', 'num_key_value_heads')]:
        if reader.fields['llama.' + field].contents() != config[key]:
            raise ValueError(f'Base GGUF/config mismatch: {key}')


def prepare(args):
    adapter, base = Path(args.adapter_dir).resolve(), Path(args.base_model).resolve()
    config_dir, converter_dir = Path(args.base_config).resolve(), Path(args.llama_cpp_dir).resolve()
    audit = inspect_adapter(adapter, args.base_model_id, args.allow_zero_adapter)
    validate_base(base, config_dir)
    destination = Path(args.output_dir).resolve()
    # A fresh directory prevents accidentally overwriting another adapter bundle.
    if destination.exists():
        raise ValueError('Output directory already exists; choose a new directory')
    converter = converter_dir / 'convert_lora_to_gguf.py'
    if not converter.is_file():
        raise ValueError('Missing llama.cpp convert_lora_to_gguf.py')
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=destination.parent) as temporary:
        output = Path(temporary)
        subprocess.run([sys.executable, str(converter), '--base', str(config_dir), '--outtype', 'f32',
                        '--outfile', str(output / 'adapter.gguf'), str(adapter)], check=True)
        # Do not publish a bundle if conversion raced with a source edit.
        if inspect_adapter(adapter, args.base_model_id, args.allow_zero_adapter) != audit:
            raise ValueError('Adapter changed during conversion')
        manifest = {'version': 1, 'baseModelPath': str(base), 'baseModelSha256': sha256(base),
                    'adapterSha256': sha256(output / 'adapter.gguf'), 'audit': audit,
                    'baseConfigSha256': sha256(config_dir / 'config.json'),
                    'converterSha256': sha256(converter)}
        (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
        output.rename(destination)
    print(destination / 'manifest.json')


def load_bundle(folder, allow_zero=False):
    root = Path(folder).resolve()
    manifest = json.loads((root / 'manifest.json').read_text())
    if manifest['version'] != 1:
        raise ValueError('Unsupported adapter manifest version')
    for path, expected in [(root / 'adapter.gguf', manifest['adapterSha256']),
                           (Path(manifest['baseModelPath']), manifest['baseModelSha256'])]:
        if sha256(path) != expected:
            raise ValueError(f'Artifact changed: {path}')
    if manifest['audit']['allUpdatesZero'] and not allow_zero:
        raise ValueError('Zero-update adapter requires --allow-zero-adapter')
    return manifest


def serve_command(args):
    manifest = load_bundle(args.bundle, args.allow_zero_adapter)
    if type(args.context_window) is not int or args.context_window <= 0:
        raise ValueError('Context window must be positive')
    if manifest['audit']['allUpdatesZero']:
        print('WARNING: serving a zero-update adapter for diagnostics only.', file=sys.stderr)
    return [args.llama_server, '-m', manifest['baseModelPath'], '--lora',
            str(Path(args.bundle).resolve() / 'adapter.gguf'), '--host', args.host,
            '--port', str(args.port), '-c', str(args.context_window), '-np', '1', '-ngl', str(args.gpu_layers)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    prepare_parser = commands.add_parser('prepare')
    for name in ('adapter-dir', 'base-model', 'base-model-id', 'base-config', 'llama-cpp-dir', 'output-dir'):
        prepare_parser.add_argument('--' + name, required=True)
    prepare_parser.add_argument('--allow-zero-adapter', action='store_true')
    serve = commands.add_parser('serve')
    serve.add_argument('--bundle', required=True)
    serve.add_argument('--llama-server', required=True)
    serve.add_argument('--host', default='127.0.0.1')
    serve.add_argument('--port', type=int, default=11436)
    serve.add_argument('--context-window', type=int, default=4096)
    serve.add_argument('--gpu-layers', type=int, default=0)
    serve.add_argument('--allow-zero-adapter', action='store_true')
    args = parser.parse_args()
    if args.command == 'prepare':
        prepare(args)
    else:
        command = serve_command(args)
        os.execvp(command[0], command)


if __name__ == '__main__':
    main()
