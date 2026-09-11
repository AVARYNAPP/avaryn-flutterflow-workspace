#!/usr/bin/env python3
"""Offline manifest/staging only. No credentials, CLI, database or network access."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
PROJECT_REF = "rvymglpkttlfwhqpmupp"
ORG = "ufvwcbrvwbqmejwraend"
EDGE_FILES = (
    "supabase/functions/delete-account/index.ts",
    "supabase/functions/delete-account/handler.ts",
    "supabase/functions/media-assets/index.ts",
)
STAGE_CONFIG = '''project_id = "avaryn-c010-pilot"
[db]
major_version = 17
[db.migrations]
enabled = true
[db.seed]
enabled = false
sql_paths = []
[functions.delete-account]
verify_jwt = false
[functions.media-assets]
verify_jwt = false
'''


def digest(data):
    return hashlib.sha256(data).hexdigest()


def source_file(root, relative):
    path = root / relative
    if any(p.is_symlink() for p in [path, *path.parents]):
        raise ValueError("Source symlink refused.")
    path.resolve().relative_to(root.resolve())
    if not path.is_file():
        raise ValueError("Source file missing.")
    return path


def build_manifest(root=ROOT):
    migrations = []
    for path in sorted((root / "supabase/migrations").glob("*.sql")):
        relative = path.relative_to(root).as_posix()
        match = re.fullmatch(r"(\d{12})_([a-z0-9_]+)\.sql", path.name)
        if not match:
            raise ValueError("Unexpected migration filename.")
        data = source_file(root, relative).read_bytes()
        controls = [s.lower() for s in re.findall(r"(?mi)^(begin|commit);[ \t]*$", data.decode())]
        if controls not in ([], ["begin", "commit"]):
            raise ValueError("Unexpected migration transaction shape.")
        migrations.append({"version": match[1], "name": match[2], "path": relative,
                           "bytes": len(data), "sha256": digest(data),
                           "transaction_wrapper": "source" if controls else "executor_required"})
    if (len(migrations) != 47 or len({m["version"] for m in migrations}) != 47
            or migrations[-1]["version"] != "202609110003"):
        raise ValueError("Expected exactly the reviewed47 migrations ending in Vitality003.")
    edges = [{"path": p, "sha256": digest(source_file(root, p).read_bytes())} for p in EDGE_FILES]
    value = {
        "schema_version": 1, "project_ref": PROJECT_REF, "organization_id": ORG,
        "project_name": "AVARYN C010 Pilot",
        "api_url": "https://" + PROJECT_REF + ".supabase.co",
        "status": "OFFLINE_PREPARED_REMOTE_NOT_VERIFIED", "migrations": migrations,
        "edge_files": edges,
        "deploy_functions": ["delete-account", "media-assets"],
        "excluded": ["fixtures", "tests", "seed.sql", "local Auth/Storage data", "legacy stable-invitations Edge"],
        "managed_requirements": {"postgres_major": 17, "source_fixture_import": False,
                                  "private_schema_exposed": False, "verified_jwt_inside_each_edge": True},
        "staging_config_sha256": digest(STAGE_CONFIG.encode()),
    }
    value["source_manifest_sha256"] = digest(json.dumps(value, sort_keys=True, separators=(",", ":")).encode())
    return value


def verify_manifest(manifest, root=ROOT):
    if manifest != build_manifest(root):
        raise ValueError("Target or reviewed source changed; stop, review and regenerate deliberately.")


def stage_release(destination, manifest, root=ROOT):
    verify_manifest(manifest, root)
    for path in [destination, *destination.parents]:
        if path.is_symlink():
            raise ValueError("Staging symlink refused.")
    if destination.exists():
        raise ValueError("Staging destination must be new; never overwrite a previous release.")
    destination.mkdir(parents=True, mode=0o700)
    for item in manifest["migrations"] + manifest["edge_files"]:
        output = destination / item["path"]
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source_file(root, item["path"]), output)
        if digest(output.read_bytes()) != item["sha256"]:
            raise ValueError("Copied source checksum mismatch.")
    (destination / "supabase/config.toml").write_text(STAGE_CONFIG)
    (destination / "pilot-release-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write-manifest", action="store_true")
    parser.add_argument("--stage", type=Path)
    args = parser.parse_args()
    path = HERE / "pilot-release-manifest.json"
    if args.write_manifest:
        path.write_text(json.dumps(build_manifest(), indent=2) + "\n")
    manifest = json.loads(path.read_text())
    verify_manifest(manifest)
    if args.stage:
        stage_release(args.stage, manifest)
    print(json.dumps({"status": "OFFLINE_PASS", "migrations": 47,
                      "source_manifest_sha256": manifest["source_manifest_sha256"],
                      "remote_executed": False}))


if __name__ == "__main__":
    main()
