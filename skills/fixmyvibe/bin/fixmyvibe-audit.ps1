<#
  fixmyvibe-audit.ps1 - machine-checkable slice of the FixMyVibe Finish Gate (Windows/PowerShell).
  Scans target files for high-signal FORBIDDEN-PATTERNS; exits 1 on any BLOCKER.
  Human-judgment gates (logo test, scope, maintainer test) still require a person / the agent.
  (ASCII-only on purpose: PowerShell 5.1 reads .ps1 as ANSI, so non-ASCII chars can corrupt parsing.)

  Usage:
    fixmyvibe-audit.ps1 [-Staged] [path ...]
  Wire into CI or a pre-commit / agent Stop hook.
#>
[CmdletBinding()]
param([switch]$Staged, [Parameter(ValueFromRemainingArguments=$true)][string[]]$Paths)

$ErrorActionPreference = 'SilentlyContinue'
$script:blockers = 0
$script:warns = 0

# Collect files
$files = @()
if ($Staged) {
  $files = (git diff --cached --name-only) | Where-Object { Test-Path $_ -PathType Leaf }
} else {
  if (-not $Paths) { $Paths = @('.') }
  $skip = '\\(\.git|node_modules|dist|build|\.next|vendor)\\'
  $files = Get-ChildItem -Path $Paths -Recurse -File |
           Where-Object { $_.FullName -notmatch $skip } | Select-Object -ExpandProperty FullName
}
if (-not $files) { Write-Host 'No files to scan.'; exit 0 }

function Scan([string]$Sev,[string]$Label,[string]$Re,[string]$Msg){
  foreach ($f in $files) {
    # Skip docs, placeholders, env-refs, and test fixtures - not real secrets. (Select-String is case-insensitive.)
    $excl = 'FORBIDDEN-PATTERNS|fixmyvibe-audit|allowlist|example|sample|dummy|mock|fixture|placeholder|changeme|redacted|your[_-]|process\.env|import\.meta|getenv|ENV\[|<[^>]+>|xxxx|test[_-]|[_-]test'
    $m = Select-String -Path $f -Pattern $Re -AllMatches 2>$null |
         Where-Object { $_.Line -notmatch $excl }
    foreach ($hit in $m) {
      $line = if ($hit.Line) { $hit.Line.Trim() } else { '' }
      $loc = '{0}:{1}: {2}' -f $f, $hit.LineNumber, $line
      if ($Sev -eq 'block') {
        $script:blockers = $script:blockers + 1
        Write-Host ('BLOCKER [{0}] {1}' -f $Label, $Msg) -ForegroundColor Red
        Write-Host ('         ' + $loc) -ForegroundColor DarkGray
      } else {
        $script:warns = $script:warns + 1
        Write-Host ('WARN    [{0}] {1}' -f $Label, $Msg) -ForegroundColor Yellow
        Write-Host ('         ' + $loc) -ForegroundColor DarkGray
      }
    }
  }
}

Write-Host ('== FixMyVibe audit ({0} files) ==' -f $files.Count)

# --- Section A security BLOCKERS ---
Scan block secrets   'sk-[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{12,}|-----BEGIN (RSA|OPENSSH|PRIVATE)|xox[baprs]-[0-9A-Za-z-]{8,}' 'possible hardcoded secret/key'
Scan block secrets   '(password|passwd|secret|api[_-]?key|token)\s*[:=]\s*["''][^"'']{6,}' 'hardcoded credential literal'
Scan block secrets   '://[^/@:\s]+:[^/@\s]+@' 'credentials embedded in a URL'
Scan block injection '(query|execute|exec)\s*\(\s*`[^`]*(SELECT|INSERT|UPDATE|DELETE|DROP)[^`]*\$\{' 'SQL built in a template literal (use parameters)'
Scan block injection '(query|execute|exec)\s*\(\s*"[^"]*(SELECT|INSERT|UPDATE|DELETE|DROP)[^"]*"\s*\+' 'concatenated SQL string (use parameters)'
Scan block injection '(query|execute|exec)\s*\(\s*f"[^"]*(SELECT|INSERT|UPDATE|DELETE|DROP)[^"]*\{' 'f-string SQL (use parameters)'
Scan block xss       'dangerouslySetInnerHTML|\.innerHTML\s*=|v-html' 'raw HTML injection sink'
Scan block exec      '\beval\s*\(|child_process.*exec\(|os\.system\(' 'dynamic code / shell execution'
Scan block swallow   'except\s*:\s*pass|catch\s*\([^)]*\)\s*\{\s*\}' 'swallowed error (empty catch)'
Scan block cors      'Access-Control-Allow-Origin["''\s:]+\*|origin\s*:\s*["'']\*' 'CORS wildcard'

# --- Section C design slop tells (WARN) ---
Scan warn slop-color  'from-purple-[0-9]|to-blue-[0-9]|from-violet-|to-indigo-|#16d5e6' 'purple/teal slop gradient - pick a direction'
Scan warn slop-radius 'rounded-2xl' 'uniform rounded-2xl - vary radius intentionally'
Scan warn slop-grid   'grid-template-columns:\s*[0-9]*\s*1fr|repeat\([^,]+,\s*1fr\)' 'bare 1fr grid - use minmax(0,1fr)'
Scan warn a11y-focus  'outline:\s*none|outline-none' 'removed focus outline - add :focus-visible'
Scan warn slop-italic 'font-style:\s*italic' 'italic (check it is not a heading)'
Scan warn overflow    'overflow-x:\s*hidden' 'overflow-x:hidden as scroll-hider - use clip'
Scan warn slop-copy   'best-in-class|cutting-edge|all-in-one platform|build the future of' 'generic filler copy'

Write-Host '----------------------------------------'
if ($script:blockers -gt 0) {
  Write-Host ('FAIL - {0} blocker(s), {1} warning(s). Not done. Fix blockers; justify or fix warnings.' -f $script:blockers, $script:warns) -ForegroundColor Red
  exit 1
} elseif ($script:warns -gt 0) {
  Write-Host ('PASS with warnings - 0 blockers, {0} warning(s). Justify each kept warning in the diff.' -f $script:warns) -ForegroundColor Yellow
  exit 0
} else {
  Write-Host 'PASS - no blocklist hits in the automatable slice. Still run the human-judgment gates.' -ForegroundColor Green
  exit 0
}
