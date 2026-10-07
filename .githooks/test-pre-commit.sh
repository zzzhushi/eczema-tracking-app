#!/bin/sh
# Checks the pre-commit hook against throwaway repositories. Run: .githooks/test-pre-commit.sh
set -u

hook="$(cd "$(dirname "$0")" && pwd)/pre-commit"
failures=0

# A made-up team ID, kept out of any line that also names the setting so the hook does not block this file.
fake=ABCDE12345

# expect_blocked <name> <path> <content>  /  expect_allowed <name> <path> <content>
run_case() {
  verdict=$1 name=$2 path=$3 content=$4
  repo=$(mktemp -d)
  (
    cd "$repo" || exit 99
    git init -q
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "$content" > "$path"
    git add -f "$path"
    sh "$hook" >/dev/null 2>&1
  )
  status=$?
  rm -rf "$repo"
  if [ "$verdict" = blocked ] && [ "$status" -ne 0 ]; then return; fi
  if [ "$verdict" = allowed ] && [ "$status" -eq 0 ]; then return; fi
  echo "FAIL: $name (expected $verdict, hook exited $status)"
  failures=$((failures + 1))
}

run_case blocked "a staged Local.xcconfig"                 Local.xcconfig "DEVELOPMENT_TEAM = $fake"
run_case blocked "a team ID in project.yml"                project.yml "    DEVELOPMENT_TEAM: $fake"
run_case blocked "a quoted team ID in project.yml"         project.yml "    DEVELOPMENT_TEAM: \"$fake\""
run_case blocked "a team ID in a generated project file"   App.xcodeproj/project.pbxproj "DEVELOPMENT_TEAM = $fake;"
run_case allowed "an empty team setting"                   project.yml '    DEVELOPMENT_TEAM: ""'
run_case allowed "a team setting read from a variable"     project.yml '    DEVELOPMENT_TEAM: $(DEVELOPMENT_TEAM)'
run_case allowed "an unrelated change"                     README.md "hello"
run_case blocked "a staged photo"                          notes/face.heic "x"
run_case blocked "a staged fixtures file"                  fixtures/manifest.json "{}"

if [ "$failures" -eq 0 ]; then echo "pre-commit hook: all cases pass"; else exit 1; fi
