#!/usr/bin/env bash
# Scripted checks for the build-signup eval. Prints one "check: value" line per assertion it can
# decide mechanically. The remaining assertions in evals.json are judged by reading the result.
#   bash evals/grade-build.sh <run-dir>
set -uo pipefail
dir="${1:?usage: grade-build.sh <run-dir>}"
audit="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/skills/fixmyvibe/bin/fixmyvibe-audit.sh"
cd "$dir" || exit 2

code_files() { git ls-files --cached --others --exclude-standard | grep -E '\.(js|mjs|cjs)$' | grep -v '^test/' | grep -v '^lib/validate\.js$'; }
added() { git diff HEAD --unified=0 -- "$@" | grep -E '^\+[^+]'; for f in $(git ls-files --others --exclude-standard -- "$@"); do sed 's/^/+/' "$f"; done; }

out="$(npm test 2>&1)"; rc=$?
echo "tests_exit: $rc"
echo "tests_pass: $(printf '%s\n' "$out" | sed -n 's/^.* pass \([0-9]*\)$/\1/p' | tail -1)"
echo "tests_fail: $(printf '%s\n' "$out" | sed -n 's/^.* fail \([0-9]*\)$/\1/p' | tail -1)"
echo "test_files_mentioning_subscribe: $(grep -lis 'subscribe' test/* 2>/dev/null | wc -l | tr -d ' ')"
echo "failure_case_assertions: $(grep -hEis '(400|409|413|415|429)' test/* 2>/dev/null | wc -l | tr -d ' ')"
echo "uses_isEmail: $(code_files | xargs grep -l 'isEmail' 2>/dev/null | wc -l | tr -d ' ')"
echo "new_email_regex: $(added '*.js' | grep -cE '@.*\\\.|\[\^\\s@\]' )"
echo "uses_readJsonBody: $(code_files | xargs grep -l 'readJsonBody' 2>/dev/null | wc -l | tr -d ' ')"
echo "handles_duplicates: $(git ls-files --cached --others --exclude-standard | grep -E '\.js$' | xargs grep -liE 'UNIQUE|ON CONFLICT|INSERT OR IGNORE' 2>/dev/null | wc -l | tr -d ' ')"
echo "sql_interpolation_lines: $(code_files | xargs grep -nE '(SELECT|INSERT|UPDATE|DELETE)[^;]*\$\{' 2>/dev/null | wc -l | tr -d ' ')"
echo "label_elements: $(grep -hoi '<label' public/*.html 2>/dev/null | wc -l | tr -d ' ')"
echo "new_color_literals_outside_tokens: $(added 'public/*' | grep -vE '^\+[[:space:]]*--' | grep -cE '#[0-9a-fA-F]{3,8}([^0-9a-zA-Z]|$)|oklch\(|rgba?\(|hsla?\(')"
echo "token_uses_added: $(added 'public/*' | grep -o 'var(--' | wc -l | tr -d ' ')"

a="$(bash "$audit" --changed 2>&1)"; echo "audit_exit: $?"
echo "audit_summary: $(printf '%s\n' "$a" | tail -1)"
printf '%s\n' "$a" | grep -E '^(BLOCKER|WARNING)' | awk '{ print "audit_finding: " $1, $2, $3 }'

# Is the admin surface readable without a credential? Start the app with no admin secret set.
port=$((20000 + RANDOM % 20000))
PORT=$port node --no-warnings server.js > .grade-server.log 2>&1 &
pid=$!; sleep 2
if kill -0 $pid 2>/dev/null; then
  for p in /admin /admin.html /api/subscribers /api/admin/subscribers /admin/subscribers; do
    echo "no_credential GET $p: $(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:$port$p")"
  done
  echo "POST /api/subscribe valid: $(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -H 'Content-Type: application/json' -d '{"email":"grader@example.org"}' "http://127.0.0.1:$port/api/subscribe")"
  echo "POST /api/subscribe duplicate: $(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -H 'Content-Type: application/json' -d '{"email":"grader@example.org"}' "http://127.0.0.1:$port/api/subscribe")"
  echo "POST /api/subscribe invalid: $(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -H 'Content-Type: application/json' -d '{"email":"nope"}' "http://127.0.0.1:$port/api/subscribe")"
  kill $pid 2>/dev/null
else
  echo "server_start: failed without configuration ($(head -c 200 .grade-server.log | tr '\n' ' '))"
fi
rm -f .grade-server.log
