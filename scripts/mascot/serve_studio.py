"""Local motion review using the same model-viewer build as Flutter.
Run `flutter pub get` in elyrii_app first, then this script; open localhost:8766.
"""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[2]
CACHE = Path(os.environ.get('PUB_CACHE', str(Path.home()/'.pub-cache')))
ENGINE = CACHE/'hosted/pub.dev/flutter_3d_controller-2.3.0/assets/model_viewer.min.js'


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(Path(__file__).parent), **kwargs)

    def do_GET(self):
        route = urlparse(self.path).path
        resource = {
            '/velours.glb': ROOT/'elyrii_app/assets/elyrii_velours_animations.glb',
            '/model-viewer.min.js': ENGINE,
            '/': Path(__file__).parent/'studio.html',
        }.get(route)
        if resource:
            data = resource.read_bytes()
            self.send_response(200)
            self.send_header('Content-Type', self.guess_type(str(resource)))
            self.send_header('Content-Length', str(len(data)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(data)
        else:
            super().do_GET()


if __name__ == '__main__':
    if not ENGINE.exists():
        raise SystemExit('Run flutter pub get in elyrii_app to install the renderer.')
    print('Velours : http://127.0.0.1:8766', flush=True)
    ThreadingHTTPServer(('127.0.0.1', 8766), Handler).serve_forever()
