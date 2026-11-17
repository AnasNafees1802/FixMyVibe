# Install

Keep this folder together: `SKILL.md` needs `references/` and `bin/` beside it.

## With the skills CLI

```bash
npx skills add AnasNafees1802/FixMyVibe -g
```

It finds `skills/fixmyvibe/` in the repository and installs it for the agents it detects.

## With the bundled installer

From this folder:

```powershell
./install.ps1                 # every detected agent
./install.ps1 -All            # all three locations
./install.ps1 -Claude -Agents # named locations only
./install.ps1 -RemoveLegacy   # also remove files left by older versions
```

```bash
./install.sh
ALL=1 ./install.sh
AGENTS="claude agents" ./install.sh
REMOVE_LEGACY=1 ./install.sh
```

| Location | Path | Agents that read it | Invoke with |
|---|---|---|---|
| claude | `~/.claude/skills/fixmyvibe/` | Claude Code, Cursor | `/fixmyvibe` |
| agents | `~/.agents/skills/fixmyvibe/` | Codex, Cursor, Gemini CLI | `$fixmyvibe` in Codex, `/fixmyvibe` elsewhere |
| antigravity | `~/.gemini/config/skills/fixmyvibe/` | Antigravity | `/fixmyvibe` |

Each run replaces the installed copy. The installer only replaces a folder that already holds a
FixMyVibe `SKILL.md`, and it never edits agent settings.

## Without cloning

This runs code fetched from the repository's `main` branch. Read the bootstrap script first. For a
pinned or regulated environment, clone a reviewed commit and use the installer above.

```powershell
irm https://raw.githubusercontent.com/AnasNafees1802/FixMyVibe/main/bootstrap.ps1 | iex
```

```bash
curl -fsSL https://raw.githubusercontent.com/AnasNafees1802/FixMyVibe/main/bootstrap.sh | bash
```

## For one project
Copy this folder to `<repo>/.claude/skills/fixmyvibe/` (Claude Code) or
`<repo>/.agents/skills/fixmyvibe/` (Codex, Cursor, Gemini CLI, Antigravity) and commit it.

## Enforcement
Loading the skill gives the agent the standard. Hooks make the audit run whether or not the agent
remembers. See `adapters/` for each agent, starting with `adapters/claude-code.md`.

## Check that it loaded
Open a new session and ask: "Use fixmyvibe to audit this folder." The agent should run
`bin/fixmyvibe-audit` and return findings with `file:line`. If it does not know the skill, check
the path in the table above.
