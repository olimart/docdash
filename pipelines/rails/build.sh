#!/bin/bash
# Ruby on Rails API docset pipeline.
#
# Source: the rails/rails repository at the release tag. Documents each
# framework gem's lib directory, mirroring api.rubyonrails.org coverage.
#
# Usage: pipelines/rails/build.sh <version> <output-dir>
#   e.g. pipelines/rails/build.sh 8.0.1 build/docsets
set -euo pipefail

VERSION="${1:?usage: build.sh <rails-version> <output-dir>}"
OUTPUT_DIR="${2:?usage: build.sh <rails-version> <output-dir>}"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IDENTIFIER="rails-${VERSION}"
REPO_URL="https://github.com/rails/rails"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "[rails] cloning ${REPO_URL} at v${VERSION}"
git clone --quiet --depth 1 --branch "v${VERSION}" "$REPO_URL" "$WORK/rails"

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

cd "$WORK/rails"

# The framework gems documented on api.rubyonrails.org.
FRAMEWORKS=(
  activesupport activemodel activerecord activejob activestorage
  actionpack actionview actionmailer actionmailbox actiontext
  actioncable railties
)
SOURCES=()
for framework in "${FRAMEWORKS[@]}"; do
  [ -d "$framework/lib" ] && SOURCES+=("$framework/lib")
done
[ -f README.md ] && SOURCES+=(README.md)

ruby "$ROOT/pipelines/lib/rdoc_docset.rb" \
  --type rails \
  --name "Ruby on Rails" \
  --version "$VERSION" \
  --id "$IDENTIFIER" \
  --out "$OUTPUT_DIR/$IDENTIFIER" \
  --source-url "${REPO_URL}/tree/v${VERSION}" \
  --main README.md \
  --title "Ruby on Rails ${VERSION}" \
  -- "${SOURCES[@]}"

echo "[rails] done: $OUTPUT_DIR/$IDENTIFIER"
