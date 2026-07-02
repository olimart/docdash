#!/bin/bash
# Packages a built docset directory into a release tarball:
#   pipelines/package.sh build/docsets/ruby-3.4.1 dist/
# produces dist/ruby-3.4.1.tar.gz (archive root = the docset folder).
set -euo pipefail

DOCSET_DIR="${1:?usage: package.sh <docset-dir> <dist-dir>}"
DIST_DIR="${2:?usage: package.sh <docset-dir> <dist-dir>}"

[ -f "$DOCSET_DIR/docset.json" ] || { echo "not a docset (missing docset.json): $DOCSET_DIR" >&2; exit 1; }

mkdir -p "$DIST_DIR"
DIST_DIR="$(cd "$DIST_DIR" && pwd)"
PARENT="$(cd "$(dirname "$DOCSET_DIR")" && pwd)"
NAME="$(basename "$DOCSET_DIR")"

tar -czf "$DIST_DIR/$NAME.tar.gz" -C "$PARENT" "$NAME"
echo "packaged: $DIST_DIR/$NAME.tar.gz ($(du -h "$DIST_DIR/$NAME.tar.gz" | cut -f1))"
