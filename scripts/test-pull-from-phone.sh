#!/bin/sh
# Checks scripts/pull_from_phone.sh against a fake devicectl, so no phone is needed.
set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/scripts/pull_from_phone.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cat > "$work/fake-devicectl" <<'FAKE'
#!/bin/sh
# Stands in for `xcrun devicectl`: FAKE_DEVICES is none, one, or two; FAKE_NO_STORE and FAKE_NO_DIAGNOSTICS
# make the matching copy fail.
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

FAKE_DEVICES=one "$script" "$work/pull1" >"$work/out.txt" 2>"$work/err.txt" || { echo "FAIL: the pull from one phone exited with an error: $(cat "$work/err.txt")" >&2; exit 1; }
check "a pull from one phone succeeds" "[ -f '$work/pull1/Store/store.sqlite' ]"
check "the diagnostic reports are copied" "[ -f '$work/pull1/Diagnostics/crash-1.json' ]"
check "the summary has the counts" "grep -q 'food items: 2' '$work/out.txt' && grep -q 'schema version: 2' '$work/out.txt' && grep -q 'integrity: ok' '$work/out.txt'"
check "the log command is printed, not run" "grep -q 'sudo /usr/bin/log collect' '$work/out.txt' && [ ! -e '$work/pull1/logs.logarchive' ]"
check "the folder is private" "[ \"\$(stat -f %Lp '$work/pull1')\" = 700 ]"
check "the phone found was used" "grep -qx phone-a '$work/copies.log'"

if FAKE_DEVICES=one "$script" "$root/pulled-by-mistake" >/dev/null 2>"$work/err.txt"; then
    echo "FAIL: an output folder inside the repository was accepted" >&2; fails=$((fails + 1))
fi
check "the repository refusal names the problem" "grep -q 'inside the repository' '$work/err.txt'"
rm -rf "$root/pulled-by-mistake"

if FAKE_DEVICES=none "$script" "$work/pull2" >/dev/null 2>"$work/err.txt"; then
    echo "FAIL: a pull with no phone connected succeeded" >&2; fails=$((fails + 1))
fi
check "no phone gives a clear message" "grep -q 'no connected iPhone' '$work/err.txt'"

if FAKE_DEVICES=two "$script" "$work/pull3" >/dev/null 2>"$work/err.txt"; then
    echo "FAIL: a pull with two phones and no choice succeeded" >&2; fails=$((fails + 1))
fi
check "two phones ask for a choice" "grep -q 'EXZEMA_DEVICE' '$work/err.txt'"
FAKE_DEVICES=two EXZEMA_DEVICE=phone-b "$script" "$work/pull4" >/dev/null 2>&1
check "a chosen phone is used" "[ -f '$work/pull4/Store/store.sqlite' ] && grep -qx phone-b '$work/copies.log'"

if FAKE_DEVICES=one FAKE_NO_STORE=1 "$script" "$work/pull5" >/dev/null 2>"$work/err.txt"; then
    echo "FAIL: a pull with no store succeeded" >&2; fails=$((fails + 1))
fi
check "a missing store says to unlock and check the install" "grep -q 'unlock the phone' '$work/err.txt'"

FAKE_DEVICES=one FAKE_NO_DIAGNOSTICS=1 "$script" "$work/pull6" >"$work/out.txt" 2>/dev/null
check "missing diagnostics is a note, not a failure" "[ -f '$work/pull6/Store/store.sqlite' ] && grep -q 'no diagnostic reports' '$work/out.txt'"

HOME="$work/home" FAKE_DEVICES=one "$script" >/dev/null 2>&1
check "the default folder is under the home directory" "[ -n \"\$(ls '$work/home/exzema-pulls' 2>/dev/null)\" ]"

if [ "$fails" -ne 0 ]; then echo "$fails check(s) failed" >&2; exit 1; fi
echo "ok"
