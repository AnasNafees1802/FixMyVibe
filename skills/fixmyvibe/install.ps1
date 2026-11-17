<#
  install.ps1 - Install the FixMyVibe skill for the agents on this machine.
  ASCII-only on purpose: Windows PowerShell 5.1 reads .ps1 files in the system code page.

  Three locations cover every supported agent:
    claude       ~/.claude/skills/fixmyvibe          Claude Code (Cursor reads it too)
    agents       ~/.agents/skills/fixmyvibe          Codex, Cursor, Gemini CLI
    antigravity  ~/.gemini/config/skills/fixmyvibe   Antigravity

  Usage:
    ./install.ps1                    install into every location whose agent is detected
    ./install.ps1 -All               install into all three, creating folders
    ./install.ps1 -Claude -Agents    install into the named locations only
    ./install.ps1 -RemoveLegacy      also remove what older FixMyVibe installers left behind
    ./install.ps1 -HomeDir D:\tmp\h  use another home folder (for testing)

  Re-runnable: each run replaces the installed copy with this one.
#>
[CmdletBinding()]
param(
  [switch]$Claude,
  [Alias('Codex', 'Cursor', 'Gemini')][switch]$Agents,
  [switch]$Antigravity,
  [switch]$All,
  [switch]$RemoveLegacy,
  [string]$HomeDir = $HOME
)

$ErrorActionPreference = 'Stop'
$Src = $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $Src 'SKILL.md'))) { throw "SKILL.md not found next to the installer ($Src)." }

function Install-Skill([string]$Dest) {
  if (Test-Path -LiteralPath $Dest) {
    # Replace only a folder that is a FixMyVibe install, so a stale file from an older version cannot linger.
    $old = Join-Path $Dest 'SKILL.md'
    if (-not (Test-Path -LiteralPath $old) -or -not (Select-String -LiteralPath $old -Pattern '^name:\s*fixmyvibe\s*$' -Quiet)) {
      throw "$Dest exists and is not a FixMyVibe install. Move it away and run again."
    }
    Remove-Item -LiteralPath $Dest -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  Copy-Item -Path (Join-Path $Src '*') -Destination $Dest -Recurse -Force
}

$targets = @(
  @{ Name = 'claude'; On = $Claude; Dir = '.claude/skills/fixmyvibe'; Detect = @('.claude'); Use = '/fixmyvibe in Claude Code' },
  @{ Name = 'agents'; On = $Agents; Dir = '.agents/skills/fixmyvibe'; Detect = @('.codex', '.cursor', '.agents', '.gemini'); Use = '$fixmyvibe in Codex, /fixmyvibe in Cursor and Gemini CLI' },
  @{ Name = 'antigravity'; On = $Antigravity; Dir = '.gemini/config/skills/fixmyvibe'; Detect = @('.gemini/config', '.gemini/antigravity'); Use = '/fixmyvibe in Antigravity' }
)
$explicit = $Claude -or $Agents -or $Antigravity
$installed = @()

Write-Host "== FixMyVibe installer ==  (home: $HomeDir)"
foreach ($t in $targets) {
  $detected = $false
  foreach ($d in $t.Detect) { if (Test-Path -LiteralPath (Join-Path $HomeDir $d)) { $detected = $true } }
  $go = $All -or $t.On -or (-not $explicit -and $detected)
  if (-not $go) { Write-Host ("skip      {0,-12} (not detected)" -f $t.Name); continue }
  $dest = Join-Path $HomeDir $t.Dir
  Install-Skill $dest
  Write-Host ("installed {0,-12} {1}" -f $t.Name, $dest) -ForegroundColor Green
  $installed += $t.Use
}

# Older installers wrote to paths the agents no longer read, plus an always-on AGENTS.md block.
$legacy = @('.codex/skills/fixmyvibe', '.gemini/skills/fixmyvibe', '.antigravity/skills/fixmyvibe',
            '.claude/commands/fixmyvibe.md', '.codex/prompts/fixmyvibe.md', '.gemini/workflows/fixmyvibe.md', '.antigravity/workflows/fixmyvibe.md') |
  ForEach-Object { Join-Path $HomeDir $_ } | Where-Object { Test-Path -LiteralPath $_ }
$blockFiles = @('.codex/AGENTS.md', '.gemini/AGENTS.md') | ForEach-Object { Join-Path $HomeDir $_ } |
  Where-Object { (Test-Path -LiteralPath $_) -and (Select-String -LiteralPath $_ -SimpleMatch '<!-- fixmyvibe:managed -->' -Quiet) }
if ($legacy -or $blockFiles) {
  if ($RemoveLegacy) {
    foreach ($p in $legacy) { Remove-Item -LiteralPath $p -Recurse -Force; Write-Host "removed   $p" }
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    foreach ($f in $blockFiles) {
      $text = [System.IO.File]::ReadAllText($f)   # .NET read and write keep the file UTF-8 without a BOM
      $clean = [regex]::Replace($text, '(?s)\r?\n?<!-- fixmyvibe:managed -->.*?<!-- /fixmyvibe:managed -->\r?\n?', "`n")
      [System.IO.File]::WriteAllText($f, $clean, $utf8); Write-Host "cleaned   $f (removed the FixMyVibe block)"
    }
  } else {
    Write-Host 'Found files from an older FixMyVibe install that agents no longer read:' -ForegroundColor Yellow
    foreach ($p in @($legacy) + @($blockFiles)) { Write-Host "  $p" }
    Write-Host 'Run again with -RemoveLegacy to remove them.' -ForegroundColor Yellow
  }
}

Write-Host '----------------------------------------'
if ($installed.Count -eq 0) {
  Write-Host 'Nothing installed. No agent was detected. Run again with -All, or name a location.' -ForegroundColor Yellow
  exit 1
}
Write-Host 'Open a new agent session, then use:'
foreach ($u in $installed) { Write-Host "  $u" }
Write-Host 'To make the audit run after every edit and before the agent stops, see adapters/ in the installed folder.'
