<#
  FixMyVibe audit, PowerShell edition. Mirrors fixmyvibe-audit.sh; both read bin/rules.conf.
  A fast heuristic scan. A clean result is not proof that a project is secure.

    ./fixmyvibe-audit.ps1 [path ...]           scan files or directories (default .)
    ./fixmyvibe-audit.ps1 -Changed [path ...]  scan lines added since HEAD plus untracked files
    ./fixmyvibe-audit.ps1 -Staged              scan lines added in the index (pre-commit)
    ./fixmyvibe-audit.ps1 -Since REF           scan lines added since the merge base with REF (CI)
    -StrictWarnings  warnings fail too         -Format Json   machine output
    -Rules FILE      use another rule pack     -Hook stop|edit  agent hook mode (reads JSON on stdin)

  Exit codes: 0 no blockers, 1 blockers (or warnings under strict), 2 scan could not complete.
  In hook mode: 0 pass, 2 blockers (reported on stderr so the agent sees them), 1 scan error.
  ASCII-only so Windows PowerShell 5.1 parses this file the same on every code page.
#>
[CmdletBinding()]
param(
  [switch]$Staged,
  [switch]$Changed,
  [string]$Since = '',
  [switch]$StrictWarnings,
  [ValidateSet('Text', 'Json')][string]$Format = 'Text',
  [string]$Rules = '',
  [ValidateSet('', 'stop', 'edit')][string]$Hook = '',
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$Paths
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { } # fixmyvibe: allow COR001 no console attached; the default encoding still works
[Environment]::CurrentDirectory = (Get-Location).ProviderPath   # so .NET file calls resolve relative paths like the shell does

$script:mode = 'files'
if ($Staged) { $script:mode = 'staged' } elseif ($Changed) { $script:mode = 'changed' } elseif ($Since) { $script:mode = 'since' }
$script:findings = New-Object System.Collections.Generic.List[object]
$script:suppressions = New-Object System.Collections.Generic.List[object]
$script:scanErrors = New-Object System.Collections.Generic.List[string]
$script:units = New-Object System.Collections.Generic.List[object]
$script:skipped = 0; $script:truncated = 0; $script:scanned = 0; $script:chars = 0
$script:disabled = @{}
$script:ignore = @()
$skillDir = ((Split-Path $PSScriptRoot -Parent) -replace '\\', '/').TrimEnd('/') + '/'

function Stop-Audit([string]$Message) {
  [Console]::Error.WriteLine('FixMyVibe audit failed: ' + $Message)
  if ($Hook) { exit 1 }
  exit 2
}
function Test-Git { & git rev-parse --is-inside-work-tree 2>$null | Out-Null; return ($LASTEXITCODE -eq 0) }

# ---- hook mode: read the harness event from stdin, and never trap the agent
if ($Hook) {
  $event = [Console]::In.ReadToEnd()
  if ($Hook -eq 'stop') {
    if ($event -match '"stop_hook_active"\s*:\s*true') { exit 0 }   # the harness already continued once for this stop
    if (-not (Test-Git)) { exit 0 }
    $script:mode = 'changed'; $Paths = @()
  } else {
    if ($event -notmatch '"file_path"\s*:\s*"((?:[^"\\]|\\.)*)"') { exit 0 }
    $edited = $Matches[1].Replace('\\', '\').Replace('\/', '/')
    if (-not (Test-Path -LiteralPath $edited -PathType Leaf)) { exit 0 }
    $script:mode = 'files'
    if (Test-Git) { & git ls-files --error-unmatch -- $edited 2>$null | Out-Null; if ($LASTEXITCODE -eq 0) { $script:mode = 'changed' } }
    $Paths = @($edited)
  }
}

# ---- rule pack
if (-not $Rules) { $Rules = $env:FIXMYVIBE_RULES }
if (-not $Rules) { $Rules = Join-Path $PSScriptRoot 'rules.conf' }
if (-not (Test-Path -LiteralPath $Rules -PathType Leaf)) { Stop-Audit "rule pack not found: $Rules" }

function Convert-Pattern([string]$Pattern) {
  # POSIX ERE to .NET, keeping every construct inside one line so whole-file matching equals grep.
  $p = $Pattern.Replace('[:space:]', ' \t').Replace('[:alnum:]', 'A-Za-z0-9').Replace('[:digit:]', '0-9')
  $p = $p.Replace('[:alpha:]', 'A-Za-z').Replace('[:upper:]', 'A-Z').Replace('[:lower:]', 'a-z')
  return [regex]::Replace($p, '(?<!\\)\[\^([^\]]*)\]', '[^\n$1]')
}

$groups = @{}
$ruleList = New-Object System.Collections.Generic.List[object]
$section = ''; $current = $null
foreach ($raw in [System.IO.File]::ReadAllLines($Rules, [System.Text.Encoding]::UTF8)) {
  $line = $raw.TrimEnd("`r")
  if ($line -eq '' -or $line.StartsWith('#')) { continue }
  if ($line.StartsWith('[') -and $line.EndsWith(']')) {
    $section = $line.Substring(1, $line.Length - 2)
    if ($section -ne 'groups') {
      $current = @{ Id = $section; Sev = 'warning'; Case = 's'; Scope = 'any'; Match = ''; Unless = ''; Msg = '' }
      $ruleList.Add($current)
    }
    continue
  }
  $at = $line.IndexOf(' = ')
  if ($at -lt 1) { Stop-Audit "rule pack: cannot parse line: $line" }
  $key = $line.Substring(0, $at); $val = $line.Substring($at + 3)
  if ($section -eq 'groups') { $groups[$key] = $val; continue }
  switch ($key) {
    'sev' { $current.Sev = $val } 'case' { $current.Case = $val } 'scope' { $current.Scope = $val }
    'match' { $current.Match = $val } 'unless' { $current.Unless = $val } 'msg' { $current.Msg = $val }
    default { Stop-Audit "rule $($current.Id): unknown key $key" }
  }
}
if ($ruleList.Count -eq 0) { Stop-Audit 'rule pack is empty' }

# ---- project gate config: .fixmyvibeignore holds path globs and "rule:ID" lines
if (Test-Path -LiteralPath '.fixmyvibeignore' -PathType Leaf) {
  foreach ($raw in [System.IO.File]::ReadAllLines((Resolve-Path -LiteralPath '.fixmyvibeignore').Path)) {
    $line = ($raw -replace '#.*$', '').Trim()
    if (-not $line) { continue }
    if ($line.StartsWith('rule:')) { $script:disabled[$line.Substring(5)] = $true }
    else { $script:ignore += ($line -replace '^\./', '') }
  }
}

$timeout = [TimeSpan]::FromSeconds(10)
$pack = New-Object System.Collections.Generic.List[object]   # not $rules: PowerShell names ignore case, and -Rules is the parameter
foreach ($r in $ruleList) {
  if (-not $r.Match) { Stop-Audit "rule $($r.Id) has no match pattern" }
  if ($script:disabled.ContainsKey($r.Id)) { continue }
  $opts = [System.Text.RegularExpressions.RegexOptions]'CultureInvariant, Multiline'
  if ($r.Case -eq 'i') { $opts = $opts -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }
  $exts = $null
  if ((' ' + $r.Scope + ' ') -notmatch ' any ') {
    $exts = @{}
    foreach ($tok in ($r.Scope -split '\s+')) {
      if (-not $tok) { continue }
      $list = if ($groups.ContainsKey($tok)) { $groups[$tok] } else { $tok }
      foreach ($e in ($list -split '\s+')) { if ($e) { $exts[$e.ToLowerInvariant()] = $true } }
    }
  }
  $pack.Add([pscustomobject]@{ Id = $r.Id; Sev = $r.Sev; Regex = $null; Unless = $null; Exts = $exts; Msg = $r.Msg; Opts = $opts; Match = $r.Match; UnlessText = $r.Unless })
}

function Add-Finding([string]$Sev, [string]$Id, [string]$Path, [int]$Line, [string]$Msg, [string]$Text) {
  $script:findings.Add([pscustomobject]@{ ruleId = $Id; severity = $Sev; path = $Path; line = $Line; message = $Msg; excerpt = $Text })
}

function Test-Skipped([string]$Path) {
  $p = ($Path -replace '\\', '/') -replace '^\./', ''
  $q = '/' + $p
  foreach ($d in '/.git/', '/node_modules/', '/dist/', '/build/', '/.next/', '/coverage/', '/vendor/', '/target/', '/obj/', '/__pycache__/', '/.venv/') {
    if ($q.IndexOf($d, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
  }
  if ($q -match '(?i)(\.min\.js|\.min\.css|\.map|\.lock|\.snap|\.svg|/package-lock\.json|/pnpm-lock\.yaml|/go\.sum)$') { return $true }
  if ($q -match '(?i)\.(png|jpg|jpeg|gif|webp|ico|pdf|zip|gz|woff|woff2|ttf|mp4|mp3|exe|dll)$') { return $true }
  if (-not $env:FIXMYVIBE_SCAN_SELF) {   # this skill's own files, and any other installed copy
    if ($q.IndexOf('/skills/fixmyvibe/', [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
    $abs = if ([System.IO.Path]::IsPathRooted($p)) { $p } else { ((Get-Location).Path -replace '\\', '/').TrimEnd('/') + '/' + $p }
    if ($abs.StartsWith($skillDir, [StringComparison]::OrdinalIgnoreCase)) { return $true }
  }
  foreach ($pat in $script:ignore) {
    if ($p -like $pat -or $p -like "*/$pat" -or $p -like "$pat/*" -or $p -like "*/$pat/*") { return $true }
  }
  return $false
}

function Test-FileLevel([string]$Path, [bool]$FromGit) {
  $base = ($Path -replace '\\', '/').Split('/')[-1]
  if ($base -eq '.fixmyvibeignore' -and $script:mode -ne 'files') {
    Add-Finding 'warning' 'GATE001' $Path 1 'gate configuration changed: a person should review what is now ignored' ''
  }
  if (-not $FromGit) { return }
  if ($base -match '(?i)^\.env\.(example|sample|template|dist|defaults|schema)$' -or $base -match '(?i)^\.env\..*\.example$') { return }
  if ($base -match '(?i)^\.env(\..*)?$' -and -not $script:disabled.ContainsKey('SEC006')) {
    Add-Finding 'blocker' 'SEC006' $Path 1 'env file is not gitignored: ignore it, and rotate anything it already exposed' ''
  }
}

function New-Unit([string]$Path) {
  return [pscustomobject]@{ Path = $Path; Lines = (New-Object System.Collections.Generic.List[string]); Nums = (New-Object System.Collections.Generic.List[int]) }
}
function Add-Line($Unit, [int]$Num, [string]$Text) {   # diff lines only; whole files are read in bulk below
  $s = $Text.TrimEnd("`r"); if ($s.Length -gt 2000) { $s = $s.Substring(0, 2000) }
  $Unit.Lines.Add($s); $Unit.Nums.Add($Num)
}

function Read-FileUnit([string]$Display, [string]$FullPath) {
  $info = New-Object System.IO.FileInfo($FullPath)
  if ($info.Length -eq 0) { return }
  $stream = [System.IO.File]::OpenRead($FullPath)
  try {
    $head = New-Object byte[] 8000
    $got = $stream.Read($head, 0, $head.Length)
    if ([Array]::IndexOf($head, [byte]0, 0, $got) -ge 0) { return }   # binary
    $stream.Position = 0
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true)
    $unit = New-Unit $Display
    if ($info.Length -le 2097152) {
      # No PowerShell code per line here: a function call per line made a 200-file scan take 14s.
      $all = $reader.ReadToEnd().Replace("`r`n", "`n").Replace("`r", "`n")
      if ($all.EndsWith("`n")) { $all = $all.Substring(0, $all.Length - 1) }
      $lines = $all.Split("`n")
      for ($i = 0; $i -lt $lines.Length; $i++) { if ($lines[$i].Length -gt 2000) { $lines[$i] = $lines[$i].Substring(0, 2000) } }
      $unit.Lines.AddRange([string[]]$lines)
      $unit.Nums.AddRange([int[]](1..$lines.Length))
    } else {
      $bytes = 0; $n = 0
      while ($null -ne ($line = $reader.ReadLine())) {
        $n++; $bytes += $line.Length + 1
        if ($bytes -gt 2097152) { break }
        Add-Line $unit $n $line
      }
      $script:truncated++
    }
    $script:units.Add($unit); $script:scanned++; $script:chars += $info.Length
  } finally { $stream.Dispose() }
}

function Add-Files([string[]]$Files, [bool]$FromGit) {
  foreach ($f in $Files) {
    if (-not $f) { continue }
    $display = ($f -replace '\\', '/') -replace '^\./', ''
    if (-not [System.IO.File]::Exists($f)) { continue }   # .NET calls: the path cmdlets cost milliseconds per file
    if (Test-Skipped $display) { $script:skipped++; continue }
    Test-FileLevel $display $FromGit
    try { Read-FileUnit $display ([System.IO.Path]::GetFullPath($f)) } catch { $script:scanErrors.Add("$display - $($_.Exception.Message)") }
  }
}

function Get-TargetFiles([string]$Target, [bool]$FromGit) {
  $t = $Target.TrimEnd('/', '\'); if (-not $t) { $t = '/' }
  if (Test-Path -LiteralPath $t -PathType Leaf) { return @($t) }
  if ($FromGit) {
    & git -C $t check-ignore -q . 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
      $out = (& git -C $t -c core.quotepath=false ls-files -z --cached --others --exclude-standard 2>$null) -join "`n"
      return @($out.Split([char]0) | Where-Object { $_ } | ForEach-Object { "$t/$_" })
    }
  }
  $root = (Resolve-Path -LiteralPath $t).ProviderPath.TrimEnd('\', '/')
  return @(Get-ChildItem -LiteralPath $t -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notlike '.env*' -and $_.FullName -notmatch '[\\/](\.git|node_modules)[\\/]' } |
    ForEach-Object { $t + '/' + ($_.FullName.Substring($root.Length).TrimStart('\', '/') -replace '\\', '/') })
}

function Add-Diff([string[]]$DiffArgs) {
  $diff = @(& git diff --no-color --no-ext-diff --unified=0 --relative --src-prefix=a/ --dst-prefix=b/ --diff-filter=ACMR @DiffArgs 2>$null)
  if ($LASTEXITCODE -ne 0) { Stop-Audit 'git diff failed' }
  $unit = $null; $ln = 0; $inHunk = $false
  foreach ($line in $diff) {
    if ($line.StartsWith('diff --git ')) { $unit = $null; $inHunk = $false; continue }
    if ($line.StartsWith('+++ ')) {
      $unit = $null; $inHunk = $false
      if ($line.StartsWith('+++ b/')) {
        $path = $line.Substring(6).TrimEnd("`t")
        Test-FileLevel $path $true
        $unit = New-Unit $path; $script:units.Add($unit)
      }
      continue
    }
    if ($line.StartsWith('@@ ')) {
      if ($unit -and $line -match '^@@ -\S+ \+(\d+)') { $ln = [int]$Matches[1]; $inHunk = $true }
      continue
    }
    if (-not $inHunk) { continue }
    if ($line.StartsWith('+')) { Add-Line $unit $ln $line.Substring(1); $ln++; $script:scanned++ }
    elseif ($line.StartsWith(' ')) { $ln++ }
  }
}

# ---- collect the lines to scan
$unitName = 'files'
if ($script:mode -eq 'files') {
  if (-not $Paths) { $Paths = @('.') }
  foreach ($t in $Paths) { if (-not (Test-Path -LiteralPath $t)) { Stop-Audit "path does not exist: $t" } }
  foreach ($t in $Paths) {
    $fromGit = $false
    if (Test-Path -LiteralPath $t -PathType Container) { & git -C $t rev-parse --is-inside-work-tree 2>$null | Out-Null; $fromGit = ($LASTEXITCODE -eq 0) }
    Add-Files (Get-TargetFiles $t $fromGit) $fromGit
  }
} else {
  if (-not (Test-Git)) { Stop-Audit "--$($script:mode) requires a Git worktree" }
  $unitName = 'added lines'
  $spec = @(); if ($Paths) { $spec = @('--') + $Paths }
  if ($script:mode -eq 'staged') { Add-Diff (@('--cached') + $spec) }
  else {
    $base = 'HEAD'
    if ($script:mode -eq 'since') {
      $found = @(& git merge-base $Since HEAD 2>$null)   # no Select-Object -First: it ends the pipeline before git sets its exit code
      if ($LASTEXITCODE -ne 0 -or $found.Count -eq 0) { Stop-Audit "cannot find a merge base with $Since" }
      $base = $found[0]
    }
    & git rev-parse -q --verify "$base^{commit}" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
      Add-Diff (@($base) + $spec)
      $lines = $script:scanned; $script:scanned = 0
      $out = (& git -c core.quotepath=false ls-files -z --others --exclude-standard @spec 2>$null) -join "`n"
      Add-Files @($out.Split([char]0) | Where-Object { $_ }) $true
      if ($script:scanned -gt 0) { $unitName = "added lines, plus $($script:scanned) new files" }
      $script:scanned += $lines
    } else {
      $unitName = 'files (no commit yet)'; Add-Files (Get-TargetFiles '.' $true) $true
    }
  }
}

# ---- match
# Compiling a regex costs tens of milliseconds and then runs faster, so it pays only on a large
# scan. A hook call on a small diff stays interpreted.
# ponytail: .NET runs these patterns at a few MB/s per rule, so a full scan is about 3x slower than
# the shell engine (grep). Diff modes are unaffected. A per-rule literal prefilter is the upgrade.
$compiled = if ($script:chars -gt 300000) { [System.Text.RegularExpressions.RegexOptions]::Compiled } else { [System.Text.RegularExpressions.RegexOptions]::None }
foreach ($rule in $pack.ToArray()) {   # ToArray, not @(): PowerShell 5.1 cannot wrap a generic List that way
  try {
    $rule.Regex = New-Object System.Text.RegularExpressions.Regex((Convert-Pattern $rule.Match), ($rule.Opts -bor $compiled), $timeout)
    if ($rule.UnlessText) { $rule.Unless = New-Object System.Text.RegularExpressions.Regex((Convert-Pattern $rule.UnlessText), $rule.Opts, $timeout) }
  } catch { $script:scanErrors.Add("rule $($rule.Id): invalid pattern"); [void]$pack.Remove($rule) }
}
# An empty block spread over two lines is joined so one-line rules can see it (same as the awk emit).
$joinRe = New-Object System.Text.RegularExpressions.Regex('[{:][ \t]*\n[ \t]*(?:\}[);,]*|pass|\.\.\.)[ \t]*(?=\n|\z)')
function Get-Starts($Lines) {
  $starts = New-Object int[] $Lines.Count; $pos = 0
  for ($i = 0; $i -lt $Lines.Count; $i++) { $starts[$i] = $pos; $pos += $Lines[$i].Length + 1 }
  return , $starts
}
function Find-Line([int[]]$Starts, [int]$Index) {
  $at = [Array]::BinarySearch($Starts, $Index)
  if ($at -lt 0) { $at = (-bnot $at) - 1 }
  return $at
}

$seen = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($unit in $script:units) {
  if ($unit.Lines.Count -eq 0) { continue }
  if ($script:mode -ne 'files' -and (Test-Skipped $unit.Path)) { continue }
  $base = $unit.Path.Split('/')[-1]
  $ext = if ($base -like '.env*') { 'env' } elseif ($base.Contains('.')) { $base.Substring($base.LastIndexOf('.') + 1) } else { $base }
  $ext = $ext.ToLowerInvariant()
  $text = [string]::Join("`n", $unit.Lines)
  $joins = $joinRe.Matches($text)
  if ($joins.Count -gt 0) {
    $starts = Get-Starts $unit.Lines
    foreach ($m in $joins) {
      $i = Find-Line $starts $m.Index
      if ($i + 1 -ge $unit.Nums.Count -or $unit.Nums[$i + 1] -ne $unit.Nums[$i] + 1) { continue }
      $unit.Lines.Add($unit.Lines[$i] + ' ' + $unit.Lines[$i + 1].Trim(' ', "`t")); $unit.Nums.Add($unit.Nums[$i])
    }
    $text = [string]::Join("`n", $unit.Lines)
  }
  $starts = $null
  foreach ($rule in $pack) {
    if ($rule.Exts -and -not $rule.Exts.ContainsKey($ext)) { continue }
    try {
      $found = $rule.Regex.Matches($text)
      if ($found.Count -eq 0) { continue }
      if ($null -eq $starts) { $starts = Get-Starts $unit.Lines }
      $last = -1
      foreach ($m in $found) {
        $at = Find-Line $starts $m.Index
        if ($at -eq $last) { continue }
        $last = $at
        $line = $unit.Lines[$at]
        if ($rule.Unless -and $rule.Unless.IsMatch($line)) { continue }
        $key = "$($rule.Id) $($unit.Path):$($unit.Nums[$at])"   # several patterns share an id; report a line once per id
        if (-not $seen.Add($key)) { continue }
        $shown = if ($rule.Id -like 'SEC0[01]*') { '(excerpt withheld so the secret is not copied into logs)' }
                 elseif ($line.Length -gt 200) { $line.Substring(0, 200).Trim() } else { $line.Trim() }
        if ($line -match ('(?i)fixmyvibe:\s*allow\s+' + [regex]::Escape($rule.Id) + '\s+\S')) {
          $script:suppressions.Add([pscustomobject]@{ ruleId = $rule.Id; path = $unit.Path; line = $unit.Nums[$at]; excerpt = $shown })
          continue
        }
        Add-Finding $rule.Sev $rule.Id $unit.Path $unit.Nums[$at] $rule.Msg $shown
      }
    } catch { $script:scanErrors.Add("rule $($rule.Id) on $($unit.Path): $($_.Exception.Message)") }
  }
}

# ---- report
$blockers = @($script:findings | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($script:findings | Where-Object { $_.severity -eq 'warning' }).Count
$code = if ($script:scanErrors.Count -gt 0) { 2 } elseif ($blockers -gt 0 -or ($StrictWarnings -and $warnings -gt 0)) { 1 } else { 0 }

if ($Format -eq 'Json') {
  [pscustomobject]@{
    version = 3; mode = $script:mode; scanned = $script:scanned; unit = $unitName
    blockerCount = $blockers; warningCount = $warnings; suppressionCount = $script:suppressions.Count
    skippedCount = $script:skipped; truncatedCount = $script:truncated; secure = $null; exitCode = $code
    scanErrors = $script:scanErrors.ToArray(); findings = $script:findings.ToArray(); suppressions = $script:suppressions.ToArray()
  } | ConvertTo-Json -Depth 5
  exit $code
}

function Get-Report {
  "== FixMyVibe audit: $($script:scanned) $unitName =="
  foreach ($sev in 'blocker', 'warning') {
    if ($sev -eq 'warning' -and $Hook) { continue }
    $label = if ($sev -eq 'blocker') { 'BLOCKER' } else { 'WARNING' }
    $seen = @{}
    foreach ($f in $script:findings) {
      if ($f.severity -ne $sev -or $seen.ContainsKey($f.ruleId)) { continue }
      $seen[$f.ruleId] = $true
      $same = @($script:findings | Where-Object { $_.ruleId -eq $f.ruleId -and $_.severity -eq $sev })
      foreach ($g in ($same | Select-Object -First 10)) {
        '{0} {1} {2}:{3}  {4}' -f $label, $g.ruleId, $g.path, $g.line, $g.message
        if ($g.excerpt) { '        ' + $g.excerpt }
      }
      if ($same.Count -gt 10) { '        ... and {0} more {1} (use -Format Json for the full list)' -f ($same.Count - 10), $f.ruleId }
    }
  }
  foreach ($s in $script:suppressions) { 'ALLOW   {0} {1}:{2}' -f $s.ruleId, $s.path, $s.line }
  foreach ($e in $script:scanErrors) { 'ERROR   ' + $e }
  if ($script:skipped -gt 0 -or $script:truncated -gt 0) { 'NOTE    {0} files skipped by ignore rules, {1} files cut off at 2MB' -f $script:skipped, $script:truncated }
  if ($script:disabled.Count -gt 0) { 'NOTE    rules disabled in .fixmyvibeignore: ' + (($script:disabled.Keys | Sort-Object) -join ' ') }
  '----------------------------------------'
  $ns = $script:suppressions.Count
  if ($script:scanErrors.Count -gt 0) { 'ERROR: the scan did not complete. Treat this as a failed gate.' }
  elseif ($blockers -gt 0) { "FAIL: $blockers blocker(s), $warnings warning(s), $ns suppression(s). Fix the blockers, then run the audit again." }
  elseif ($StrictWarnings -and $warnings -gt 0) { "FAIL (strict): $warnings warning(s) need a fix or a recorded reason." }
  elseif ($script:scanned -eq 0) { 'NOTHING SCANNED: no matching files or added lines. This is not a pass.' }
  elseif ($warnings -gt 0) { "PASS WITH REVIEW: 0 blockers, $warnings warning(s), $ns suppression(s). Fix each warning or state why it stays." }
  else { "PASS: no heuristic findings, $ns suppression(s). This is not proof of security." }
}

if ($Hook) {
  if ($code -eq 2) { Get-Report | ForEach-Object { [Console]::Error.WriteLine($_) }; exit 1 }
  if ($blockers -eq 0) { exit 0 }
  Get-Report | ForEach-Object { [Console]::Error.WriteLine($_) }
  [Console]::Error.WriteLine('FixMyVibe gate: fix these blockers before finishing. If one is a false positive, add "fixmyvibe: allow RULE-ID reason" on that line.')
  exit 2
}
Get-Report
exit $code
