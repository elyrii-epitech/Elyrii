"""Offline CycloneDX inventory of the locked Dart graph and embedded assets.

Run after `flutter pub deps --json > build/pub-deps.json` and locked pub get.
Native Gradle/CocoaPods dependencies require their own inventory after a build.
"""
import argparse
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote, unquote, urlparse


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--deps", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    packages = json.loads(args.deps.read_text())["packages"]
    lock = root / "pubspec.lock"
    locked = {}
    for name, block in re.findall(r"^  ([\w]+):\n(.*?)(?=^  \w+:|^sdks:|\Z)", lock.read_text(), re.M | re.S):
        version = re.search(r'^    version: "([^"]+)"', block, re.M)
        sha = re.search(r'^      sha256: "?([a-f0-9]{64})"?', block, re.M)
        locked[name] = {"version": version[1] if version else None, "sha": sha[1] if sha else None}

    def ref(package):
        return "pkg:pub/" + package["name"] + "@" + quote(package["version"], safe="")

    refs = {package["name"]: ref(package) for package in packages}
    components = []
    edges = []
    application = None
    for package in packages:
        component = {"type": "application" if package["kind"] == "root" else "library",
                     "bom-ref": ref(package), "name": package["name"], "version": package["version"],
                     "purl": ref(package), "properties": [{"name": "elyrii:source", "value": package["source"]}]}
        if package["kind"] == "root":
            application = component
        else:
            if package["name"] not in locked or locked[package["name"]]["version"] != package["version"]:
                raise ValueError("Installed dependency differs from lock: " + package["name"])
            if locked[package["name"]]["sha"]:
                component["properties"].append({"name": "elyrii:pub-archive-sha256", "value": locked[package["name"]]["sha"]})
            components.append(component)
        edges.append({"ref": ref(package), "dependsOn": [refs[n] for n in package.get("dependencies", [])]})
    if application is None:
        raise ValueError("No root application in pub dependency graph")

    config = root / ".dart_tool/package_config.json"
    viewer = next(p for p in json.loads(config.read_text())["packages"] if p["name"] == "flutter_3d_controller")
    uri = urlparse(viewer["rootUri"])
    viewer_root = Path(unquote(uri.path)) if uri.scheme == "file" else (config.parent / unquote(uri.path)).resolve()
    files = [(viewer_root / "assets/model_viewer.min.js", "embedded/model_viewer.min.js", "BSD-3-Clause")]
    files += [(p, str(p.relative_to(root)), None) for p in sorted((root / "assets").rglob("*.glb"))]
    for path, name, license_id in files:
        sha = digest(path)
        file_ref = "sha256:" + sha
        component = {"type": "file", "bom-ref": file_ref, "name": name,
                     "hashes": [{"alg": "SHA-256", "content": sha}],
                     "properties": [{"name": "elyrii:size-bytes", "value": str(path.stat().st_size)}]}
        if license_id:
            component["licenses"] = [{"license": {"id": license_id}}]
            component["properties"].append({"name": "elyrii:upstream-version", "value": "undetermined; identified by embedded file hash"})
        components.append(component)
        parent = refs["flutter_3d_controller"] if license_id else application["bom-ref"]
        next(edge for edge in edges if edge["ref"] == parent)["dependsOn"].append(file_ref)
        edges.append({"ref": file_ref, "dependsOn": []})
    bom = {"bomFormat": "CycloneDX", "specVersion": "1.6", "version": 1,
           "metadata": {"timestamp": datetime.now(timezone.utc).isoformat(), "component": application,
                        "properties": [{"name": "elyrii:pubspec-lock-sha256", "value": digest(lock)},
                                       {"name": "elyrii:flutter-version", "value": json.loads((root / ".fvmrc").read_text())["flutter"]},
                                       {"name": "elyrii:scope", "value": "Dart dependency graph, embedded model-viewer JavaScript and GLB assets. Excludes native Gradle/CocoaPods closure."}]},
           "components": components, "dependencies": edges}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(bom, indent=2) + "\n")
    print(f"Inventoried {len(components)} components; native dependency inventory remains separate.")


if __name__ == "__main__":
    main()
