#!/usr/bin/env bash
# Regression tests for the shell audit. No external test framework required.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIT="$ROOT/skills/fixmyvibe/bin/fixmyvibe-audit.sh"
TEST_ROOT="$ROOT/tmp/fixmyvibe-audit-shell-tests"
passes=0

cleanup() {
  case "$TEST_ROOT" in "$ROOT"/tmp/*) rm -rf "$TEST_ROOT" ;; *) echo 'Unsafe cleanup path.' >&2; exit 2 ;; esac
}
trap cleanup EXIT
cleanup
mkdir -p "$TEST_ROOT"

run_audit() {
  local cwd="$1"; shift
  set +e
  output="$(cd "$cwd" && bash "$AUDIT" "$@" 2>&1)"
  status=$?
  set -e
}

assert_status() {
  local expected="$1" name="$2"
  if [[ "$status" -ne "$expected" ]]; then printf 'FAIL %s: expected %s, got %s\n%s\n' "$name" "$expected" "$status" "$output" >&2; exit 1; fi
  printf 'PASS %s\n' "$name"; passes=$((passes+1))
}

assert_output() {
  local needle="$1" name="$2"
  if [[ "$output" != *"$needle"* ]]; then printf 'FAIL %s: missing %s\n%s\n' "$name" "$needle" "$output" >&2; exit 1; fi
  printf 'PASS %s\n' "$name"; passes=$((passes+1))
}

printf 'api_key = "replace_me"\nhttps://example.test/risk-management-framework-resources\n' > "$TEST_ROOT/clean sample.txt"
run_audit "$ROOT" "$TEST_ROOT/clean sample.txt"
assert_status 0 'placeholder exits clean'

printf 'API_KEY = "real-looking-production-value-123"\n' > "$TEST_ROOT/fixture.txt" # fixmyvibe: allow SEC003 scanner-fixture
run_audit "$ROOT" "$TEST_ROOT/fixture.txt"
assert_status 1 'hardcoded secret blocks'
assert_output 'SEC003' 'hardcoded secret has stable rule ID'

printf '.button { outline: none; }\n' > "$TEST_ROOT/styles.css"
run_audit "$ROOT" "$TEST_ROOT/styles.css"
assert_status 0 'warning is reviewable by default'
run_audit "$ROOT" --strict-warnings "$TEST_ROOT/styles.css"
assert_status 1 'strict warnings block'

printf 'node.innerHTML = trustedHtml; // fixmyvibe: allow SEC201 trusted-sanitized-renderer\n' > "$TEST_ROOT/reviewed.tsx"
run_audit "$ROOT" "$TEST_ROOT/reviewed.tsx"
assert_status 0 'reviewed suppression exits clean'
assert_output 'ALLOW' 'reviewed suppression stays visible'

run_audit "$ROOT" "$TEST_ROOT/missing.txt"
assert_status 2 'missing target fails closed'

git_root="$TEST_ROOT/staged repo"
mkdir -p "$git_root"
git -C "$git_root" init --quiet
git -C "$git_root" config user.email 'fixmyvibe-tests@example.invalid'
git -C "$git_root" config user.name 'FixMyVibe Tests'
printf 'password = "old-real-looking-value"\n' > "$git_root/app.txt" # fixmyvibe: allow SEC003 scanner-fixture
git -C "$git_root" add app.txt
git -C "$git_root" commit --quiet -m baseline
printf 'safe = true\n' >> "$git_root/app.txt"
git -C "$git_root" add app.txt
run_audit "$git_root" --staged
assert_status 0 'staged mode ignores unchanged legacy lines'
assert_output 'added lines' 'staged mode declares scope'

printf 'token = "new-real-looking-secret-value"\n' >> "$git_root/app.txt" # fixmyvibe: allow SEC003 scanner-fixture
git -C "$git_root" add app.txt
run_audit "$git_root" --staged
assert_status 1 'staged mode catches newly added secret'
assert_output 'SEC003' 'staged finding includes rule ID'

printf 'All shell audit tests passed (%d assertions).\n' "$passes"
