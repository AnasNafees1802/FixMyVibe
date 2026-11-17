#!/usr/bin/env bash
# FixMyVibe audit, POSIX edition. Mirrors fixmyvibe-audit.ps1; both read bin/rules.conf.
# A fast heuristic scan. A clean result is not proof that a project is secure.
#
#   fixmyvibe-audit.sh [path ...]          scan files or directories (default .)
#   fixmyvibe-audit.sh --changed [path ..] scan lines added since HEAD plus untracked files
#   fixmyvibe-audit.sh --staged            scan lines added in the index (pre-commit)
#   fixmyvibe-audit.sh --since REF         scan lines added since the merge base with REF (CI)
#   --strict-warnings   warnings fail too      --format json   machine output, one finding per line
#   --rules FILE        use another rule pack  --hook stop|edit  agent hook mode (reads JSON on stdin)
#
# Exit codes: 0 no blockers, 1 blockers (or warnings under strict), 2 scan could not complete.
# In hook mode: 0 pass, 2 blockers (reported on stderr so the agent sees them), 1 scan error.
#
# Process spawns are kept to about ten per run because each one costs ~100ms under Git Bash on
# Windows, where agent hooks call this script after every edit.
set -uo pipefail
export LC_ALL=C

mode=files; strict=0; format=text; hook=''; ref=''
here="${BASH_SOURCE[0]%/*}"; [[ "$here" == "${BASH_SOURCE[0]}" ]] && here=.
rules="${FIXMYVIBE_RULES:-$here/rules.conf}"
targets=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --staged) mode=staged ;;
    --changed) mode=changed ;;
    --since) [[ $# -ge 2 ]] || { echo '--since needs a ref.' >&2; exit 2; }; mode=since; ref="$2"; shift ;;
    --strict-warnings) strict=1 ;;
    --format) [[ $# -ge 2 ]] || { echo '--format needs text or json.' >&2; exit 2; }; format="$2"; shift ;;
    --rules) [[ $# -ge 2 ]] || { echo '--rules needs a file.' >&2; exit 2; }; rules="$2"; shift ;;
    --hook) [[ $# -ge 2 ]] || { echo '--hook needs stop or edit.' >&2; exit 2; }; hook="$2"; shift ;;
    --) shift; while [[ $# -gt 0 ]]; do targets+=("$1"); shift; done; break ;;
    -*) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    *) targets+=("$1") ;;
  esac
  shift
done
case "$format" in text|json) ;; *) echo '--format must be text or json.' >&2; exit 2 ;; esac

die() { printf 'FixMyVibe audit failed: %s\n' "$1" >&2; [[ -n "$hook" ]] && exit 1; exit 2; }
git_state=''
in_git() { [[ -z "$git_state" ]] && { git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git_state=yes || git_state=no; }; [[ "$git_state" == yes ]]; }

# ---- hook mode: read the harness event from stdin, and never trap the agent
if [[ -n "$hook" ]]; then
  event=''; while IFS= read -r line || [[ -n "$line" ]]; do event="$event$line"; done
  case "$hook" in
    stop)
      re='"stop_hook_active"[[:space:]]*:[[:space:]]*true'
      [[ "$event" =~ $re ]] && exit 0      # the harness already continued once for this stop
      in_git || exit 0
      mode=changed ;;
    edit)
      re='"file_path"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'
      [[ "$event" =~ $re ]] || exit 0
      edited="${BASH_REMATCH[1]}"; edited="${edited//\\\\/\\}"; edited="${edited//\\\//\/}"
      [[ -f "$edited" ]] || exit 0
      if in_git && git ls-files --error-unmatch -- "$edited" >/dev/null 2>&1; then mode=changed; else mode=files; fi
      targets=("$edited") ;;
    *) echo '--hook must be stop or edit.' >&2; exit 1 ;;
  esac
fi

tmp="$(mktemp -d 2>/dev/null)" || die 'unable to create a temporary directory'
trap 'rm -rf "$tmp"' EXIT
hay="$tmp/hay"; idx="$tmp/idx"; : > "$hay"; : > "$idx"; : > "$tmp/paths"; : > "$tmp/counts"; npats=0
skill_dir="$(cd "$here/.." 2>/dev/null && pwd -P)"

# ---- rule pack
[[ -f "$rules" ]] || die "rule pack not found: $rules"
n=0; g=0; section=''
R_ID=(); R_SEV=(); R_CASE=(); R_SCOPE=(); R_RE=(); R_UNLESS=(); R_MSG=(); R_EXT=(); G_NAME=(); G_EXT=()
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  case "$line" in
    ''|'#'*) continue ;;
    '['*']')
      section="${line#[}"; section="${section%]}"
      if [[ "$section" != groups ]]; then
        n=$((n+1)); R_ID[n]="$section"; R_SEV[n]=warning; R_CASE[n]=s; R_SCOPE[n]=any; R_RE[n]=''; R_UNLESS[n]=''; R_MSG[n]=''
      fi ;;
    *' = '*)
      key="${line%% = *}"; val="${line#* = }"
      if [[ "$section" == groups ]]; then g=$((g+1)); G_NAME[g]="$key"; G_EXT[g]="$val"
      else case "$key" in
        sev) R_SEV[n]="$val" ;; case) R_CASE[n]="$val" ;; scope) R_SCOPE[n]="$val" ;;
        match) R_RE[n]="$val" ;; unless) R_UNLESS[n]="$val" ;; msg) R_MSG[n]="$val" ;;
        *) die "rule ${R_ID[n]}: unknown key $key" ;;
      esac; fi ;;
    *) die "rule pack: cannot parse line: $line" ;;
  esac
done < "$rules"
[[ $n -gt 0 ]] || die 'rule pack is empty'

# ---- project gate config: .fixmyvibeignore holds path globs and "rule:ID" lines
IGN=(); DISABLED=' '
if [[ -f .fixmyvibeignore ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"; line="${line%%#*}"; line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    if [[ "$line" == rule:* ]]; then DISABLED="$DISABLED${line#rule:} "; else IGN+=("${line#./}"); fi
  done < .fixmyvibeignore
fi

for ((i=1; i<=n; i++)); do
  [[ -n "${R_RE[i]}" ]] || die "rule ${R_ID[i]} has no match pattern"
  exts=' '
  for tok in ${R_SCOPE[i]}; do
    found=0
    for ((j=1; j<=g; j++)); do [[ "${G_NAME[j]}" == "$tok" ]] && { exts="$exts${G_EXT[j]} "; found=1; }; done
    [[ $found -eq 0 ]] && exts="$exts$tok "
  done
  R_EXT[i]="$exts"
  # Ten patterns per file: one grep over the whole pack is about ten times slower than six
  # greps over a sixth of it each (measured), because the combined automaton blows up.
  [[ "$DISABLED" == *" ${R_ID[i]} "* ]] || { printf '%s\n' "${R_RE[i]}" >> "$tmp/pats.$((npats / 10))"; npats=$((npats+1)); }
done

shopt -s nocasematch
skipped=0; scan_errors=0; err_text=''
F_SEV=(); F_ID=(); F_PATH=(); F_LINE=(); F_MSG=(); F_TEXT=(); nf=0
S_ID=(); S_PATH=(); S_LINE=(); S_TEXT=(); ns=0
add_finding() { nf=$((nf+1)); F_SEV[nf]="$1"; F_ID[nf]="$2"; F_PATH[nf]="$3"; F_LINE[nf]="$4"; F_MSG[nf]="$5"; F_TEXT[nf]="$6"; }
scan_error() { scan_errors=$((scan_errors+1)); err_text="$err_text$1"$'\n'; }
first_line() { local l=''; IFS= read -r l < "$1"; printf '%s' "$l"; }

path_skipped() { # returns 0 when the path must not be scanned
  local p="${1//\\//}" abs pat
  p="${p#./}"
  case "/$p" in
    */.git/*|*/node_modules/*|*/dist/*|*/build/*|*/.next/*|*/coverage/*|*/vendor/*|*/target/*|*/obj/*|*/__pycache__/*|*/.venv/*) return 0 ;;
    *.min.js|*.min.css|*.map|*.lock|*.snap|*.svg|*/package-lock.json|*/pnpm-lock.yaml|*/go.sum) return 0 ;;
    *.png|*.jpg|*.jpeg|*.gif|*.webp|*.ico|*.pdf|*.zip|*.gz|*.woff|*.woff2|*.ttf|*.mp4|*.mp3|*.exe|*.dll) return 0 ;;
  esac
  if [[ -z "${FIXMYVIBE_SCAN_SELF:-}" ]]; then   # this skill's own files, and any other installed copy
    [[ "/$p" == */skills/fixmyvibe/* ]] && return 0
    case "$p" in /*|[A-Za-z]:/*) abs="$p" ;; *) abs="$PWD/$p" ;; esac
    [[ -n "$skill_dir" && "$abs" == "$skill_dir"/* ]] && return 0
  fi
  for pat in ${IGN[@]+"${IGN[@]}"}; do
    [[ "$p" == $pat || "$p" == */$pat || "$p" == $pat/* || "$p" == */$pat/* ]] && return 0
  done
  return 1
}

file_level() { # engine-coded findings that depend on the file name, not on a line
  local p="$1" base="${1##*/}" from_git="$2"
  if [[ "$base" == .fixmyvibeignore && "$mode" != files ]]; then
    add_finding warning GATE001 "$p" 1 'gate configuration changed: a person should review what is now ignored' ''
  fi
  [[ "$from_git" == 1 ]] || return 0
  case "$base" in
    .env.example|.env.sample|.env.template|.env.dist|.env.defaults|.env.schema|.env.*.example) ;;
    .env|.env.*) [[ "$DISABLED" == *" SEC006 "* ]] || add_finding blocker SEC006 "$p" 1 'env file is not gitignored: ignore it, and rotate anything it already exposed' '' ;;
  esac
}

AWK_EMIT='
function emit(path, n, s,   t) {
  sub(/^\.\//, "", path); sub(/\r$/, "", s); if (length(s) > 2000) s = substr(s, 1, 2000)
  print s >> hay; print path "\t" n >> idx
  t = s; gsub(/^[ \t]+|[ \t]+$/, "", t)
  # An empty block spread over two lines is joined so one-line rules can see it.
  if (path == ppath && n == pn + 1 && (pend == "{" || pend == ":") && t ~ /^(\}[);,]*|pass|\.\.\.)$/) {
    print ptext " " t >> hay; print path "\t" pn >> idx
  }
  ppath = path; pn = n; ptext = s; pend = substr(t, length(t), 1)
}'

scan_files() { # $1: 1 when the list came from git. stdin: NUL separated paths.
  local list="$tmp/list" text="$tmp/text" f p c
  : > "$list"
  while IFS= read -r -d '' f; do
    p="${f#./}"
    [[ -f "$f" ]] || continue
    if path_skipped "$p"; then skipped=$((skipped+1)); continue; fi
    file_level "$p" "$1"
    case "$p" in /*|[A-Za-z]:*) ;; *) p="./$p" ;; esac  # keeps awk from reading a=b.js as an assignment
    printf '%s\0' "$p" >> "$list"
  done
  [[ -s "$list" ]] || return 0
  xargs -0 grep -Il --null -e '' -- < "$list" > "$text" 2> "$tmp/err"
  [[ -s "$tmp/err" ]] && scan_error "$(first_line "$tmp/err")"
  [[ -s "$text" ]] || return 0
  xargs -0 awk -v hay="$hay" -v idx="$idx" -v big="$tmp/big" -v counts="$tmp/counts" "$AWK_EMIT"'
    FNR == 1 { bytes = 0; over = 0; files++ }
    over { next }
    { bytes += length($0) + 1
      if (bytes > 2097152) { over = 1; print FILENAME >> big; next }
      emit(FILENAME, FNR, $0) }
    END { print files + 0, NR >> counts }' < "$text" 2> "$tmp/err" || scan_error "$(first_line "$tmp/err")"
  while read -r c l; do scanned=$((scanned + c)); hay_lines=$((hay_lines + l)); done < "$tmp/counts"; : > "$tmp/counts"
}

list_target() { # $1 target, $2: 1 when it is a directory inside a worktree. Prints NUL separated files.
  local t="${1%/}" f
  [[ -z "$t" ]] && t=/
  if [[ -f "$t" ]]; then printf '%s\0' "$t"; return; fi
  if [[ "$2" == 1 ]] && ! git -C "$t" check-ignore -q . 2>/dev/null; then
    git -C "$t" -c core.quotepath=false ls-files -z --cached --others --exclude-standard |
      while IFS= read -r -d '' f; do printf '%s\0' "$t/$f"; done
  else
    find "$t" -type f ! -name '.env*' ! -path '*/.git/*' ! -path '*/node_modules/*' -print0 2>/dev/null
  fi
}

scan_diff() { # $@: git diff arguments. Appends added lines to the haystack.
  local c p
  git diff --no-color --no-ext-diff --unified=0 --relative --src-prefix=a/ --dst-prefix=b/ \
      --diff-filter=ACMR "$@" > "$tmp/diff" 2> "$tmp/err" || die "git diff failed: $(first_line "$tmp/err")"
  awk -v hay="$hay" -v idx="$idx" -v paths="$tmp/paths" -v counts="$tmp/counts" "$AWK_EMIT"'
    /^diff --git / { path = ""; inh = 0; next }
    /^\+\+\+ / { path = ""; inh = 0
      if ($0 ~ /^\+\+\+ b\//) { path = substr($0, 7); sub(/\t$/, "", path); print path >> paths }
      next }
    /^@@ / { if (path != "") { split($0, a, " "); s = a[3]; sub(/^\+/, "", s); sub(/,.*/, "", s); ln = s + 0; inh = 1 } next }
    inh && /^\+/ { emit(path, ln, substr($0, 2)); ln++; added++; next }
    inh && /^ / { ln++; next }
    END { print added + 0 >> counts }' "$tmp/diff" || die 'unable to parse the diff'
  while IFS= read -r c; do scanned=$((scanned + c)); hay_lines=$((hay_lines + c)); done < "$tmp/counts"; : > "$tmp/counts"
  while IFS= read -r p; do file_level "$p" 1; done < "$tmp/paths"
}

# ---- collect the lines to scan
scanned=0; hay_lines=0; unit='files'
if [[ "$mode" == files ]]; then
  [[ ${#targets[@]} -eq 0 ]] && targets=(.)
  for t in "${targets[@]}"; do [[ -e "$t" ]] || die "path does not exist: $t"; done
  for t in "${targets[@]}"; do
    from_git=0
    [[ -d "$t" ]] && git -C "$t" rev-parse --is-inside-work-tree >/dev/null 2>&1 && from_git=1
    scan_files "$from_git" < <(list_target "$t" "$from_git")
  done
else
  in_git || die "--$mode requires a Git worktree"
  unit='added lines'
  spec=(); [[ ${#targets[@]} -gt 0 ]] && spec=(-- "${targets[@]}")
  case "$mode" in
    staged) scan_diff --cached ${spec[@]+"${spec[@]}"} ;;
    changed|since)
      base=HEAD
      if [[ "$mode" == since ]]; then base="$(git merge-base "$ref" HEAD 2>/dev/null)" || die "cannot find a merge base with $ref"; fi
      if git rev-parse -q --verify "$base^{commit}" >/dev/null 2>&1; then
        scan_diff "$base" ${spec[@]+"${spec[@]}"}
        lines=$scanned; scanned=0
        scan_files 1 < <(git -c core.quotepath=false ls-files -z --others --exclude-standard ${spec[@]+"${spec[@]}"})
        [[ $scanned -gt 0 ]] && unit="added lines, plus $scanned new files"
        scanned=$((lines + scanned))
      else
        unit='files (no commit yet)'; scan_files 1 < <(list_target . 1)
      fi ;;
  esac
fi

# ---- one grep finds candidate lines for the whole pack, then each candidate is attributed to rules.
record() { # rule index, path, line, text: dedupe, honor an allow annotation, store the finding
  local i="$1" path="$2" line="$3" text="$4" id="${R_ID[$1]}" key shown
  key="|$id $path:$line|"   # several patterns share an id; report a line once per id
  [[ "$seen" == *"$key"* ]] && return 0
  seen="$seen$key"
  case "$id" in SEC0[01]*) shown='(excerpt withheld so the secret is not copied into logs)' ;; *) shown="${text:0:200}" ;; esac
  if [[ "$text" =~ fixmyvibe:[[:space:]]*allow[[:space:]]+$id[[:space:]]+[^[:space:]] ]]; then
    ns=$((ns+1)); S_ID[ns]="$id"; S_PATH[ns]="$path"; S_LINE[ns]="$line"; S_TEXT[ns]="$shown"; return 0
  fi
  add_finding "${R_SEV[i]}" "$id" "$path" "$line" "${R_MSG[i]}" "$shown"
}

: > "$tmp/cand"; rc=1
if [[ $hay_lines -eq 0 ]]; then :
elif [[ $hay_lines -le 2000 ]]; then   # a diff or a few files: one process beats six
  all=(); for f in "$tmp"/pats.*; do all+=(-f "$f"); done
  grep -aEin "${all[@]}" -- "$hay" > "$tmp/cand" 2> "$tmp/err"; rc=$?
else
  for f in "$tmp"/pats.*; do
    grep -aEin -f "$f" -- "$hay" >> "$tmp/cand" 2> "$tmp/err"; one=$?
    [[ $one -gt 1 ]] && { rc=2; break; }
    [[ $one -eq 0 ]] && rc=0
  done
fi
if [[ $rc -gt 1 ]]; then
  for ((i=1; i<=n; i++)); do
    printf '' | grep -E -e "${R_RE[i]}" >/dev/null 2>&1
    [[ $? -gt 1 ]] && scan_error "rule ${R_ID[i]}: invalid pattern"
  done
  [[ $scan_errors -eq 0 ]] && scan_error "pattern scan failed: $(first_line "$tmp/err")"
elif [[ $rc -eq 0 ]]; then
  seen=''; fast=0
  if [[ -z "${FIXMYVIBE_NO_AWK:-}" ]]; then
    # Fast path: awk attributes every candidate in one process. It needs interval expressions
    # ({n,m}), which very old mawk lacks; the probe in BEGIN falls back to the bash loop below.
    : > "$tmp/rtab"
    for ((i=1; i<=n; i++)); do
      [[ "$DISABLED" == *" ${R_ID[i]} "* ]] && continue
      printf '%s\t%s\t%s\t%s\t%s\n' "$i" "${R_CASE[i]}" "${R_EXT[i]}" "${R_RE[i]}" "${R_UNLESS[i]}" >> "$tmp/rtab"
    done
    awk -v rulesf="$tmp/rtab" -v idxf="$idx" '
      BEGIN { if ("aaa" !~ /^a{3}$/) { print "NOINTERVAL"; exit } }
      FILENAME == rulesf {
        split($0, f, "\t"); nr++; RI[nr] = f[1]; RC[nr] = f[2]; RX[nr] = tolower(f[3])
        RE[nr] = (f[2] == "i") ? tolower(f[4]) : f[4]; UN[nr] = (f[2] == "i") ? tolower(f[5]) : f[5]; next }
      FILENAME == idxf { I[FNR] = $0; next }
      { c = index($0, ":"); k = substr($0, 1, c - 1); if (k in D) next; D[k] = 1
        nc++; T[nc] = substr($0, c + 1); L[nc] = tolower(T[nc])
        split(I[k], pl, "\t"); P[nc] = pl[1]; N[nc] = pl[2]
        base = pl[1]; sub(/.*\//, "", base); ext = base
        if (base ~ /^\.env/) ext = "env"; else sub(/.*\./, "", ext)
        X[nc] = " " tolower(ext) " " }
      END { # rule in the outer loop: awk compiles a dynamic regex once while it stays the same
        for (r = 1; r <= nr; r++) {
          any = index(RX[r], " any "); ci = (RC[r] == "i"); re = RE[r]; un = UN[r]
          for (k = 1; k <= nc; k++) {
            if (!any && index(RX[r], X[k]) == 0) continue
            t = ci ? L[k] : T[k]
            if (t !~ re) continue
            if (un != "" && t ~ un) continue
            print RI[r] "\t" P[k] "\t" N[k] "\t" T[k] } } }' "$tmp/rtab" "$idx" "$tmp/cand" > "$tmp/joined" 2> "$tmp/err" && fast=1
    [[ $fast -eq 1 && "$(first_line "$tmp/joined")" == NOINTERVAL ]] && fast=0
  fi
  if [[ $fast -eq 1 ]]; then
    while IFS=$'\t' read -r i path line text; do
      [[ "$mode" != files ]] && path_skipped "$path" && continue
      record "$i" "$path" "$line" "$text"
    done < "$tmp/joined"
  else
    # ponytail: the fallback recompiles each rule per candidate line. Correct everywhere, slow on a
    # full scan with thousands of candidates. Installing gawk selects the fast path.
    awk -v idxf="$idx" '
      FILENAME == idxf { I[FNR] = $0; next }
      { c = index($0, ":"); k = substr($0, 1, c - 1); if (k in D) next; D[k] = 1; print I[k] "\t" substr($0, c + 1) }' "$idx" "$tmp/cand" > "$tmp/joined"
    while IFS=$'\t' read -r path line text; do
      [[ "$mode" != files ]] && path_skipped "$path" && continue
      ext="${path##*/}"; [[ "$ext" == .env* ]] && ext=env; ext="${ext##*.}"
      for ((i=1; i<=n; i++)); do
        shopt -s nocasematch
        [[ "${R_EXT[i]}" == *' any '* || "${R_EXT[i]}" == *" $ext "* ]] || continue
        [[ "$DISABLED" == *" ${R_ID[i]} "* ]] && continue
        [[ "${R_CASE[i]}" == i ]] || shopt -u nocasematch
        [[ "$text" =~ ${R_RE[i]} ]] || continue
        [[ -n "${R_UNLESS[i]}" && "$text" =~ ${R_UNLESS[i]} ]] && continue
        shopt -s nocasematch
        record "$i" "$path" "$line" "$text"
      done
      shopt -s nocasematch
    done < "$tmp/joined"
  fi
fi
big=0; if [[ -s "$tmp/big" ]]; then while IFS= read -r _; do big=$((big+1)); done < "$tmp/big"; fi

# ---- report
blockers=0; warnings=0
for ((k=1; k<=nf; k++)); do [[ "${F_SEV[k]}" == blocker ]] && blockers=$((blockers+1)) || warnings=$((warnings+1)); done
if [[ $scan_errors -gt 0 ]]; then code=2
elif [[ $blockers -gt 0 || ( $strict -eq 1 && $warnings -gt 0 ) ]]; then code=1
else code=0; fi

je() { J="$1"; J="${J//\\/\\\\}"; J="${J//\"/\\\"}"; J="${J//$'\t'/ }"; J="${J//$'\r'/}"; J="${J//[$'\001'-$'\037']/ }"; } # sets J; no subshell per field

if [[ "$format" == json ]]; then
  printf '{"version":3,"mode":"%s","scanned":%d,"unit":"%s","blockerCount":%d,"warningCount":%d,"suppressionCount":%d,"skippedCount":%d,"truncatedCount":%d,"secure":null,"exitCode":%d,\n' \
    "$mode" "$scanned" "$unit" "$blockers" "$warnings" "$ns" "$skipped" "$big" "$code"
  printf '"scanErrors":['; first=1
  while IFS= read -r e; do [[ -z "$e" ]] && continue; [[ $first -eq 0 ]] && printf ','; first=0; je "$e"; printf '"%s"' "$J"; done <<< "$err_text"
  printf '],\n"findings":[\n'
  for ((k=1; k<=nf; k++)); do
    je "${F_PATH[k]}"; jp="$J"; je "${F_MSG[k]}"; jm="$J"; je "${F_TEXT[k]}"
    printf '{"ruleId":"%s","severity":"%s","path":"%s","line":%d,"message":"%s","excerpt":"%s"}' \
      "${F_ID[k]}" "${F_SEV[k]}" "$jp" "${F_LINE[k]}" "$jm" "$J"
    [[ $k -lt $nf ]] && printf ','; printf '\n'
  done
  printf '],\n"suppressions":[\n'
  for ((k=1; k<=ns; k++)); do
    je "${S_PATH[k]}"; jp="$J"; je "${S_TEXT[k]}"
    printf '{"ruleId":"%s","path":"%s","line":%d,"excerpt":"%s"}' "${S_ID[k]}" "$jp" "${S_LINE[k]}" "$J"
    [[ $k -lt $ns ]] && printf ','; printf '\n'
  done
  printf ']}\n'
  exit $code
fi

report() {
  local sev k id count label seen
  printf '== FixMyVibe audit: %s %s ==\n' "$scanned" "$unit"
  for sev in blocker warning; do
    [[ "$sev" == warning && -n "$hook" ]] && continue
    label=BLOCKER; [[ "$sev" == warning ]] && label=WARNING
    seen=' '
    for ((k=1; k<=nf; k++)); do
      id="${F_ID[k]}"
      [[ "${F_SEV[k]}" == "$sev" && "$seen" != *" $id "* ]] || continue
      seen="$seen$id "; count=0
      for ((j=k; j<=nf; j++)); do
        [[ "${F_ID[j]}" == "$id" && "${F_SEV[j]}" == "$sev" ]] || continue
        count=$((count+1)); [[ $count -gt 10 ]] && continue
        printf '%s %s %s:%s  %s\n' "$label" "$id" "${F_PATH[j]}" "${F_LINE[j]}" "${F_MSG[j]}"
        [[ -n "${F_TEXT[j]}" ]] && printf '        %s\n' "${F_TEXT[j]}"
      done
      [[ $count -gt 10 ]] && printf '        ... and %d more %s (use --format json for the full list)\n' $((count-10)) "$id"
    done
  done
  for ((k=1; k<=ns; k++)); do printf 'ALLOW   %s %s:%s\n' "${S_ID[k]}" "${S_PATH[k]}" "${S_LINE[k]}"; done
  [[ -n "$err_text" ]] && printf 'ERROR   %s' "$err_text"
  [[ $skipped -gt 0 || $big -gt 0 ]] && printf 'NOTE    %d files skipped by ignore rules, %d files cut off at 2MB\n' "$skipped" "$big"
  [[ "$DISABLED" != ' ' ]] && printf 'NOTE    rules disabled in .fixmyvibeignore:%s\n' "$DISABLED"
  echo '----------------------------------------'
  if [[ $scan_errors -gt 0 ]]; then echo 'ERROR: the scan did not complete. Treat this as a failed gate.'
  elif [[ $blockers -gt 0 ]]; then printf 'FAIL: %d blocker(s), %d warning(s), %d suppression(s). Fix the blockers, then run the audit again.\n' "$blockers" "$warnings" "$ns"
  elif [[ $strict -eq 1 && $warnings -gt 0 ]]; then printf 'FAIL (strict): %d warning(s) need a fix or a recorded reason.\n' "$warnings"
  elif [[ $scanned -eq 0 ]]; then echo 'NOTHING SCANNED: no matching files or added lines. This is not a pass.'
  elif [[ $warnings -gt 0 ]]; then printf 'PASS WITH REVIEW: 0 blockers, %d warning(s), %d suppression(s). Fix each warning or state why it stays.\n' "$warnings" "$ns"
  else printf 'PASS: no heuristic findings, %d suppression(s). This is not proof of security.\n' "$ns"; fi
}

if [[ -n "$hook" ]]; then
  [[ $code -eq 2 ]] && { report >&2; exit 1; }
  [[ $blockers -gt 0 ]] || exit 0
  { report; echo 'FixMyVibe gate: fix these blockers before finishing. If one is a false positive, add "fixmyvibe: allow RULE-ID reason" on that line.'; } >&2
  exit 2
fi
report
exit $code
