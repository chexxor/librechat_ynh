#!/usr/bin/env python3
"""TOML syntax + schema validation for the LibreChat YunoHost package (GHCI-01).

Run from the repo root:
    python scripts/lint_toml.py

Checks:
  1. manifest.toml parses (stdlib tomllib, syntax only).
  2. tests.toml parses (stdlib tomllib).
  3. tests.toml validates against the YunoHost tests.v1 schema (fetched live).
     tests.toml declares this schema in its `#:schema` comment; jsonschema
     applies it strictly (additionalProperties=false).

Exits non-zero on any failure so the GitHub Actions job gate works.
"""

import json
import sys
import tomllib
import urllib.request
from pathlib import Path

TESTS_SCHEMA_URL = (
    "https://raw.githubusercontent.com/YunoHost/apps/main/schemas/tests.v1.schema.json"
)

ROOT = Path(__file__).resolve().parent.parent


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    # 1. manifest.toml syntax
    manifest = ROOT / "manifest.toml"
    try:
        tomllib.loads(manifest.read_text(encoding="utf-8"))
    except Exception as exc:  # tomllib.TOMLDecodeError
        fail(f"{manifest.name} does not parse: {exc}")
    print(f"OK: {manifest.name} parses")

    # 2. tests.toml syntax
    tests = ROOT / "tests.toml"
    try:
        tests_data = tomllib.loads(tests.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"{tests.name} does not parse: {exc}")
    print(f"OK: {tests.name} parses")

    # 3. tests.toml schema validation
    try:
        import jsonschema
    except ImportError:
        fail("jsonschema is required (pip install jsonschema)")

    try:
        with urllib.request.urlopen(TESTS_SCHEMA_URL, timeout=30) as resp:
            schema = json.loads(resp.read().decode("utf-8"))
    except Exception as exc:
        fail(f"could not fetch tests schema from {TESTS_SCHEMA_URL}: {exc}")

    try:
        jsonschema.validate(tests_data, schema)
    except jsonschema.ValidationError as exc:
        fail(f"{tests.name} fails schema validation: {exc.message} "
             f"(at {'/'.join(str(p) for p in exc.absolute_path) or '<root>'})")
    print(f"OK: {tests.name} satisfies the tests.v1 schema")

    print("All TOML/schema checks passed.")


if __name__ == "__main__":
    main()
