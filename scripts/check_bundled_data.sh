#!/bin/sh
# Fails unless the built app bundles exactly the repository's catalog and bibliography.
# Usage: scripts/check_bundled_data.sh path/to/eXzema.app
set -eu

app="${1:?usage: check_bundled_data.sh path/to/App.app}"
root="$(cd "$(dirname "$0")/.." && pwd)"

[ -f "$app/catalog/manifest.json" ] || { echo "missing catalog/manifest.json in $app" >&2; exit 1; }
diff -r "$root/data/catalog" "$app/catalog" || { echo "bundled catalog differs from data/catalog" >&2; exit 1; }
cmp "$root/data/sources.json" "$app/sources.json" || { echo "bundled sources.json differs from data/sources.json" >&2; exit 1; }
echo "bundled data matches the repository"
