#!/bin/sh
# Copies the app's store and diagnostic reports from a connected iPhone to a private folder on this Mac,
# for debugging. The app must be installed from Xcode so its data container is readable.
#
# Usage: scripts/pull_from_phone.sh [output-dir]
#   output-dir   defaults to ~/exzema-pulls/<UTC timestamp>; it must be outside every checkout of this
#                repository, because the store holds the user's real entries.
# Environment:
#   EXZEMA_DEVICE     device name or identifier; needed only when more than one iPhone is connected
#   EXZEMA_DEVICECTL  the devicectl command to run, for tests
set -eu
umask 077

bundle="com.zzzhushi.exzema"
support="Library/Application Support/eXzema"
devicectl="${EXZEMA_DEVICECTL:-xcrun devicectl}"
root="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "error: $*" >&2; exit 1; }

out="${1:-$HOME/exzema-pulls/$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"

checkouts="$(git -C "$root" rev-parse --show-toplevel) $(dirname "$(git -C "$root" rev-parse --path-format=absolute --git-common-dir)")"
for checkout in $checkouts; do
    case "$out/" in
        "$checkout"/*) fail "$out is inside the repository checkout $checkout; pick a folder outside it" ;;
    esac
done

device="${EXZEMA_DEVICE:-}"
if [ -z "$device" ]; then
    list="$(mktemp)"
    trap 'rm -f "$list"' EXIT
    $devicectl list devices --json-output "$list" >/dev/null 2>&1 || fail "could not list devices; is Xcode installed?"
    found="$(python3 - "$list" <<'PY'
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
for d in devices:
    hardware = d.get("hardwareProperties", {})
    if (hardware.get("reality") == "physical" and hardware.get("platform") == "iOS"
            and d.get("connectionProperties", {}).get("tunnelState") == "connected"):
        print(d["identifier"] + "\t" + d.get("deviceProperties", {}).get("name", "unnamed"))
PY
)"
    count="$(printf '%s\n' "$found" | grep -c . || true)"
    [ "$count" -ge 1 ] || fail "no connected iPhone found; connect and unlock it"
    [ "$count" -eq 1 ] || fail "more than one iPhone is connected; set EXZEMA_DEVICE to one of: $(printf '%s' "$found" | cut -f2 | tr '\n' ',' | sed 's/,$//')"
    device="$(printf '%s' "$found" | cut -f1)"
    echo "device: $(printf '%s' "$found" | cut -f2)"
fi

copy() {
    $devicectl device copy from --device "$device" --domain-type appDataContainer --domain-identifier "$bundle" \
        --source "$support/$1" --destination "$out/$1" >/dev/null 2>"$out/.copy-error"
}

copy Store || { cat "$out/.copy-error" >&2; fail "could not copy the store; unlock the phone and check the app is installed from Xcode"; }
if ! copy Diagnostics; then
    echo "note: no diagnostic reports on the phone"
fi
if ! copy Logs; then
    echo "note: no app log files on the phone (the build predates them, or nothing has been logged)"
fi
rm -f "$out/.copy-error"
chmod -R go-rwx "$out"

store="$out/Store/store.sqlite"
[ -f "$store" ] || fail "the copy has no Store/store.sqlite"
echo "copied to: $out"
if command -v sqlite3 >/dev/null 2>&1; then
    echo "integrity: $(sqlite3 -readonly "$store" 'PRAGMA integrity_check;')"
    sqlite3 -readonly "$store" "select 'schema version: ' || user_version from pragma_user_version;
        select 'days: ' || count(*) from day; select 'food lines: ' || count(*) from food_line;
        select 'food items: ' || count(*) from food_item;"
fi
if [ -d "$out/Logs" ]; then
    echo "app log lines: $(cat "$out"/Logs/*.jsonl 2>/dev/null | wc -l | tr -d ' ')"
fi
echo
echo "look at the data:    sqlite3 -readonly '$store' '.tables'"
if [ -d "$out/Logs" ]; then
    echo "app logs:           cat '$out'/Logs/previous.jsonl '$out'/Logs/current.jsonl"
fi
echo "system logs (root): sudo /usr/bin/log collect --device --last 1d --output '$out/logs.logarchive'"
echo "read them:           /usr/bin/log show '$out/logs.logarchive' --predicate 'subsystem == \"$bundle\"'"
echo "The store holds real entries and ratings; logs mark them private. Delete the folder when finished."
