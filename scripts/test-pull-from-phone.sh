#!/bin/sh
# Checks scripts/pull_from_phone.sh against a fake devicectl, so no phone is needed.
set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/scripts/pull_from_phone.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cat > "$work/fake-devicectl" <<'FAKE'
#!/bin/sh
# Stands in for `xcrun devicectl`. FAKE_DEVICES is none, one, or two. FAKE_RUNNING makes the app appear to be
# running. FAKE_NO_STORE, FAKE_NO_DIAGNOSTICS, and FAKE_NO_LOGS make the matching copy fail.
case "$1 $2" in
"list devices")
    while [ $# -gt 0 ]; do [ "$1" = "--json-output" ] && file="$2"; shift; done
    phone() { printf '{"identifier":"%s","hardwareProperties":{"reality":"physical","platform":"iOS"},"connectionProperties":{"tunnelState":"connected"},"deviceProperties":{"name":"%s"}}' "$1" "$2"; }
    case "$FAKE_DEVICES" in
        none) devices='{"identifier":"sim","hardwareProperties":{"reality":"simulated","platform":"iOS"},"connectionProperties":{"tunnelState":"connected"},"deviceProperties":{"name":"Simulator"}}' ;;
        one) devices="$(phone phone-a "Test Phone")" ;;
        two) devices="$(phone phone-a "Test Phone"),$(phone phone-b "Other Phone")" ;;
    esac
    printf '{"result":{"devices":[%s]}}' "$devices" > "$file"
    ;;
"device info")
    while [ $# -gt 0 ]; do [ "$1" = "--json-output" ] && file="$2"; shift; done
    if [ -n "${FAKE_RUNNING:-}" ]; then
        printf '{"result":{"runningProcesses":[{"executable":"file:///private/var/containers/Bundle/Application/X/eXzema.app/eXzema","processIdentifier":1}]}}' > "$file"
    else
        printf '{"result":{"runningProcesses":[]}}' > "$file"
    fi
    ;;
"device copy")
    while [ $# -gt 0 ]; do
        case "$1" in --source) source="$2" ;; --destination) dest="$2" ;; --device) device="$2" ;; esac
        shift
    done
    echo "$device" >> "$FAKE_LOG"
    case "$source" in
        */Store)
            [ -z "${FAKE_NO_STORE:-}" ] || { echo "ERROR: no node" >&2; exit 1; }
            mkdir -p "$dest"
            sqlite3 "$dest/store.sqlite" "pragma user_version=2; create table day(date text); create table food_line(id integer); create table food_item(id integer); insert into day values ('2026-10-08'); insert into food_line values (1); insert into food_item values (1),(2);"
            ;;
        */Logs)
            [ -z "${FAKE_NO_LOGS:-}" ] || { echo "ERROR: no node" >&2; exit 1; }
            mkdir -p "$dest"
            printf '{"event":"a"}\n{"event":"b"}\n' > "$dest/current.jsonl"; printf '{"event":"c"}\n' > "$dest/previous.jsonl"
            ;;
        */Diagnostics)
            [ -z "${FAKE_NO_DIAGNOSTICS:-}" ] || { echo "ERROR: no node" >&2; exit 1; }
            mkdir -p "$dest"; echo '{}' > "$dest/crash-1.json"
            ;;
    esac
    ;;
esac
FAKE
chmod +x "$work/fake-devicectl"
export EXZEMA_DEVICECTL="$work/fake-devicectl" FAKE_LOG="$work/copies.log"

fails=0
check() { if ! eval "$2"; then echo "FAIL: $1" >&2; fails=$((fails + 1)); fi; }
refused() { # description, expected message, command...
    desc="$1"; message="$2"; shift 2
    if "$@" >"$work/out.txt" 2>"$work/err.txt"; then
        echo "FAIL: $desc succeeded" >&2; fails=$((fails + 1))
    elif ! grep -q "$message" "$work/err.txt"; then
        echo "FAIL: $desc did not say '$message': $(cat "$work/err.txt")" >&2; fails=$((fails + 1))
    fi
}
export FAKE_DEVICES=one

"$script" "$work/pull1" >"$work/out.txt" 2>"$work/err.txt" || { echo "FAIL: the pull from one phone exited with an error: $(cat "$work/err.txt")" >&2; exit 1; }
check "a pull from one phone succeeds" "[ -f '$work/pull1/Store/store.sqlite' ]"
check "the diagnostic reports are copied" "[ -f '$work/pull1/Diagnostics/crash-1.json' ]"
check "the app log files are copied and counted" "[ -f '$work/pull1/Logs/current.jsonl' ] && grep -q 'app log lines: 3' '$work/out.txt'"
check "the summary has the counts" "grep -q 'food items: 2' '$work/out.txt' && grep -q 'schema version: 2' '$work/out.txt' && grep -q 'integrity: ok' '$work/out.txt'"
check "the log command is printed, not run" "grep -q 'sudo /usr/bin/log collect' '$work/out.txt' && [ ! -e '$work/pull1/logs.logarchive' ]"
check "the folder is private" "[ \"\$(stat -f %Lp '$work/pull1')\" = 700 ]"
check "the phone found was used" "grep -qx phone-a '$work/copies.log'"

# Inside a git checkout: this repository, a sibling worktree, an unrelated repository, and a repository's git directory.
git init -q "$work/other"
git -C "$work/other" -c user.name=Test -c user.email=test@example.com commit -q --allow-empty -m start
git -C "$work/other" worktree add -q "$work/sibling" -b sibling 2>/dev/null
mine="$root/pull-refused-$$"
[ ! -e "$mine" ] || { echo "FAIL: $mine already exists" >&2; exit 1; }
# The name is unique to this run and checked absent above, so removing it can only remove what this run made, which
# matters only if the guard is broken: a refusal that fails must not leave output inside the repository.
trap 'rm -rf "$work" "$mine"' EXIT
refused "an output folder inside this repository" "inside a git checkout" "$script" "$mine/deeper"
check "a refusal inside this repository creates nothing" "[ ! -e '$mine' ]"
refused "an output folder inside a sibling worktree" "inside a git checkout" "$script" "$work/sibling/pulls/one"
check "a refusal inside a sibling worktree creates nothing" "[ ! -e '$work/sibling/pulls' ]"
refused "an output folder inside an unrelated repository" "inside a git checkout" "$script" "$work/other/new/pull"
refused "an output folder inside a git directory" "inside a git checkout" "$script" "$work/other/.git/pull"
refused "a path that climbs back into a checkout" "inside a git checkout" "$script" "$work/pull1/../other/via-dotdot"

# A pull never reuses a folder.
mkdir "$work/existing" && echo keep > "$work/existing/old.txt"
refused "an output folder that already exists" "already exists" "$script" "$work/existing"
check "an existing folder is left alone" "[ \"\$(cat '$work/existing/old.txt')\" = keep ] && [ ! -e '$work/existing/Store' ]"
refused "a second pull into the same folder" "already exists" "$script" "$work/pull1"

# The app must not be running.
refused "a pull while the app is running" "force-quit" env FAKE_RUNNING=1 "$script" "$work/pull-running"
check "refusing a running app creates nothing" "[ ! -e '$work/pull-running' ]"
FAKE_RUNNING=1 EXZEMA_ALLOW_RUNNING=1 "$script" "$work/pull-allowed" >"$work/out.txt" 2>&1
check "a running app can be copied when asked" "[ -f '$work/pull-allowed/Store/store.sqlite' ] && grep -q 'warning: the app is running' '$work/out.txt'"

refused "a pull with no phone connected" "no connected iPhone" env FAKE_DEVICES=none "$script" "$work/pull2"
refused "a pull with two phones and no choice" "EXZEMA_DEVICE" env FAKE_DEVICES=two "$script" "$work/pull3"
FAKE_DEVICES=two EXZEMA_DEVICE=phone-b "$script" "$work/pull4" >/dev/null 2>&1
check "a chosen phone is used" "[ -f '$work/pull4/Store/store.sqlite' ] && grep -qx phone-b '$work/copies.log'"

refused "a pull with no store" "unlock the phone" env FAKE_NO_STORE=1 "$script" "$work/pull5"
check "a failed pull leaves no folder behind" "[ ! -e '$work/pull5' ]"

FAKE_NO_DIAGNOSTICS=1 "$script" "$work/pull6" >"$work/out.txt" 2>/dev/null
check "missing diagnostics is a note, not a failure" "[ -f '$work/pull6/Store/store.sqlite' ] && grep -q 'no diagnostic reports' '$work/out.txt'"
FAKE_NO_LOGS=1 "$script" "$work/pull7" >"$work/out.txt" 2>/dev/null
check "missing app logs is a note, not a failure" "[ -f '$work/pull7/Store/store.sqlite' ] && grep -q 'no app log files' '$work/out.txt'"

HOME="$work/home" "$script" >/dev/null 2>&1
check "the default folder is under the home directory" "[ -n \"\$(ls '$work/home/exzema-pulls' 2>/dev/null)\" ]"

if [ "$fails" -ne 0 ]; then echo "$fails check(s) failed" >&2; exit 1; fi
echo "ok"
