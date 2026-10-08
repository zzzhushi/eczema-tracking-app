#!/bin/sh
# Copies the app's store, log files, and diagnostic reports from a connected iPhone to a new private folder on
# this Mac, for debugging. The app must be installed from Xcode so its data container is readable.
#
# Usage: scripts/pull_from_phone.sh [output-dir]
#   output-dir   must not exist yet; defaults to ~/exzema-pulls/<UTC timestamp>. It must be outside every git
#                checkout, because the store holds the user's real entries.
#
# The three copies are separate operations, so they describe one moment only if nothing is writing: force-quit
# the app on the phone first. The script refuses to run while the app is running.
#
# Environment:
#   EXZEMA_DEVICE         device name or identifier; needed only when more than one iPhone is connected
#   EXZEMA_ALLOW_RUNNING  set to copy while the app is running, accepting that the copy may be inconsistent
#   EXZEMA_DEVICECTL      the devicectl command to run, for tests
set -eu
umask 077

bundle="com.zzzhushi.exzema"
support="Library/Application Support/eXzema"
devicectl="${EXZEMA_DEVICECTL:-xcrun devicectl}"

fail() { echo "error: $*" >&2; exit 1; }

out="${1:-$HOME/exzema-pulls/$(date -u +%Y%m%dT%H%M%SZ)}"
out="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$out")"
[ ! -e "$out" ] || fail "$out already exists; each pull needs a fresh folder, so a retry cannot mix old and new copies"

# Refuse a folder inside any git checkout, including other worktrees and unrelated repositories. Nothing is
# created until this passes, so a refused path leaves nothing behind.
ancestor="$(dirname "$out")"
while [ ! -d "$ancestor" ]; do ancestor="$(dirname "$ancestor")"; done
if [ "$(git -C "$ancestor" rev-parse --is-inside-work-tree 2>/dev/null)" = true ] \
    || [ "$(git -C "$ancestor" rev-parse --is-inside-git-dir 2>/dev/null)" = true ]; then
    fail "$out is inside a git checkout; pick a folder outside every checkout"
fi

tmp="$(mktemp)"
succeeded=""
created=""
cleanup() {
    rm -f "$tmp"
    [ -z "$created" ] || [ -n "$succeeded" ] || rm -rf "$out"
}
trap cleanup EXIT

device="${EXZEMA_DEVICE:-}"
if [ -z "$device" ]; then
    $devicectl list devices --json-output "$tmp" >/dev/null 2>&1 || fail "could not list devices; is Xcode installed?"
    found="$(python3 - "$tmp" <<'PY'
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

$devicectl device info processes --device "$device" --search "eXzema.app" --json-output "$tmp" >/dev/null 2>&1 \
    || fail "could not check whether the app is running; unlock the phone and try again"
running="$(python3 - "$tmp" <<'PY'
import json, sys
processes = json.load(open(sys.argv[1]))["result"]["runningProcesses"]
print(sum(1 for p in processes if "/eXzema.app/" in p.get("executable", "")))
PY
)"
if [ "$running" -ne 0 ]; then
    [ -n "${EXZEMA_ALLOW_RUNNING:-}" ] || fail "the app is running on the phone; force-quit it (swipe it away in the app switcher) so nothing is written during the copy, or set EXZEMA_ALLOW_RUNNING=1 to copy anyway"
    echo "warning: the app is running, so the copies may not describe one moment"
fi

mkdir -p "$(dirname "$out")"
mkdir "$out"
created=1

copy() {
    $devicectl device copy from --device "$device" --domain-type appDataContainer --domain-identifier "$bundle" \
        --source "$support/$1" --destination "$out/$1" >/dev/null 2>"$tmp"
}

copy Store || { cat "$tmp" >&2; fail "could not copy the store; unlock the phone and check the app is installed from Xcode"; }
if ! copy Diagnostics; then
    echo "note: no diagnostic reports on the phone"
fi
if ! copy Logs; then
    echo "note: no app log files on the phone (the build predates them, or nothing has been logged)"
fi
chmod -R go-rwx "$out"

store="$out/Store/store.sqlite"
[ -f "$store" ] || fail "the copy has no Store/store.sqlite"
succeeded=1
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
    echo "app logs:            cat '$out'/Logs/previous.jsonl '$out'/Logs/current.jsonl"
fi
echo "system logs (root):  sudo /usr/bin/log collect --device --last 1d --output '$out/logs.logarchive'"
echo "read them:           /usr/bin/log show '$out/logs.logarchive' --predicate 'subsystem == \"$bundle\"'"
echo "The store holds real entries and ratings; logs mark them private. Delete the folder when finished."
