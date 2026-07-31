#!/usr/bin/env python3
"""Overlay only patched FFmpeg libraries onto the verified upstream 1.17 AAR."""

from __future__ import annotations

import argparse
import hashlib
import json
import zipfile
from pathlib import Path

UPSTREAM_SHA256 = "4570a5cb8fa2c87808e81ebf4b7f3747cb5aa52b1662dc8a1c03831c37b26b89"
ABIS = ("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
REPLACEMENTS = {
    f"jni/{abi}/{library}"
    for abi in ABIS
    for library in ("libavcodec.so", "libavformat.so")
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--upstream", type=Path, required=True)
    parser.add_argument("--patched", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args()

    upstream_bytes = args.upstream.read_bytes()
    if sha256(upstream_bytes) != UPSTREAM_SHA256:
        raise SystemExit("upstream 1.17 AAR checksum mismatch")

    with zipfile.ZipFile(args.upstream) as upstream, zipfile.ZipFile(args.patched) as patched:
        upstream_names = set(upstream.namelist())
        patched_names = set(patched.namelist())
        missing = REPLACEMENTS - upstream_names | REPLACEMENTS - patched_names
        if missing:
            raise SystemExit(f"missing replacement entries: {sorted(missing)}")

        replacements: dict[str, dict[str, str]] = {}
        manifest: dict[str, object] = {
            "upstream_aar_sha256": UPSTREAM_SHA256,
            "replacements": replacements,
        }
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(args.output, "w") as output:
            for info in upstream.infolist():
                original = upstream.read(info.filename)
                data = patched.read(info.filename) if info.filename in REPLACEMENTS else original
                if info.filename in REPLACEMENTS:
                    if data == original:
                        raise SystemExit(f"patched entry did not change: {info.filename}")
                    replacements[info.filename] = {
                        "upstream_sha256": sha256(original),
                        "patched_sha256": sha256(data),
                    }
                output.writestr(info, data)

    with zipfile.ZipFile(args.output) as output, zipfile.ZipFile(args.upstream) as upstream:
        if output.namelist() != upstream.namelist():
            raise SystemExit("packaged AAR entry list differs from upstream")
        for name in upstream.namelist():
            if name not in REPLACEMENTS and output.read(name) != upstream.read(name):
                raise SystemExit(f"unintended entry changed: {name}")

    manifest["output_aar_sha256"] = sha256(args.output.read_bytes())
    args.manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
