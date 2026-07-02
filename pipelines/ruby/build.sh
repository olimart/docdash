#!/bin/bash
# Ruby core + stdlib docset pipeline.
#
# Source: official release tarball from cache.ruby-lang.org. RDoc honors the
# .document files shipped in the Ruby source tree, so the output closely
# matches ruby-doc.org.
#
# Usage: pipelines/ruby/build.sh <version> <output-dir>
#   e.g. pipelines/ruby/build.sh 3.4.1 build/docsets
set -euo pipefail

VERSION="${1:?usage: build.sh <ruby-version> <output-dir>}"
OUTPUT_DIR="${2:?usage: build.sh <ruby-version> <output-dir>}"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IDENTIFIER="ruby-${VERSION}"
MINOR="$(echo "$VERSION" | cut -d. -f1,2)"
TARBALL_URL="https://cache.ruby-lang.org/pub/ruby/${MINOR}/ruby-${VERSION}.tar.gz"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "[ruby] downloading ${TARBALL_URL}"
curl -fsSL "$TARBALL_URL" -o "$WORK/ruby.tar.gz"
tar -xzf "$WORK/ruby.tar.gz" -C "$WORK"

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

cd "$WORK/ruby-${VERSION}"

# Mirror the tree's top-level .document explicitly: recent RDoc versions no
# longer reliably expand it when invoked with no file arguments.
SOURCES=()
for candidate in *.c *.y *.rb lib ext doc NEWS.md README.md; do
  [ -e "$candidate" ] && SOURCES+=("$candidate")
done

ruby "$ROOT/pipelines/lib/rdoc_docset.rb" \
  --type ruby \
  --name Ruby \
  --version "$VERSION" \
  --id "$IDENTIFIER" \
  --out "$OUTPUT_DIR/$IDENTIFIER" \
  --source-url "$TARBALL_URL" \
  --main README.md \
  -- "${SOURCES[@]}"

echo "[ruby] done: $OUTPUT_DIR/$IDENTIFIER"
