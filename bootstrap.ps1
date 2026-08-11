<#
  FixMyVibe one-line bootstrap (Windows / PowerShell).  ASCII-only on purpose (PS 5.1 reads as ANSI).

  Install into every detected agent:
    irm https://raw.githubusercontent.com/AnasNafees1802/FixMyVibe/main/bootstrap.ps1 | iex

  Force all three agents (create dirs even if not detected):
    $env:FIXMYVIBE_ALL='1'; irm https://raw.githubusercontent.com/AnasNafees1802/FixMyVibe/main/bootstrap.ps1 | iex

  It downloads the repo to a temp folder, runs skills/fixmyvibe/install.ps1, then cleans up.
#>
$ErrorActionPreference = 'Stop'
$Repo   = 'https://github.com/AnasNafees1802/FixMyVibe.git'
$Branch = if ($env:FIXMYVIBE_BRANCH) { $env:FIXMYVIBE_BRANCH } else { 'main' }
$Tmp    = Join-Path $env:TEMP ('fixmyvibe-' + [guid]::NewGuid().ToString('N').Substring(0,8))

Write-Host '== FixMyVibe bootstrap ==' -ForegroundColor Cyan
try {
  if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Host "Cloning $Repo ($Branch) ..."
    # git writes normal progress to stderr; under -EA Stop that would wrap as a terminating
    # error, so relax EA around the native call and check the real exit code instead.
    $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    git clone --depth 1 --branch $Branch $Repo $Tmp
    $code = $LASTEXITCODE
    $ErrorActionPreference = $eap
    if ($code -ne 0) { throw "git clone failed (exit $code)" }
    $root = $Tmp
  } else {
    Write-Host 'git not found - downloading zip ...'
    $zip = "$Tmp.zip"
    Invoke-WebRequest "https://codeload.github.com/AnasNafees1802/FixMyVibe/zip/refs/heads/$Branch" -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $Tmp -Force
    Remove-Item $zip -Force
    $root = Join-Path $Tmp "FixMyVibe-$Branch"
  }

  $installer = Join-Path $root 'skills/fixmyvibe/install.ps1'
  if (-not (Test-Path $installer)) { throw "installer not found at $installer" }

  $instArgs = @()
  if ($env:FIXMYVIBE_ALL -eq '1') { $instArgs += '-All' }
  & $installer @instArgs
}
finally {
  Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}
