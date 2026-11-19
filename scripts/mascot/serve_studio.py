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
            '/wardrobe': Path(__file__).parent/'wardrobe.html',
            '/wardrobe.glb': ROOT/'elyrii_app/assets/optimized/mascot_wardrobe.glb',
            '/poster': Path(__file__).parent/'render_poster.html',
            '/material-script.js': ROOT/'elyrii_app/lib/core/widgets/mascot_material_script.dart',
            '/motion-script.js': ROOT/'elyrii_app/lib/core/widgets/mascot_motion_script.dart',
            '/scene-script.js': ROOT/'elyrii_app/lib/core/widgets/mascot_scene_script.dart',
        }.get(route)
        if resource:
            data = resource.read_bytes()
            if route == '/scene-script.js':
                script = data.decode().split("'''", 1)[1].rsplit("'''", 1)[0]
                for name, filename in (
                    ('mascotMotionScript', 'mascot_motion_script.dart'),
                    ('mascotMaterialScript', 'mascot_material_script.dart'),
                ):
                    source = (resource.parent/filename).read_text()
                    body = source.split("r'''", 1)[1].rsplit("'''", 1)[0]
                    script = script.replace('$'+name, body)
                data = ('export function installScene(m){' + script + '\n}').encode()
            if route in ('/material-script.js', '/motion-script.js'):
                script = data.decode().split("r'''", 1)[1].rsplit("'''", 1)[0]
                prefix = (
                    'export async function applyAppearance(m,appearance){'
                    'const revision=m.elyriiAppearanceRevision='
                    '(m.elyriiAppearanceRevision||0)+1;'
                    if route == '/material-script.js'
                    else 'export function installMotion(m){'
                )
                data = (prefix + script + '\n}').encode()
            self.send_response(200)
            content_type = 'text/javascript' if route.endswith('-script.js') else self.guess_type(str(resource))
            self.send_header('Content-Type', content_type)
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
