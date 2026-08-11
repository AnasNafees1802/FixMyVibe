#!/usr/bin/env bash
# fixmyvibe-audit — machine-checkable slice of the FixMyVibe Finish Gate.
# Greps target files for high-signal FORBIDDEN-PATTERNS and exits non-zero on any BLOCKER.
# Human-judgment gates (logo test, scope, maintainer test) still require a person / the agent.
#
# Usage:
#   fixmyvibe-audit.sh [path ...]      # scan given files/dirs (default: current dir)
#   fixmyvibe-audit.sh --staged        # scan git staged changes only
# Wire into CI or a pre-commit / agent Stop hook.
set -uo pipefail

RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; DIM=$'\033[2m'; NC=$'\033[0m'
blockers=0; warns=0

hit()  { blockers=$((blockers+1)); printf "%sBLOCKER%s [%s] %s\n         %s%s%s\n" "$RED" "$NC" "$1" "$2" "$DIM" "$3" "$NC"; }
warn() { warns=$((warns+1));       printf "%sWARN%s    [%s] %s\n         %s%s%s\n" "$YEL" "$NC" "$1" "$2" "$DIM" "$3" "$NC"; }

# Build file list
files=()
if [[ "${1:-}" == "--staged" ]]; then
  while IFS= read -r f; do [[ -f "$f" ]] && files+=("$f"); done < <(git diff --cached --name-only 2>/dev/null)
else
  targets=("${@:-.}")
  while IFS= read -r f; do files+=("$f"); done < <(
    grep -rIl --exclude-dir={.git,node_modules,dist,build,.next,vendor} '' "${targets[@]}" 2>/dev/null)
fi
[[ ${#files[@]} -eq 0 ]] && { echo "No files to scan."; exit 0; }

scan() { # scan LABEL SEVERITY REGEX MESSAGE
  local sev="$1" label="$2" re="$3" msg="$4"
  local out; out=$(grep -REnI "$re" "${files[@]}" 2>/dev/null | grep -viE 'FORBIDDEN-PATTERNS|fixmyvibe-audit|example|allowlist' )
  if [[ -n "$out" ]]; then
    while IFS= read -r line; do
      [[ "$sev" == block ]] && hit "$label" "$msg" "$line" || warn "$label" "$msg" "$line"
    done <<< "$out"
  fi
}

echo "== FixMyVibe audit (${#files[@]} files) =="

# ---- §A security BLOCKERS ----
scan block secrets   'sk-[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{12,}|-----BEGIN (RSA|OPENSSH|PRIVATE)|xox[baprs]-[0-9A-Za-z-]{8,}' 'possible hardcoded secret/key'
scan block secrets   '(password|passwd|secret|api[_-]?key|token)\s*[:=]\s*["'"'"'][^"'"'"']{6,}' 'hardcoded credential literal'
scan block secrets   '://[^/@:\s]+:[^/@\s]+@' 'credentials embedded in a URL'
scan block injection '(query|execute|exec)[[:space:]]*\([[:space:]]*`[^`]*(SELECT|INSERT|UPDATE|DELETE|DROP)[^`]*\$\{' 'SQL built in a template literal (use parameters)'
scan block injection '(query|execute|exec)[[:space:]]*\([[:space:]]*"[^"]*(SELECT|INSERT|UPDATE|DELETE|DROP)[^"]*"[[:space:]]*\+' 'concatenated SQL string (use parameters)'
scan block injection '(query|execute|exec)[[:space:]]*\([[:space:]]*f"[^"]*(SELECT|INSERT|UPDATE|DELETE|DROP)[^"]*\{' 'f-string SQL (use parameters)'
scan block xss       'dangerouslySetInnerHTML|\.innerHTML\s*=|v-html' 'raw HTML injection sink'
scan block exec      '\beval\s*\(|child_process.*exec\(|os\.system\(' 'dynamic code / shell execution'
scan block swallow   'except\s*:\s*pass|catch\s*\([^)]*\)\s*\{\s*\}' 'swallowed error (empty catch)'
scan block cors      "Access-Control-Allow-Origin[\"'\s:]+\*|cors\(\s*\{\s*origin\s*:\s*['\"]\*" 'CORS wildcard *'

# ---- §C design slop tells (WARN — allowed only with a deliberate reason) ----
scan warn slop-color   'from-purple-[0-9]|to-blue-[0-9]|from-violet-|to-indigo-|#16d5e6' 'purple/teal slop gradient — pick a direction'
scan warn slop-radius  'rounded-2xl' 'uniform rounded-2xl — vary radius intentionally'
scan warn slop-grid    'grid-template-columns:\s*[0-9]*\s*1fr|repeat\([^,]+,\s*1fr\)' 'bare 1fr grid — use minmax(0,1fr)'
scan warn a11y-focus   'outline:\s*none|outline-none' 'removed focus outline — add :focus-visible'
scan warn slop-italic  'font-style:\s*italic' 'italic (check it is not a heading)'
scan warn overflow     'overflow-x:\s*hidden' 'overflow-x:hidden as scroll-hider — use clip'
scan warn slop-copy    'best-in-class|cutting-edge|all-in-one platform|build the future of' 'generic filler copy'

echo "----------------------------------------"
if [[ $blockers -gt 0 ]]; then
  printf "%sFAIL%s — %d blocker(s), %d warning(s). Not done. Fix blockers; justify or fix warnings.\n" "$RED" "$NC" "$blockers" "$warns"
  exit 1
elif [[ $warns -gt 0 ]]; then
  printf "%sPASS with warnings%s — 0 blockers, %d warning(s). Justify each kept warning in the diff.\n" "$YEL" "$NC" "$warns"
  exit 0
else
  printf "%sPASS%s — no blocklist hits in the automatable slice. Still run the human-judgment gates.\n" "$GRN" "$NC"
  exit 0
fi
