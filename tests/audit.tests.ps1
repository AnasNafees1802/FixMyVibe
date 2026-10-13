<#
  Regression tests for the PowerShell audit. No external test framework required.
  Run: pwsh -NoProfile -File tests/audit.tests.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$audit = Join-Path $repoRoot 'skills/fixmyvibe/bin/fixmyvibe-audit.ps1'
$testRoot = Join-Path $repoRoot 'tmp/fixmyvibe-audit-tests'
$pwsh = Join-Path $PSHOME 'pwsh.exe'
if (-not (Test-Path -LiteralPath $pwsh)) { $pwsh = 'powershell.exe' }

function Assert-Equal($Expected, $Actual, [string]$Name) {
  if ($Expected -ne $Actual) { throw "$Name expected [$Expected], got [$Actual]." }
  Write-Host "PASS $Name" -ForegroundColor Green
}

function Assert-Contains([string]$Needle, [string]$Haystack, [string]$Name) {
  if (-not $Haystack.Contains($Needle)) { throw "$Name did not contain [$Needle]. Output: $Haystack" }
  Write-Host "PASS $Name" -ForegroundColor Green
}

function Run-Audit([string[]]$AuditArgs, [string]$WorkingDirectory = $repoRoot) {
  $old = Get-Location
  $oldErrorActionPreference = $ErrorActionPreference
  try {
    Set-Location -LiteralPath $WorkingDirectory
    # The failure-path fixtures deliberately make the child audit write to stderr and exit nonzero.
    # Capture that evidence without allowing the parent test harness to terminate early.
    $ErrorActionPreference = 'Continue'
    $output = & $pwsh -NoProfile -File $audit @AuditArgs 2>&1 | Out-String
    return [pscustomobject]@{ ExitCode=$LASTEXITCODE; Output=$output }
  } finally {
    $ErrorActionPreference = $oldErrorActionPreference
    Set-Location -LiteralPath $old
  }
}

if (Test-Path -LiteralPath $testRoot) {
  $resolved = [System.IO.Path]::GetFullPath($testRoot)
  $allowed = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'tmp'))
  if (-not $resolved.StartsWith($allowed, [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test cleanup path.' }
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
New-Item -ItemType Directory -Path $testRoot | Out-Null

try {
  $clean = Join-Path $testRoot 'clean sample.txt'
  Set-Content -LiteralPath $clean -Value @('api_key = "replace_me"','https://example.test/risk-management-framework-resources') -Encoding utf8
  $r = Run-Audit @('-Format','Json','-Paths',$clean)
  Assert-Equal 0 $r.ExitCode 'placeholder exits clean'
  $json = $r.Output | ConvertFrom-Json
  Assert-Equal 0 $json.blockerCount 'placeholder is not a blocker'
  Assert-Equal $null $json.secure 'JSON refuses to claim security'

  $secret = Join-Path $testRoot 'fixture.txt'
  Set-Content -LiteralPath $secret -Value 'API_KEY = "real-looking-production-value-123"' -Encoding utf8 # fixmyvibe: allow SEC003 scanner-fixture
  $r = Run-Audit @('-Format','Json','-Paths',$secret)
  Assert-Equal 1 $r.ExitCode 'hardcoded secret blocks'
  Assert-Contains 'SEC003' $r.Output 'hardcoded secret has stable rule ID'

  $warning = Join-Path $testRoot 'styles.css'
  Set-Content -LiteralPath $warning -Value '.button { outline: none; }' -Encoding utf8
  $r = Run-Audit @('-Paths',$warning)
  Assert-Equal 0 $r.ExitCode 'warning is reviewable by default'
  $r = Run-Audit @('-StrictWarnings','-Paths',$warning)
  Assert-Equal 1 $r.ExitCode 'strict warnings block'

  $suppressed = Join-Path $testRoot 'reviewed.tsx'
  Set-Content -LiteralPath $suppressed -Value 'node.innerHTML = trustedHtml; // fixmyvibe: allow SEC201 trusted-sanitized-renderer' -Encoding utf8
  $r = Run-Audit @('-Format','Json','-Paths',$suppressed)
  Assert-Equal 0 $r.ExitCode 'reviewed suppression exits clean'
  $json = $r.Output | ConvertFrom-Json
  Assert-Equal 1 $json.suppressionCount 'reviewed suppression stays visible'

  $r = Run-Audit @('-Paths',(Join-Path $testRoot 'missing.txt'))
  Assert-Equal 2 $r.ExitCode 'missing target fails closed'

  $gitRoot = Join-Path $testRoot 'staged repo'
  New-Item -ItemType Directory -Path $gitRoot | Out-Null
  & git -C $gitRoot init --quiet
  & git -C $gitRoot config user.email 'fixmyvibe-tests@example.invalid'
  & git -C $gitRoot config user.name 'FixMyVibe Tests'
  $tracked = Join-Path $gitRoot 'app.txt'
  Set-Content -LiteralPath $tracked -Value 'password = "old-real-looking-value"' -Encoding utf8 # fixmyvibe: allow SEC003 scanner-fixture
  & git -C $gitRoot add app.txt
  & git -C $gitRoot commit --quiet -m baseline
  Add-Content -LiteralPath $tracked -Value 'safe = true' -Encoding utf8
  & git -C $gitRoot add app.txt
  $r = Run-Audit @('-Staged','-Format','Json') $gitRoot
  Assert-Equal 0 $r.ExitCode 'staged mode ignores unchanged legacy lines'
  $json = $r.Output | ConvertFrom-Json
  Assert-Equal 'staged-added-lines' $json.mode 'staged mode declares scope'

  Add-Content -LiteralPath $tracked -Value 'token = "new-real-looking-secret-value"' -Encoding utf8 # fixmyvibe: allow SEC003 scanner-fixture
  & git -C $gitRoot add app.txt
  $r = Run-Audit @('-Staged','-Format','Json') $gitRoot
  Assert-Equal 1 $r.ExitCode 'staged mode catches newly added secret'
  Assert-Contains 'SEC003' $r.Output 'staged finding includes rule ID'

  Write-Host 'All PowerShell audit tests passed.' -ForegroundColor Cyan
} finally {
  if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
