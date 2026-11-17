<#
  Tests for the PowerShell audit: corpus accuracy, parity with the shell engine, and behavior.
  No test framework needed. Works on Windows PowerShell 5.1 and PowerShell 7.
    powershell -NoProfile -ExecutionPolicy Bypass -File tests/run.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
$audit = Join-Path $root 'skills/fixmyvibe/bin/fixmyvibe-audit.ps1'
$corpus = Join-Path $root 'tests/corpus.txt'
$T = Join-Path $root 'tmp/audit-ps-tests'
$shell = (Get-Process -Id $PID).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)
$script:passes = 0; $script:failures = 0; $script:status = 0; $script:output = ''

if (-not ([System.IO.Path]::GetFullPath($T)).StartsWith([System.IO.Path]::GetFullPath((Join-Path $root 'tmp')), [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe cleanup path.' }
if (Test-Path -LiteralPath $T) { Remove-Item -LiteralPath $T -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $T 'corpus') -Force | Out-Null

function Ok([string]$Name) { $script:passes++; Write-Host "PASS $Name" }
function Fail([string]$Name, [string]$Detail = '') { $script:failures++; Write-Host "FAIL $Name" -ForegroundColor Red; if ($Detail) { Write-Host $Detail } }
function Put([string]$Path, [string]$Content) { [System.IO.File]::WriteAllText($Path, $Content, $utf8) }
function Run([string]$Cwd, [string[]]$AuditArgs, [string]$Stdin = $null) {
  Push-Location -LiteralPath $Cwd
  try {
    if ($null -ne $Stdin) { $script:output = ($Stdin | & $shell -NoProfile -ExecutionPolicy Bypass -File $audit @AuditArgs 2>&1 | Out-String) }
    else { $script:output = (& $shell -NoProfile -ExecutionPolicy Bypass -File $audit @AuditArgs 2>&1 | Out-String) }
    $script:status = $LASTEXITCODE
  } finally { Pop-Location }
}
function Expect-Status([int]$Want, [string]$Name) { if ($script:status -eq $Want) { Ok $Name } else { Fail "$Name (expected exit $Want, got $($script:status))" $script:output } }
function Expect-Output([string]$Needle, [string]$Name) { if ($script:output.Contains($Needle)) { Ok $Name } else { Fail "$Name (missing: $Needle)" $script:output } }
function Refute-Output([string]$Needle, [string]$Name) { if (-not $script:output.Contains($Needle)) { Ok $Name } else { Fail "$Name (unexpected: $Needle)" $script:output } }

try {
  # ---- corpus accuracy
  $hits = @{}; $misses = @{}; $rowText = @{}; $row = 0
  foreach ($line in [System.IO.File]::ReadAllLines($corpus, [System.Text.Encoding]::UTF8)) {
    if ($line -notmatch '^(hit|miss)\s*\|') { continue }
    $row++; $num = '{0:d3}' -f $row
    $parts = $line.Split([char[]]'|', 4)
    $exp = $parts[0].Trim(); $id = $parts[1].Trim(); $ext = $parts[2].Trim()
    $content = $parts[3]; if ($content.StartsWith(' ')) { $content = $content.Substring(1) }
    $content = $content.Replace('{+}', '').Replace('\n', "`n")
    Put (Join-Path $T "corpus/$num.$ext") ($content + "`n")
    $rowText["$id $num"] = $content
    if ($exp -eq 'hit') { $hits["$id $num"] = $true } else { $misses["$id $num"] = $true }
  }
  Run $root @('-Format', 'Json', (Join-Path $T 'corpus'))
  if ($script:status -ne 2) { Ok 'corpus scan completes' } else { Fail 'corpus scan did not complete' $script:output }
  $json = $script:output | ConvertFrom-Json
  $got = @{}
  foreach ($f in $json.findings) { if ($f.path -match '/(\d+)\.[A-Za-z]+$') { $got["$($f.ruleId) $($Matches[1])"] = $true } }
  $missed = @($hits.Keys | Where-Object { -not $got.ContainsKey($_) } | Sort-Object)
  $falsePos = @($misses.Keys | Where-Object { $got.ContainsKey($_) } | Sort-Object)
  if ($missed.Count -eq 0) { Ok "corpus: all $($hits.Count) hit rows fire" } else { Fail 'corpus: rule did not fire on a hit row' (($missed | ForEach-Object { "  ${_}: $($rowText[$_])" }) -join "`n") }
  if ($falsePos.Count -eq 0) { Ok "corpus: all $($misses.Count) miss rows stay quiet" } else { Fail 'corpus: rule fired on a miss row' (($falsePos | ForEach-Object { "  ${_}: $($rowText[$_])" }) -join "`n") }

  # ---- parity: every finding on the corpus, labeled or not, must match the shell engine
  $mine = @($got.Keys | Sort-Object -CaseSensitive)
  [System.IO.File]::WriteAllLines((Join-Path $root 'tmp/corpus-got-ps.txt'), [string[]]$mine, $utf8)
  $shFile = Join-Path $root 'tmp/corpus-got-sh.txt'
  if (Test-Path -LiteralPath $shFile) {
    $theirs = @([System.IO.File]::ReadAllLines($shFile) | Where-Object { $_ })
    $diff = @(Compare-Object $theirs $mine)
    if ($diff.Count -eq 0) { Ok "parity: both engines report the same $($mine.Count) findings on the corpus" }
    else { Fail 'parity: engines disagree on the corpus' (($diff | ForEach-Object { "  $($_.SideIndicator) $($_.InputObject): $($rowText[$_.InputObject])" }) -join "`n") }
  } else { Write-Host 'SKIP parity (run tests/run.sh first to produce tmp/corpus-got-sh.txt)' }

  # ---- behavior
  $F = Join-Path $T 'behavior'; New-Item -ItemType Directory -Path $F | Out-Null
  Put "$F/clean sample.txt" "api_key = `"replace_me`"`n"
  Run $root @("$F/clean sample.txt"); Expect-Status 0 'placeholder exits clean'

  Put "$F/secret.txt" "API_KEY = `"real-looking-value-123`"`n"
  Run $root @("$F/secret.txt")
  Expect-Status 1 'hardcoded secret blocks'; Expect-Output 'SEC003' 'finding carries a stable rule id'
  Refute-Output 'real-looking-value-123' 'secret value is not echoed into the report'
  Run $root @('-Format', 'Json', "$F/secret.txt")
  $j = $script:output | ConvertFrom-Json
  if ($null -eq $j.secure -and $j.blockerCount -eq 1) { Ok 'JSON reports the blocker and refuses to claim security' } else { Fail 'JSON shape' $script:output }

  Put "$F/styles.css" ".button { outline: none; }`n"
  Run $root @("$F/styles.css"); Expect-Status 0 'warning passes by default'; Expect-Output 'PASS WITH REVIEW' 'warning asks for review'
  Run $root @('-StrictWarnings', "$F/styles.css"); Expect-Status 1 'strict mode fails on a warning'

  Put "$F/reviewed.js" "node.innerHTML = trustedHtml; // fixmyvibe: allow SEC201 sanitized-by-dompurify`n"
  Run $root @("$F/reviewed.js"); Expect-Status 0 'reasoned suppression passes'; Expect-Output 'ALLOW   SEC201' 'suppression stays visible'
  Put "$F/noreason.js" "node.innerHTML = trustedHtml; // fixmyvibe: allow SEC201`n"
  Run $root @('-StrictWarnings', "$F/noreason.js"); Expect-Status 1 'suppression without a reason is ignored'

  Run $root @("$F/missing.txt"); Expect-Status 2 'missing target fails closed'
  Run $root @('-Rules', "$F/missing.conf", $F); Expect-Status 2 'missing rule pack fails closed'
  Put "$F/bad.conf" "[BAD1]`nsev = blocker`nmatch = (unclosed`nmsg = broken`n"
  Run $root @('-Rules', "$F/bad.conf", "$F/styles.css"); Expect-Status 2 'broken rule pattern fails closed'

  Put "$F/crlf.js" "const a = 1;`r`ntry { go(); } catch (e) {`r`n}`r`n"
  Run $root @("$F/crlf.js"); Expect-Status 1 'CRLF file: empty catch across two lines blocks'; Expect-Output 'crlf.js:2' 'two-line finding reports the opening line'

  Put "$F/notes.md" "# Notes`n`nNever call ``eval(userInput)`` or build `"SELECT * FROM t WHERE id = `" + id in code.`n"
  Run $root @("$F/notes.md"); Expect-Status 0 'code rules do not fire on prose files'

  Put "$F/huge.txt" (('a' * 3000000) + "`n")
  Run $root @("$F/huge.txt"); Expect-Status 0 'oversized file does not break the scan'

  # git-aware modes
  $G = Join-Path $T 'repo'; New-Item -ItemType Directory -Path "$G/src" -Force | Out-Null
  & git -C $G init --quiet; & git -C $G config user.email 'tests@example.invalid'; & git -C $G config user.name 'FixMyVibe Tests'
  & git -C $G config core.autocrlf false
  Put "$G/src/legacy.py" "password = `"old-legacy-value-99`"`n"
  Put "$G/.gitignore" "node_modules/`nsecret-notes.txt`n"
  Put "$G/secret-notes.txt" "token = `"ignored-real-value-77`"`n"
  & git -C $G add -A; & git -C $G commit --quiet -m baseline

  Run $G @('-Staged'); Expect-Status 0 'staged: nothing staged is not a failure'; Expect-Output 'NOTHING SCANNED' 'staged: empty scan is not reported as a pass'
  Run $G @('-Changed'); Expect-Status 0 'changed: clean tree exits 0'
  Run $G @('.'); Expect-Status 1 'full scan sees the legacy secret'; Refute-Output 'secret-notes.txt' 'full scan honors .gitignore'

  [System.IO.File]::AppendAllText("$G/src/legacy.py", "safe = True`n", $utf8)
  Run $G @('-Changed'); Expect-Status 0 'changed: legacy lines are not rescanned'; Expect-Output 'added lines' 'changed: scope is stated'
  [System.IO.File]::AppendAllText("$G/src/legacy.py", "token = `"brand-new-value-4242`"`n", $utf8)
  Run $G @('-Changed'); Expect-Status 1 'changed: new unstaged secret blocks'; Expect-Output 'src/legacy.py:3' 'changed: line number is the new file line'
  Run $G @('-Staged'); Expect-Status 0 'staged: unstaged change is out of scope'
  & git -C $G add -A
  Run $G @('-Staged'); Expect-Status 1 'staged: staged secret blocks'
  & git -C $G commit --quiet -m second
  Run $G @('-Since', 'HEAD~1'); Expect-Status 1 'since: finds the secret added after the base'
  Run $G @('-Changed'); Expect-Status 0 'changed: committed work is out of scope'

  Put "$G/src/new file.js" "const q = eval(input);`n"
  Run $G @('-Changed'); Expect-Status 1 'changed: untracked file is scanned'; Expect-Output 'new file.js:1' 'changed: path with a space is reported'
  Remove-Item -LiteralPath "$G/src/new file.js"

  Put "$G/.env" "API_KEY=abc`n"
  Run $G @('-Changed'); Expect-Status 1 'env file that is not ignored blocks'; Expect-Output 'SEC006' 'env finding has its id'
  [System.IO.File]::AppendAllText("$G/.gitignore", ".env`n", $utf8)
  Run $G @('-Changed'); Expect-Status 0 'ignored env file passes'

  Put "$G/.fixmyvibeignore" "src/legacy.py`nrule:COPY005`n"
  Run $G @('.'); Expect-Status 0 'ignore file removes a path from the scan'; Expect-Output 'COPY005' 'disabled rules are listed'
  Run $G @('-Changed'); Expect-Output 'GATE001' 'changing the gate config is flagged for review'
  Remove-Item -LiteralPath "$G/.fixmyvibeignore"

  # hook mode
  [System.IO.File]::AppendAllText("$G/src/legacy.py", "os.system(`"rm `" + name)`n", $utf8)
  Run $G @('-Hook', 'stop') '{"hook_event_name":"Stop","stop_hook_active":false}'; Expect-Status 2 'stop hook blocks on a new blocker'; Expect-Output 'SEC104' 'stop hook reports the finding'
  Run $G @('-Hook', 'stop') '{"hook_event_name":"Stop","stop_hook_active":true}'; Expect-Status 0 'stop hook never blocks twice in a row'
  Run $G @('-Hook', 'edit') '{"tool_input":{"file_path":"src/legacy.py"}}'; Expect-Status 2 'edit hook blocks on the edited file'
  & git -C $G checkout --quiet -- src/legacy.py
  Put "$G/src/card.css" ".card { outline: none; }`n"
  Run $G @('-Hook', 'edit') '{"tool_input":{"file_path":"src/card.css"}}'; Expect-Status 0 'edit hook stays quiet on warnings'
  Run $G @('-Hook', 'edit') '{"tool_input":{"command":"ls"}}'; Expect-Status 0 'edit hook ignores events without a file'
  Run $T @('-Hook', 'stop') '{}'; Expect-Status 0 'stop hook outside a repository does nothing'
} finally {
  if (Test-Path -LiteralPath $T) { Remove-Item -LiteralPath $T -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host '----------------------------------------'
if ($script:failures -gt 0) { Write-Host "$($script:failures) failed, $($script:passes) passed."; exit 1 }
Write-Host "All PowerShell audit tests passed ($($script:passes) assertions)."
