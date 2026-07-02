#!/bin/bash
# Fixture docset pipeline — a tiny docset built from sample.rb.
# Used by CI and local development to exercise the full engine quickly.
#
# Usage: pipelines/fixture/build.sh <output-dir>
set -euo pipefail

OUTPUT_DIR="${1:?usage: build.sh <output-dir>}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

cd "$ROOT/pipelines/fixture"
ruby "$ROOT/pipelines/lib/rdoc_docset.rb" \
  --type fixture \
  --name Fixture \
  --version 1.0.0 \
  --id fixture-1.0.0 \
  --out "$OUTPUT_DIR/fixture-1.0.0" \
  -- sample.rb

echo "[fixture] done: $OUTPUT_DIR/fixture-1.0.0"
