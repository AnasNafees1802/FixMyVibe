#!/usr/bin/env bash
# Tests for the shell audit: rule-pack lint, corpus accuracy, and behavior. No test framework needed.
#   bash tests/run.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIT="$ROOT/skills/fixmyvibe/bin/fixmyvibe-audit.sh"
RULES="$ROOT/skills/fixmyvibe/bin/rules.conf"
CORPUS="$ROOT/tests/corpus.txt"
T="$ROOT/tmp/audit-sh-tests"
passes=0; failures=0

case "$T" in "$ROOT"/tmp/*) rm -rf "$T" ;; *) echo 'Unsafe cleanup path.' >&2; exit 2 ;; esac
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/corpus"

ok()   { passes=$((passes+1)); printf 'PASS %s\n' "$1"; }
fail() { failures=$((failures+1)); printf 'FAIL %s\n%s\n' "$1" "${2:-}" >&2; }
run()  { local cwd="$1"; shift; output="$(cd "$cwd" && bash "$AUDIT" "$@" 2>&1)"; status=$?; }
expect_status() { [[ "$status" -eq "$1" ]] && ok "$2" || fail "$2 (expected exit $1, got $status)" "$output"; }
expect_output() { [[ "$output" == *"$1"* ]] && ok "$2" || fail "$2 (missing: $1)" "$output"; }
refute_output() { [[ "$output" != *"$1"* ]] && ok "$2" || fail "$2 (unexpected: $1)" "$output"; }

# ---- 1. rule pack lint: only escapes that grep -E and .NET read the same way
bad="$(grep -nE '^(match|unless) = ' "$RULES" | grep -E '\\[^].()[{}*+?|$^\\]')"
[[ -z "$bad" ]] && ok 'rule pack uses only portable escapes' || fail 'rule pack uses a non-portable escape' "$bad"
bad="$(grep -nE '^(match|unless) = (.*[^\\])?\(\?' "$RULES")"
[[ -z "$bad" ]] && ok 'rule pack has no lookaround or inline flags' || fail 'rule pack uses (?' "$bad"

# ---- 2. corpus coverage: every rule id has a hit and a miss, every corpus id is a real rule
gaps="$(awk -F'|' '
  FNR == NR { if ($0 ~ /^\[[A-Z]+[0-9]+\]/) { id = $0; gsub(/[][\r]/, "", id); rule[id] = 1 } next }
  /^(hit|miss) / { e = $1; id = $2; gsub(/ /, "", e); gsub(/ /, "", id); seen[e " " id] = 1
                   if (!(id in rule)) print "corpus row names unknown rule " id }
  END { for (id in rule) { if (!(("hit " id) in seen)) print "no hit row for " id
                           if (!(("miss " id) in seen)) print "no miss row for " id } }' "$RULES" "$CORPUS")"
[[ -z "$gaps" ]] && ok 'every rule id has a hit row and a miss row' || fail 'corpus coverage gap' "$gaps"

# ---- 3. corpus accuracy
: > "$T/hits"; : > "$T/misses"; row=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  case "$line" in hit*'|'*|miss*'|'*) ;; *) continue ;; esac
  row=$((row+1)); printf -v num '%03d' "$row"
  IFS='|' read -r exp id ext content <<< "$line"
  exp="${exp// /}"; id="${id// /}"; ext="${ext// /}"; content="${content# }"
  content="${content//'{+}'/}"; content="${content//\\n/$'\n'}"
  printf '%s\n' "$content" > "$T/corpus/$num.$ext"
  if [[ "$exp" == hit ]]; then printf '%s %s\n' "$id" "$num" >> "$T/hits"; else printf '%s %s\n' "$id" "$num" >> "$T/misses"; fi
done < "$CORPUS"
run "$ROOT" --format json "$T/corpus"
[[ "$status" -ne 2 ]] && ok 'corpus scan completes' || fail 'corpus scan did not complete' "$output"
printf '%s\n' "$output" | sed -n 's/^{"ruleId":"\([A-Z0-9]*\)".*"path":"[^"]*\/\([0-9]*\)\.[A-Za-z]*".*/\1 \2/p' | sort -u > "$T/got"
sort -u "$T/hits" -o "$T/hits"; sort -u "$T/misses" -o "$T/misses"
missed="$(comm -23 "$T/hits" "$T/got")"; false_pos="$(comm -12 "$T/misses" "$T/got")"
show_rows() { while read -r id num; do [[ -z "$id" ]] && continue; printf '  %s: %s\n' "$id" "$(head -n 1 "$T/corpus/$num".*)"; done <<< "$1"; }
[[ -z "$missed" ]] && ok "corpus: all $(wc -l < "$T/hits" | tr -d ' ') hit rows fire" || fail 'corpus: rule did not fire on a hit row' "$(show_rows "$missed")"
[[ -z "$false_pos" ]] && ok "corpus: all $(wc -l < "$T/misses" | tr -d ' ') miss rows stay quiet" || fail 'corpus: rule fired on a miss row' "$(show_rows "$false_pos")"
cp "$T/got" "$ROOT/tmp/corpus-got-sh.txt" 2>/dev/null   # run.ps1 compares its own findings with this file
# The engine has two attribution paths (awk, and a bash fallback for awk without {n,m}). Both must agree.
output="$(cd "$ROOT" && FIXMYVIBE_NO_AWK=1 bash "$AUDIT" --format json "$T/corpus" 2>&1)"
printf '%s\n' "$output" | sed -n 's/^{"ruleId":"\([A-Z0-9]*\)".*"path":"[^"]*\/\([0-9]*\)\.[A-Za-z]*".*/\1 \2/p' | sort -u > "$T/got-fallback"
cmp -s "$T/got" "$T/got-fallback" && ok 'awk path and bash fallback path report the same findings' || fail 'attribution paths disagree' "$(comm -3 "$T/got" "$T/got-fallback")"

# ---- 4. behavior
F="$T/behavior"; mkdir -p "$F"
printf 'api_key = "replace_me"\n' > "$F/clean sample.txt"
run "$ROOT" "$F/clean sample.txt"; expect_status 0 'placeholder exits clean'

printf 'API_KEY = "real-looking-value-123"\n' > "$F/secret.txt"
run "$ROOT" "$F/secret.txt"
expect_status 1 'hardcoded secret blocks'; expect_output 'SEC003' 'finding carries a stable rule id'
refute_output 'real-looking-value-123' 'secret value is not echoed into the report'

printf '.button { outline: none; }\n' > "$F/styles.css"
run "$ROOT" "$F/styles.css"; expect_status 0 'warning passes by default'; expect_output 'PASS WITH REVIEW' 'warning asks for review'
run "$ROOT" --strict-warnings "$F/styles.css"; expect_status 1 'strict mode fails on a warning'

printf 'node.innerHTML = trustedHtml; // fixmyvibe: allow SEC201 sanitized-by-dompurify\n' > "$F/reviewed.js"
run "$ROOT" "$F/reviewed.js"; expect_status 0 'reasoned suppression passes'; expect_output 'ALLOW   SEC201' 'suppression stays visible'
printf 'node.innerHTML = trustedHtml; // fixmyvibe: allow SEC201\n' > "$F/noreason.js"
run "$ROOT" --strict-warnings "$F/noreason.js"; expect_status 1 'suppression without a reason is ignored'

run "$ROOT" "$F/missing.txt"; expect_status 2 'missing target fails closed'
run "$ROOT" --rules "$F/missing.conf" "$F"; expect_status 2 'missing rule pack fails closed'
printf '[BAD1]\nsev = blocker\nmatch = (unclosed\nmsg = broken\n' > "$F/bad.conf"
run "$ROOT" --rules "$F/bad.conf" "$F/styles.css"; expect_status 2 'broken rule pattern fails closed'

printf 'const a = 1;\r\ntry { go(); } catch (e) {\r\n}\r\n' > "$F/crlf.js"
run "$ROOT" "$F/crlf.js"; expect_status 1 'CRLF file: empty catch across two lines blocks'; expect_output 'crlf.js:2' 'two-line finding reports the opening line'

printf '# Notes\n\nNever call `eval(userInput)` or build "SELECT * FROM t WHERE id = " + id in code.\n' > "$F/notes.md"
run "$ROOT" "$F/notes.md"; expect_status 0 'code rules do not fire on prose files'

head -c 3000000 /dev/zero | tr '\0' 'a' > "$F/huge.txt"; printf '\n' >> "$F/huge.txt"
run "$ROOT" "$F/huge.txt"; expect_status 0 'oversized file does not break the scan'

# git-aware modes
G="$T/repo"; mkdir -p "$G/src"
git -C "$G" init --quiet; git -C "$G" config user.email 'tests@example.invalid'; git -C "$G" config user.name 'FixMyVibe Tests'
git -C "$G" config core.autocrlf false
printf 'password = "old-legacy-value-99"\n' > "$G/src/legacy.py"
printf 'node_modules/\nsecret-notes.txt\n' > "$G/.gitignore"
printf 'token = "ignored-real-value-77"\n' > "$G/secret-notes.txt"
git -C "$G" add -A; git -C "$G" commit --quiet -m baseline

run "$G" --staged; expect_status 0 'staged: nothing staged is not a failure'; expect_output 'NOTHING SCANNED' 'staged: empty scan is not reported as a pass'
run "$G" --changed; expect_status 0 'changed: clean tree exits 0'
run "$G" .; expect_status 1 'full scan sees the legacy secret'; refute_output 'secret-notes.txt' 'full scan honors .gitignore'

printf 'safe = True\n' >> "$G/src/legacy.py"
run "$G" --changed; expect_status 0 'changed: legacy lines are not rescanned'; expect_output 'added lines' 'changed: scope is stated'
printf 'token = "brand-new-value-4242"\n' >> "$G/src/legacy.py"
run "$G" --changed; expect_status 1 'changed: new unstaged secret blocks'; expect_output 'src/legacy.py:3' 'changed: line number is the new file line'
run "$G" --staged; expect_status 0 'staged: unstaged change is out of scope'
git -C "$G" add -A
run "$G" --staged; expect_status 1 'staged: staged secret blocks'
git -C "$G" commit --quiet -m second
run "$G" --since HEAD~1; expect_status 1 'since: finds the secret added after the base'
run "$G" --changed; expect_status 0 'changed: committed work is out of scope'

printf 'const q = eval(input);\n' > "$G/src/new file.js"
run "$G" --changed; expect_status 1 'changed: untracked file is scanned'; expect_output 'new file.js:1' 'changed: path with a space is reported'
rm "$G/src/new file.js"

printf 'API_KEY=abc\n' > "$G/.env"
run "$G" --changed; expect_status 1 'env file that is not ignored blocks'; expect_output 'SEC006' 'env finding has its id'
printf '.env\n' >> "$G/.gitignore"
run "$G" --changed; expect_status 0 'ignored env file passes'

printf 'src/legacy.py\nrule:COPY005\n' > "$G/.fixmyvibeignore"
run "$G" .; expect_status 0 'ignore file removes a path from the scan'; expect_output 'COPY005' 'disabled rules are listed'
run "$G" --changed; expect_output 'GATE001' 'changing the gate config is flagged for review'
rm "$G/.fixmyvibeignore"

# hook mode
hook() { local cwd="$1" kind="$2" event="$3"; output="$(cd "$cwd" && printf '%s' "$event" | bash "$AUDIT" --hook "$kind" 2>&1)"; status=$?; }
printf 'os.system("rm " + name)\n' >> "$G/src/legacy.py"
hook "$G" stop '{"hook_event_name":"Stop","stop_hook_active":false}'; expect_status 2 'stop hook blocks on a new blocker'; expect_output 'SEC104' 'stop hook reports the finding'
hook "$G" stop '{"hook_event_name":"Stop","stop_hook_active":true}'; expect_status 0 'stop hook never blocks twice in a row'
hook "$G" edit '{"tool_input":{"file_path":"src/legacy.py"}}'; expect_status 2 'edit hook blocks on the edited file'
git -C "$G" checkout --quiet -- src/legacy.py
printf '.card { outline: none; }\n' > "$G/src/card.css"
hook "$G" edit '{"tool_input":{"file_path":"src/card.css"}}'; expect_status 0 'edit hook stays quiet on warnings'
hook "$G" edit '{"tool_input":{"command":"ls"}}'; expect_status 0 'edit hook ignores events without a file'
hook "$T" stop '{}'; expect_status 0 'stop hook outside a repository does nothing'

echo '----------------------------------------'
if [[ $failures -gt 0 ]]; then printf '%d failed, %d passed.\n' "$failures" "$passes"; exit 1; fi
printf 'All shell audit tests passed (%d assertions).\n' "$passes"
