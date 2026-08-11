<#
  install.ps1 - Install the FixMyVibe skill into Claude Code, Codex, and Antigravity,
  and register a /fixmyvibe slash command in each.  (ASCII-only on purpose: PS 5.1 reads .ps1 as ANSI.)

  Usage:
    ./install.ps1                 # auto: install into every agent detected on this machine
    ./install.ps1 -All            # install into all three even if not yet detected (creates dirs)
    ./install.ps1 -Claude -Codex  # install into the named agent(s) only
    ./install.ps1 -HomeDir D:\tmp\home   # override HOME (for testing)

  Re-runnable / idempotent: copies overwrite, the command file is rewritten, and the AGENTS.md
  block is inserted only once (guarded by a marker).
#>
[CmdletBinding()]
param(
  [switch]$Claude,
  [switch]$Codex,
  [switch]$Antigravity,
  [switch]$All,
  [string]$HomeDir = $HOME
)

$ErrorActionPreference = 'Stop'
$SkillName = 'fixmyvibe'
$Src = $PSScriptRoot                          # this skill folder (source of truth)
if (-not (Test-Path (Join-Path $Src 'SKILL.md'))) { throw "SKILL.md not found next to installer ($Src)." }

$cmdTemplate = Get-Content (Join-Path $Src 'command.md') -Raw
$marker = '<!-- fixmyvibe:managed -->'
$installed = @()

function Copy-Skill($dest) {
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  # Copy contents of $Src into $dest (overwrite). Exclude VCS noise.
  Copy-Item -Path (Join-Path $Src '*') -Destination $dest -Recurse -Force -Exclude @('.git')
}

function Write-Command($destFile, $skillDir) {
  New-Item -ItemType Directory -Force -Path (Split-Path $destFile) | Out-Null
  ($cmdTemplate -replace '\{\{SKILL_DIR\}\}', ($skillDir -replace '\\','/')) |
    Set-Content -Path $destFile -Encoding utf8
}

function Add-AgentsBlock($agentsFile, $skillDir) {
  $block = @"
$marker
## FixMyVibe craft standard (auto-installed)
Before writing/generating/refactoring code or building any UI, follow the FixMyVibe skill at
$skillDir/SKILL.md: read-before-write, refuse the average, and pass references/FINISH-GATE.md
(run bin/fixmyvibe-audit) before claiming done. Never emit anything in references/FORBIDDEN-PATTERNS.md.
Invoke explicitly with /$SkillName.
<!-- /fixmyvibe:managed -->
"@
  New-Item -ItemType Directory -Force -Path (Split-Path $agentsFile) | Out-Null
  $existing = if (Test-Path $agentsFile) { Get-Content $agentsFile -Raw } else { '' }
  if ($existing -notmatch [regex]::Escape($marker)) {
    ($existing.TrimEnd() + "`r`n`r`n" + $block + "`r`n") | Set-Content -Path $agentsFile -Encoding utf8
    return $true
  }
  return $false
}

# Decide which agents to target
$detected = @{
  Claude      = Test-Path (Join-Path $HomeDir '.claude')
  Codex       = Test-Path (Join-Path $HomeDir '.codex')
  Antigravity = (Test-Path (Join-Path $HomeDir '.gemini')) -or (Test-Path (Join-Path $HomeDir '.antigravity'))
}
$explicit = $Claude -or $Codex -or $Antigravity
$do = @{
  Claude      = $All -or $Claude      -or (-not $explicit -and $detected.Claude)
  Codex       = $All -or $Codex       -or (-not $explicit -and $detected.Codex)
  Antigravity = $All -or $Antigravity -or (-not $explicit -and $detected.Antigravity)
}

Write-Host "== FixMyVibe installer ==  (HOME: $HomeDir)"
Write-Host ("detected -> Claude:{0}  Codex:{1}  Antigravity:{2}" -f $detected.Claude,$detected.Codex,$detected.Antigravity)

# ---- Claude Code ----
if ($do.Claude) {
  $skillDir = Join-Path $HomeDir ".claude/skills/$SkillName"
  Copy-Skill $skillDir
  Write-Command (Join-Path $HomeDir ".claude/commands/$SkillName.md") $skillDir
  Write-Host "[Claude] skill -> $skillDir ; command -> /$SkillName" -ForegroundColor Green
  $installed += 'Claude (/fixmyvibe)'
}

# ---- Codex CLI ----
if ($do.Codex) {
  $skillDir = Join-Path $HomeDir ".codex/skills/$SkillName"
  Copy-Skill $skillDir
  Write-Command (Join-Path $HomeDir ".codex/prompts/$SkillName.md") $skillDir   # prompts/<name>.md -> /<name>
  Add-AgentsBlock (Join-Path $HomeDir ".codex/AGENTS.md") $skillDir | Out-Null
  Write-Host "[Codex]  skill -> $skillDir ; command -> /$SkillName (prompts) ; AGENTS.md updated" -ForegroundColor Green
  $installed += 'Codex (/fixmyvibe)'
}

# ---- Antigravity ----
if ($do.Antigravity) {
  $base = if (Test-Path (Join-Path $HomeDir '.antigravity')) { Join-Path $HomeDir '.antigravity' } else { Join-Path $HomeDir '.gemini' }
  $skillDir = Join-Path $base "skills/$SkillName"
  Copy-Skill $skillDir
  Write-Command (Join-Path $base "workflows/$SkillName.md") $skillDir            # global workflow -> /<name>
  Add-AgentsBlock (Join-Path $HomeDir ".gemini/AGENTS.md") $skillDir | Out-Null
  Write-Host "[Antigravity] skill -> $skillDir ; workflow -> /$SkillName ; ~/.gemini/AGENTS.md updated" -ForegroundColor Green
  Write-Host "  note: if /$SkillName does not appear, import $base/workflows/$SkillName.md via Antigravity's '+ Global' workflow button." -ForegroundColor DarkYellow
  $installed += 'Antigravity (/fixmyvibe)'
}

Write-Host '----------------------------------------'
if ($installed.Count -eq 0) {
  Write-Host 'No agents installed. None detected - re-run with -All or a specific -Claude/-Codex/-Antigravity flag.' -ForegroundColor Yellow
} else {
  Write-Host ('Installed into: ' + ($installed -join ', ')) -ForegroundColor Cyan
  Write-Host 'Open a fresh agent session and type /fixmyvibe to use it.'
}
