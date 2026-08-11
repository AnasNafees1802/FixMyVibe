# INSTALL

Keep the whole `fixmyvibe/` folder together (the references, adapters, and `bin/` must travel with
`SKILL.md`).

## Zero-clone — one-line remote install
Installs into every detected agent straight from GitHub:
```powershell
# Windows (PowerShell)  — add  $env:FIXMYVIBE_ALL='1';  before it to force all three
irm https://raw.githubusercontent.com/AnasNafees1802/FixMyVibe/main/bootstrap.ps1 | iex
```
```bash
# macOS / Linux  — prefix with  ALL=1  after the pipe to force all three
curl -fsSL https://raw.githubusercontent.com/AnasNafees1802/FixMyVibe/main/bootstrap.sh | bash
```

## One command — from a clone
From inside the `fixmyvibe/` folder, run the installer. It copies the skill into each agent it
detects and registers a **`/fixmyvibe`** slash command in each. Idempotent — safe to re-run.

```powershell
# Windows (PowerShell)
./install.ps1            # auto: every agent detected on this machine
./install.ps1 -All       # force all three (Claude, Codex, Antigravity), creating dirs
./install.ps1 -Claude -Codex   # only the named agent(s)
```
```bash
# macOS / Linux
./install.sh             # auto-detect
ALL=1 ./install.sh       # force all three
AGENTS="claude codex" ./install.sh   # only the named agent(s)
```

What it writes (matches the Continuum layout):
| Agent | Skill copied to | `/fixmyvibe` registered via | Rules file touched |
|---|---|---|---|
| Claude Code | `~/.claude/skills/fixmyvibe/` | `~/.claude/commands/fixmyvibe.md` | — |
| Codex | `~/.codex/skills/fixmyvibe/` | `~/.codex/prompts/fixmyvibe.md` | `~/.codex/AGENTS.md` |
| Antigravity | `~/.gemini/skills/fixmyvibe/` | `~/.gemini/workflows/fixmyvibe.md` | `~/.gemini/AGENTS.md` |

Then open a **fresh** agent session and type `/fixmyvibe <what to build, or `audit <path>`>`.
(If Antigravity doesn't list `/fixmyvibe`, import `~/.gemini/workflows/fixmyvibe.md` via its
**+ Global** workflow button — the installer prints the exact path.)

---

## Manual install — 60 seconds per agent
Prefer to wire it yourself, or using Cursor/Gemini? Do it by hand:

## Claude Code
```bash
# global (all projects)
cp -r fixmyvibe ~/.claude/skills/fixmyvibe
# or per-project
cp -r fixmyvibe <repo>/.claude/skills/fixmyvibe
```
Then invoke `/fixmyvibe`, or just ask it to build/design something — the description auto-triggers it.
Details + always-on option: `adapters/claude-code.md`.

## Cursor
Add `.cursor/rules/fixmyvibe.mdc` (see `adapters/cursor.md` for the exact contents) and keep the
`fixmyvibe/` folder in the repo. Legacy: paste the rule body into a root `.cursorrules`.

## OpenAI Codex
Add the FixMyVibe section to your root `AGENTS.md` (body in `adapters/codex.md`) and commit the
`fixmyvibe/` folder so the references are openable.

## Google Antigravity
Add the standard to the project rules / `AGENTS.md` and make the Finish Gate an explicit acceptance
step in each task. See `adapters/antigravity.md`.

## Gemini
Add the FixMyVibe block to `GEMINI.md` (project or `~/.gemini/GEMINI.md`). See `adapters/gemini.md`.

---

## Verify the install
Ask the agent: *"Build me a modern SaaS landing page."* A correctly-loaded FixMyVibe agent will:
- **not** immediately emit Inter + a purple gradient + three identical rounded cards;
- ask about (or state assumptions for) brand personality and derive design tokens first;
- include empty/loading/error states and accessibility;
- and finish by running the **Finish Gate** and reporting evidence — not just "here you go."

If it does the slop thing, the skill isn't loaded — recheck the path / rules file.

## Strongest setup: pair with Perpetua
Arm a Perpetua mission whose Definition of Done includes *"FixMyVibe Finish Gate is green."* The
Stop-guard then refuses to let the agent stop while the gate is red — enforcement, not just advice.
