#!/bin/sh
# Checks that scripts/check_bundled_data.sh accepts a faithful copy of the data and rejects a damaged one.
set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
check="$root/scripts/check_bundled_data.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fresh_app() {
    rm -rf "$work/App.app"
    mkdir "$work/App.app"
    cp -R "$root/data/catalog" "$work/App.app/catalog"
    cp "$root/data/sources.json" "$work/App.app/sources.json"
}

expect_fail() {
    if "$check" "$work/App.app" >/dev/null 2>&1; then
        echo "FAIL: $1" >&2
        exit 1
    fi
}

fresh_app
"$check" "$work/App.app" >/dev/null || { echo "FAIL: a faithful copy was rejected" >&2; exit 1; }

fresh_app; rm "$work/App.app/catalog/manifest.json"
expect_fail "a bundle without the manifest was accepted"

fresh_app; rm "$work/App.app/catalog/filler-words.json"
expect_fail "a bundle without the filler words was accepted"

fresh_app; echo " " >> "$work/App.app/catalog/foods/salt.json"
expect_fail "a bundle with an altered food was accepted"

fresh_app; rm "$work/App.app/sources.json"
expect_fail "a bundle without sources.json was accepted"

echo "ok"
