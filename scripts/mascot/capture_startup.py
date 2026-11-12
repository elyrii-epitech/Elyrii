"""Capture a cold iPhone launch without screen-recording support.

Each image's acquisition interval is recorded, not treated as a frame timestamp.
Run with --device UDID --bundle BUNDLE_ID --output /tmp/mascot-before.
"""
import argparse
import json
from pathlib import Path
import subprocess
import time


def capture(device, bundle, output, count):
    output.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    launch = subprocess.Popen(
        ['xcrun', 'devicectl', 'device', 'process', 'launch', '--device', device,
         '--terminate-existing', bundle],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )
    samples = []
    for index in range(count):
        path = output / f'{index:02d}.png'
        requested = time.monotonic() - started
        result = subprocess.run(
            ['xcrun', 'devicectl', 'device', 'capture', 'screenshot', '--device',
             device, '--destination', str(path)],
            capture_output=True, text=True, timeout=30,
        )
        sample = {
            'image': path.name,
            'requested_seconds': requested,
            'completed_seconds': time.monotonic() - started,
            'success': result.returncode == 0,
        }
        if result.returncode:
            sample['error'] = result.stderr or result.stdout
        samples.append(sample)
        print(json.dumps(sample), flush=True)
    stdout, stderr = launch.communicate(timeout=30)
    manifest = {'device': device, 'bundle': bundle, 'launch': stdout,
                'launch_success': launch.returncode == 0, 'samples': samples}
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    if launch.returncode:
        raise SystemExit(stderr or stdout)
    if any(not sample['success'] for sample in samples):
        raise SystemExit('Incomplete capture; inspect manifest.json.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--bundle', required=True)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--count', type=int, default=8)
    args = parser.parse_args()
    if args.count < 1:
        parser.error('--count must be positive')
    capture(args.device, args.bundle, args.output, args.count)
