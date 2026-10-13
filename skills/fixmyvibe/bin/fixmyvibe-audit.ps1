<#
  FixMyVibe audit, Windows edition.

  This is a fast, deterministic heuristic scan. It is not a vulnerability scanner and a clean
  result is not proof that a project is secure. Use it with the stack-native checks selected in
  references/SECURITY-VERIFICATION.md.

  Usage:
    ./fixmyvibe-audit.ps1 [path ...]
    ./fixmyvibe-audit.ps1 -Staged
    ./fixmyvibe-audit.ps1 -Staged -StrictWarnings
    ./fixmyvibe-audit.ps1 -Format Json src

  Exit codes: 0 clean or warnings, 1 blocker (or warning in strict mode), 2 scan failure.
  ASCII-only so Windows PowerShell 5.1 can parse this file reliably.
#>
[CmdletBinding()]
param(
  [switch]$Staged,
  [switch]$StrictWarnings,
  [ValidateSet('Text', 'Json')][string]$Format = 'Text',
  [ValidateRange(1, 100)][int]$MaxFileSizeMB = 2,
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$Paths
)

$ErrorActionPreference = 'Stop'
$script:findings = New-Object System.Collections.Generic.List[object]
$script:suppressions = New-Object System.Collections.Generic.List[object]
$script:scanErrors = New-Object System.Collections.Generic.List[string]

$rules = @(
  @{ Id='SEC001'; Severity='blocker'; Category='secrets'; Pattern='(?<![A-Za-z0-9])(?:sk-(?:live-)?[A-Za-z0-9_-]{16,}|AKIA[0-9A-Z]{12,}|AIza[0-9A-Za-z_-]{30,}|gh[pousr]_[A-Za-z0-9]{20,}|glpat-[A-Za-z0-9_-]{16,}|xox[baprs]-[0-9A-Za-z-]{8,})'; Message='possible hardcoded credential' },
  @{ Id='SEC002'; Severity='blocker'; Category='secrets'; Pattern='-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----'; Message='private key committed as text' },
  @{ Id='SEC003'; Severity='blocker'; Category='secrets'; Pattern='(?i)(password|passwd|secret|api[_-]?key|access[_-]?token|auth[_-]?token|token)\s*[:=]\s*["''][^"'']{6,}["'']'; Message='hardcoded credential literal' },
  @{ Id='SEC004'; Severity='blocker'; Category='secrets'; Pattern='[a-z][a-z0-9+.-]*://[^/@:\s]+:[^/@\s]+@'; Message='credentials embedded in a URL' },
  @{ Id='SEC101'; Severity='blocker'; Category='injection'; Pattern='(?i)(query|execute|exec)\s*\(\s*`[^`]*(SELECT|INSERT|UPDATE|DELETE|DROP)[^`]*\$\{'; Message='SQL built with template interpolation' },
  @{ Id='SEC102'; Severity='blocker'; Category='injection'; Pattern='(?i)(query|execute|exec)\s*\(\s*["''][^"'']*(SELECT|INSERT|UPDATE|DELETE|DROP)[^"'']*["'']\s*\+'; Message='SQL built with string concatenation' },
  @{ Id='SEC103'; Severity='blocker'; Category='injection'; Pattern='(?i)(query|execute|exec)\s*\(\s*f["''][^"'']*(SELECT|INSERT|UPDATE|DELETE|DROP)[^"'']*\{'; Message='SQL built with an f-string' },
  @{ Id='SEC104'; Severity='blocker'; Category='execution'; Pattern='\beval\s*\(|(?i)child_process\s*\.\s*exec\s*\(|(?i)os\.system\s*\('; Message='dynamic code or shell execution requires a proven-safe boundary' },
  @{ Id='SEC105'; Severity='blocker'; Category='transport'; Pattern='(?i)(verify\s*=\s*false|rejectUnauthorized\s*:\s*false|NODE_TLS_REJECT_UNAUTHORIZED\s*=\s*["'']?0)'; Message='TLS certificate verification disabled' },
  @{ Id='SEC106'; Severity='blocker'; Category='crypto'; Pattern='(?i)(md5|sha1)\s*\([^\r\n]*(password|passwd)|(?:password|passwd)[^\r\n]*(md5|sha1)\s*\('; Message='weak password hashing' },
  @{ Id='SEC201'; Severity='warning'; Category='xss'; Pattern='dangerouslySetInnerHTML|\.innerHTML\s*=|\bv-html\b'; Message='raw HTML sink, prove the value is trusted or sanitized' },
  @{ Id='SEC202'; Severity='warning'; Category='deserialization'; Pattern='(?i)pickle\.loads?\s*\(|yaml\.load\s*\([^\r\n]*Loader\s*=\s*yaml\.(Loader|UnsafeLoader)|BinaryFormatter\s*\('; Message='unsafe deserialization sink' },
  @{ Id='SEC203'; Severity='warning'; Category='configuration'; Pattern='(?i)Access-Control-Allow-Origin["''\s:]+\*|origin\s*:\s*["'']\*["'']|allow_origins\s*=\s*\[["'']\*["'']\]'; Message='wildcard CORS, verify this is an intentional public no-credentials API' },
  @{ Id='SEC204'; Severity='warning'; Category='configuration'; Pattern='(?i)(debug\s*[:=]\s*true|app\.run\([^\r\n]*debug\s*=\s*True)'; Message='debug mode may be enabled' },
  @{ Id='COR001'; Severity='blocker'; Category='errors'; Pattern='(?i)except\s*:\s*pass|catch\s*\([^)]*\)\s*\{\s*\}'; Message='swallowed error' },
  @{ Id='UX001'; Severity='warning'; Category='focus'; Pattern='(?i)outline\s*:\s*none|\boutline-none\b'; Message='focus outline removed, require a visible focus-visible replacement' },
  @{ Id='UX002'; Severity='warning'; Category='responsive'; Pattern='(?i)overflow-x\s*:\s*hidden'; Message='body scroll may be hidden instead of fixing overflow' },
  @{ Id='SLOP001'; Severity='warning'; Category='visual'; Pattern='from-purple-[0-9]|to-blue-[0-9]|from-violet-|to-indigo-|#16d5e6'; Message='common generated gradient/accent fingerprint' },
  @{ Id='SLOP002'; Severity='warning'; Category='visual'; Pattern='\brounded-2xl\b'; Message='large default radius, check for repeated card treatment' },
  @{ Id='SLOP003'; Severity='warning'; Category='layout'; Pattern='(?i)grid-template-columns\s*:\s*(repeat\([^,]+,\s*)?1fr'; Message='bare 1fr grid track can overflow, prefer minmax(0, 1fr)' },
  @{ Id='SLOP004'; Severity='warning'; Category='copy'; Pattern='(?i)best-in-class|cutting-edge|all-in-one platform|build the future of|unlock your|seamless(ly)?|supercharge|game[- ]changer'; Message='generic or unsupported marketing copy' }
)

function Test-PlaceholderLine([string]$Line) {
  return $Line -match '(?i)["''](?:example|sample|dummy|placeholder|changeme|replace[_-]?me|redacted|your[_-][a-z0-9_-]+|x{6,})["'']'
}

function Test-SelfFile([string]$Path) {
  $p = $Path -replace '\\', '/'
  return $p -match '/bin/fixmyvibe-audit\.(ps1|sh)$' -or $p -match '/references/FORBIDDEN-PATTERNS\.md$'
}

function Add-Finding($Rule, [string]$Path, [int]$LineNumber, [string]$Line) {
  if ($Line -match ("(?i)fixmyvibe:\s*allow\s+" + [regex]::Escape($Rule.Id) + "\s+(\S.*)$")) {
    $script:suppressions.Add([pscustomobject]@{ ruleId=$Rule.Id; originalSeverity=$Rule.Severity; path=$Path; line=$LineNumber; reason=$Matches[1].Trim(); excerpt=$Line.Trim() })
    return
  }
  if ($Rule.Category -eq 'secrets' -and (Test-PlaceholderLine $Line)) { return }
  $script:findings.Add([pscustomobject]@{
    ruleId = $Rule.Id
    severity = $Rule.Severity
    category = $Rule.Category
    path = $Path
    line = $LineNumber
    message = $Rule.Message
    excerpt = $Line.Trim()
  })
}

function Scan-Line([string]$Path, [int]$LineNumber, [string]$Line) {
  foreach ($rule in $rules) {
    if ([regex]::IsMatch($Line, $rule.Pattern)) { Add-Finding $rule $Path $LineNumber $Line }
  }
}

function Scan-File([string]$Path) {
  $item = Get-Item -LiteralPath $Path
  if ($item.Length -gt ($MaxFileSizeMB * 1MB)) {
    $script:scanErrors.Add("File exceeds ${MaxFileSizeMB}MB limit: $Path")
    return
  }
  $bytes = [System.IO.File]::ReadAllBytes($item.FullName)
  if ($bytes -contains 0) { return }
  $lines = [System.IO.File]::ReadAllLines($item.FullName)
  for ($i = 0; $i -lt $lines.Length; $i++) { Scan-Line $item.FullName ($i + 1) $lines[$i] }
}

function Get-TargetFiles {
  if (-not $Paths) { $script:Paths = @('.') }
  $skip = '[\\/](\.git|node_modules|dist|build|\.next|coverage|vendor|target|obj)[\\/]'
  $seen = @{}
  foreach ($path in $Paths) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Path does not exist: $path" }
    $items = if (Test-Path -LiteralPath $path -PathType Leaf) { @(Get-Item -LiteralPath $path) } else { @(Get-ChildItem -LiteralPath $path -Recurse -File) }
    foreach ($item in $items) {
      if ($item.FullName -match $skip -or (Test-SelfFile $item.FullName)) { continue }
      if (-not $seen.ContainsKey($item.FullName)) { $seen[$item.FullName] = $true; $item.FullName }
    }
  }
}

function Scan-StagedDiff {
  & git rev-parse --is-inside-work-tree *> $null
  if ($LASTEXITCODE -ne 0) { throw '-Staged requires a Git worktree.' }
  $diff = @(& git -c core.quotepath=false diff --cached --unified=0 --no-color --diff-filter=ACMR)
  if ($LASTEXITCODE -ne 0) { throw 'git diff failed.' }
  $currentPath = $null
  $newLine = 0
  $inHunk = $false
  $count = 0
  foreach ($line in $diff) {
    if ($line -match '^\+\+\+ b/(.*)$') { $currentPath = $Matches[1]; $inHunk = $false; continue }
    if ($line -match '^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@') { $newLine = [int]$Matches[1]; $inHunk = $true; continue }
    if (-not $inHunk -or -not $currentPath -or (Test-SelfFile $currentPath)) { continue }
    if ($line.StartsWith('+')) { Scan-Line $currentPath $newLine $line.Substring(1); $newLine++; $count++ }
    elseif ($line.StartsWith('-')) { continue }
    elseif ($line.StartsWith(' ')) { $newLine++ }
    elseif ($line.StartsWith('\')) { continue }
    else { $inHunk = $false }
  }
  return $count
}

function Write-TextResult([int]$Scanned) {
  $unit = if ($Staged) { 'added lines' } else { 'files' }
  Write-Host ("== FixMyVibe audit ($Scanned $unit) ==")
  foreach ($finding in $script:findings) {
    $color = if ($finding.severity -eq 'blocker') { 'Red' } else { 'Yellow' }
    Write-Host (("{0,-7} [{1}] {2}" -f $finding.severity.ToUpperInvariant(), $finding.ruleId, $finding.message)) -ForegroundColor $color
    Write-Host ("        {0}:{1}: {2}" -f $finding.path, $finding.line, $finding.excerpt) -ForegroundColor DarkGray
  }
  foreach ($scanError in $script:scanErrors) { Write-Host ("ERROR   $scanError") -ForegroundColor Red }
  foreach ($suppression in $script:suppressions) {
    Write-Host ("ALLOW   [{0}] {1}:{2} - {3}" -f $suppression.ruleId, $suppression.path, $suppression.line, $suppression.reason) -ForegroundColor DarkYellow
  }
  $blockers = @($script:findings | Where-Object severity -eq 'blocker').Count
  $warnings = @($script:findings | Where-Object severity -eq 'warning').Count
  Write-Host '----------------------------------------'
  if ($script:scanErrors.Count -gt 0) { Write-Host 'ERROR - scan incomplete. Treat this as a failed gate.' -ForegroundColor Red }
  elseif ($blockers -gt 0) { Write-Host ("FAIL - $blockers blocker(s), $warnings warning(s), $($script:suppressions.Count) suppression(s).") -ForegroundColor Red }
  elseif ($StrictWarnings -and $warnings -gt 0) { Write-Host ("FAIL STRICT - $warnings warning(s) require review.") -ForegroundColor Red }
  elseif ($warnings -gt 0) { Write-Host ("PASS WITH REVIEW - $warnings warning(s), $($script:suppressions.Count) suppression(s), 0 blockers.") -ForegroundColor Yellow }
  else { Write-Host ("PASS - no heuristic findings, $($script:suppressions.Count) suppression(s). This is not proof of security.") -ForegroundColor Green }
}

try {
  $scanned = 0
  if ($Staged) { $scanned = Scan-StagedDiff }
  else {
    $targetFiles = @(Get-TargetFiles)
    foreach ($file in $targetFiles) {
      try { Scan-File $file; $scanned++ } catch { $script:scanErrors.Add("$file - $($_.Exception.Message)") }
    }
  }
  $blockerCount = @($script:findings | Where-Object severity -eq 'blocker').Count
  $warningCount = @($script:findings | Where-Object severity -eq 'warning').Count
  $exitCode = if ($script:scanErrors.Count -gt 0) { 2 } elseif ($blockerCount -gt 0 -or ($StrictWarnings -and $warningCount -gt 0)) { 1 } else { 0 }
  if ($Format -eq 'Json') {
    [pscustomobject]@{ version=2; mode=$(if ($Staged) { 'staged-added-lines' } else { 'files' }); scanned=$scanned; blockerCount=$blockerCount; warningCount=$warningCount; suppressionCount=$script:suppressions.Count; scanErrors=$script:scanErrors.ToArray(); findings=$script:findings.ToArray(); suppressions=$script:suppressions.ToArray(); secure=$null; exitCode=$exitCode } | ConvertTo-Json -Depth 6
  } else { Write-TextResult $scanned }
  exit $exitCode
} catch {
  if ($Format -eq 'Json') { [pscustomobject]@{ version=2; scanErrors=@($_.Exception.Message); findings=@(); secure=$null; exitCode=2 } | ConvertTo-Json -Depth 4 }
  else { [Console]::Error.WriteLine("FixMyVibe audit failed: " + $_.Exception.Message) }
  exit 2
}
