#!/usr/bin/env bash
# FixMyVibe audit, POSIX-host edition. Mirrors fixmyvibe-audit.ps1.
# Fast heuristic checks only. A clean result is not proof that a project is secure.
# Exit codes: 0 clean or warnings, 1 blockers/strict warnings, 2 incomplete scan.
set -uo pipefail

staged=0; strict=0; blockers=0; warnings=0; suppressions=0; scan_errors=0; scanned=0
targets=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --staged) staged=1 ;;
    --strict-warnings) strict=1 ;;
    --) shift; targets+=("$@"); break ;;
    -*) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    *) targets+=("$1") ;;
  esac
  shift
done
[[ ${#targets[@]} -eq 0 ]] && targets=(.)

RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; DIM=$'\033[2m'; NC=$'\033[0m'
tmp_dir="$(mktemp -d 2>/dev/null)" || { echo 'Unable to create a temporary directory.' >&2; exit 2; }
trap 'rm -rf "$tmp_dir"' EXIT
records="$tmp_dir/records.tsv"
: > "$records"

is_self_file() {
  case "${1//\\//}" in
    */bin/fixmyvibe-audit.ps1|*/bin/fixmyvibe-audit.sh|*/references/FORBIDDEN-PATTERNS.md) return 0 ;;
  esac
  return 1
}

if [[ $staged -eq 1 ]]; then
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo '--staged requires a Git worktree.' >&2; exit 2; }
  git -c core.quotepath=false diff --cached --unified=0 --no-color --diff-filter=ACMR > "$tmp_dir/diff" || { echo 'git diff failed.' >&2; exit 2; }
  awk '
    /^\+\+\+ b\// { path=substr($0,7); in_hunk=0; next }
    /^@@ / {
      plus=index($0," +"); rest=substr($0,plus+2); split(rest,a,/[, ]/); line=a[1]+0; in_hunk=1; next
    }
    in_hunk && /^\+/ && !/^\+\+\+/ {
      if (path !~ /\/bin\/fixmyvibe-audit\.(ps1|sh)$/ && path !~ /\/references\/FORBIDDEN-PATTERNS\.md$/) {
        print path "\t" line "\t" substr($0,2)
      }
      line++; next
    }
    in_hunk && /^-/ { next }
    in_hunk && /^ / { line++; next }
    in_hunk && /^\\/ { next }
    in_hunk { in_hunk=0 }
  ' "$tmp_dir/diff" > "$records" || { echo 'Unable to parse staged diff.' >&2; exit 2; }
  scanned=$(wc -l < "$records" | tr -d ' ')
else
  for target in "${targets[@]}"; do
    [[ -e "$target" ]] || { printf 'Path does not exist: %s\n' "$target" >&2; exit 2; }
  done
  while IFS= read -r -d '' file; do
    is_self_file "$file" && continue
    size=$(wc -c < "$file" 2>/dev/null) || { printf 'ERROR   unable to read %s\n' "$file" >&2; scan_errors=$((scan_errors+1)); continue; }
    if [[ $size -gt 2097152 ]]; then
      printf 'ERROR   file exceeds 2MB limit: %s\n' "$file" >&2; scan_errors=$((scan_errors+1)); continue
    fi
    if ! LC_ALL=C grep -Iq . "$file" 2>/dev/null; then continue; fi
    awk -v p="$file" '{ print p "\t" NR "\t" $0 }' "$file" >> "$records" || { printf 'ERROR   unable to scan %s\n' "$file" >&2; scan_errors=$((scan_errors+1)); continue; }
    scanned=$((scanned+1))
  done < <(find "${targets[@]}" -type f \
    ! -path '*/.git/*' ! -path '*/node_modules/*' ! -path '*/dist/*' ! -path '*/build/*' \
    ! -path '*/.next/*' ! -path '*/coverage/*' ! -path '*/vendor/*' ! -path '*/target/*' \
    ! -path '*/obj/*' -print0 2>/dev/null)
fi

placeholder_re="[\"'](example|sample|dummy|placeholder|changeme|replace[_-]?me|redacted|your[_-][a-z0-9_-]+|x{6,})[\"']"

scan() { # severity id category regex message [secret]
  local severity="$1" id="$2" category="$3" regex="$4" message="$5" secret="${6:-0}"
  local matches="$tmp_dir/$id"
  grep -Eai "$regex" "$records" > "$matches" 2>/dev/null || true
  while IFS=$'\t' read -r path line content; do
    [[ -z "${path:-}" ]] && continue
    is_self_file "$path" && continue
    if printf '%s\n' "$content" | grep -Eqi "fixmyvibe:[[:space:]]*allow[[:space:]]+$id[[:space:]]+[^[:space:]]+"; then
      suppressions=$((suppressions+1)); printf '%sALLOW%s   [%s] %s:%s\n' "$YEL" "$NC" "$id" "$path" "$line"; continue
    fi
    if [[ "$secret" == 1 ]] && printf '%s\n' "$content" | grep -Eqi "$placeholder_re"; then continue; fi
    if [[ "$severity" == blocker ]]; then blockers=$((blockers+1)); color="$RED"; label='BLOCKER'; else warnings=$((warnings+1)); color="$YEL"; label='WARNING'; fi
    printf '%s%-7s%s [%s] %s\n' "$color" "$label" "$NC" "$id" "$message"
    printf '        %s%s:%s: %s%s\n' "$DIM" "$path" "$line" "${content:0:240}" "$NC"
  done < "$matches"
}

unit='files'; [[ $staged -eq 1 ]] && unit='added lines'
printf '== FixMyVibe audit (%s %s) ==\n' "$scanned" "$unit"

scan blocker SEC001 secrets '(^|[^A-Za-z0-9])(sk-(live-)?[A-Za-z0-9_-]{16,}|AKIA[0-9A-Z]{12,}|AIza[0-9A-Za-z_-]{30,}|gh[pousr]_[A-Za-z0-9]{20,}|glpat-[A-Za-z0-9_-]{16,}|xox[baprs]-[0-9A-Za-z-]{8,})' 'possible hardcoded credential' 1
scan blocker SEC002 secrets '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----' 'private key committed as text' 1
scan blocker SEC003 secrets "(password|passwd|secret|api[_-]?key|access[_-]?token|auth[_-]?token|token)[[:space:]]*[:=][[:space:]]*[\"'][^\"']{6,}[\"']" 'hardcoded credential literal' 1
scan blocker SEC004 secrets '[a-z][a-z0-9+.-]*://[^/@:[:space:]]+:[^/@[:space:]]+@' 'credentials embedded in a URL' 1
scan blocker SEC101 injection '(query|execute|exec)[[:space:]]*\([[:space:]]*`[^`]*(SELECT|INSERT|UPDATE|DELETE|DROP)[^`]*\$\{' 'SQL built with template interpolation'
scan blocker SEC102 injection "(query|execute|exec)[[:space:]]*\([[:space:]]*[\"'][^\"']*(SELECT|INSERT|UPDATE|DELETE|DROP)[^\"']*[\"'][[:space:]]*\+" 'SQL built with string concatenation'
scan blocker SEC103 injection "(query|execute|exec)[[:space:]]*\([[:space:]]*f[\"'][^\"']*(SELECT|INSERT|UPDATE|DELETE|DROP)[^\"']*\{" 'SQL built with an f-string'
scan blocker SEC104 execution '(^|[^a-z])eval[[:space:]]*\(|child_process[[:space:]]*\.[[:space:]]*exec[[:space:]]*\(|os\.system[[:space:]]*\(' 'dynamic code or shell execution requires a proven-safe boundary'
scan blocker SEC105 transport "verify[[:space:]]*=[[:space:]]*false|rejectUnauthorized[[:space:]]*:[[:space:]]*false|NODE_TLS_REJECT_UNAUTHORIZED[[:space:]]*=[[:space:]]*[\"']?0" 'TLS certificate verification disabled'
scan blocker SEC106 crypto '(md5|sha1)[[:space:]]*\([^\r\n]*(password|passwd)|(password|passwd)[^\r\n]*(md5|sha1)[[:space:]]*\(' 'weak password hashing'
scan warning SEC201 xss 'dangerouslySetInnerHTML|\.innerHTML[[:space:]]*=|v-html' 'raw HTML sink, prove the value is trusted or sanitized'
scan warning SEC202 deserialization 'pickle\.loads?[[:space:]]*\(|yaml\.load[[:space:]]*\([^\r\n]*Loader[[:space:]]*=[[:space:]]*yaml\.(Loader|UnsafeLoader)|BinaryFormatter[[:space:]]*\(' 'unsafe deserialization sink'
scan warning SEC203 configuration "Access-Control-Allow-Origin[\"'[:space:]:]+\*|origin[[:space:]]*:[[:space:]]*[\"']\*[\"']|allow_origins[[:space:]]*=[[:space:]]*\[[\"']\*[\"']\]" 'wildcard CORS requires review'
scan warning SEC204 configuration 'debug[[:space:]]*[:=][[:space:]]*true|app\.run\([^\r\n]*debug[[:space:]]*=[[:space:]]*True' 'debug mode may be enabled'
scan blocker COR001 errors 'except[[:space:]]*:[[:space:]]*pass|catch[[:space:]]*\([^)]*\)[[:space:]]*\{[[:space:]]*\}' 'swallowed error'
scan warning UX001 focus 'outline[[:space:]]*:[[:space:]]*none|outline-none' 'focus outline removed without a proven replacement'
scan warning UX002 responsive 'overflow-x[[:space:]]*:[[:space:]]*hidden' 'body scroll may be hidden instead of fixing overflow'
scan warning SLOP001 visual 'from-purple-[0-9]|to-blue-[0-9]|from-violet-|to-indigo-|#16d5e6' 'common generated gradient/accent fingerprint'
scan warning SLOP002 visual 'rounded-2xl' 'large default radius, check for repeated card treatment'
scan warning SLOP003 layout 'grid-template-columns[[:space:]]*:[[:space:]]*(repeat\([^,]+,[[:space:]]*)?1fr' 'bare 1fr grid track can overflow'
scan warning SLOP004 copy 'best-in-class|cutting-edge|all-in-one platform|build the future of|unlock your|seamless(ly)?|supercharge|game[- ]changer' 'generic or unsupported marketing copy'

echo '----------------------------------------'
if [[ $scan_errors -gt 0 ]]; then
  printf '%sERROR%s - scan incomplete. Treat this as a failed gate.\n' "$RED" "$NC"; exit 2
elif [[ $blockers -gt 0 ]]; then
  printf '%sFAIL%s - %d blocker(s), %d warning(s), %d suppression(s).\n' "$RED" "$NC" "$blockers" "$warnings" "$suppressions"; exit 1
elif [[ $strict -eq 1 && $warnings -gt 0 ]]; then
  printf '%sFAIL STRICT%s - %d warning(s) require review.\n' "$RED" "$NC" "$warnings"; exit 1
elif [[ $warnings -gt 0 ]]; then
  printf '%sPASS WITH REVIEW%s - %d warning(s), %d suppression(s), 0 blockers.\n' "$YEL" "$NC" "$warnings" "$suppressions"; exit 0
else
  printf '%sPASS%s - no heuristic findings, %d suppression(s). This is not proof of security.\n' "$GRN" "$NC" "$suppressions"; exit 0
fi
