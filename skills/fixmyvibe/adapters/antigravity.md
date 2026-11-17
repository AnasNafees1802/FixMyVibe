# Antigravity

## Install
Antigravity loads global skills from `~/.gemini/config/skills/` and workspace skills from
`<workspace>/.agents/skills/`. `install.ps1` or `install.sh` writes
`~/.gemini/config/skills/fixmyvibe/` when Antigravity is detected. Invoke it with `/fixmyvibe`.

Older FixMyVibe versions wrote a workflow file and an `AGENTS.md` block. Antigravity has deprecated
workflows in favor of skills. Run the installer with `-RemoveLegacy` (PowerShell) or
`REMOVE_LEGACY=1` (shell) to clean them up.

## Making the gate part of a task
Antigravity runs long, multi-step tasks on its own. Put the gate in the task itself: "Before
marking this complete, run the fixmyvibe audit with --changed and attach the output." Treat deploys
and destructive actions as points where a person approves.

This project has not tested hook enforcement in Antigravity. The audit also runs from a git
pre-commit hook or CI, which works with any agent:

```bash
bash ~/.gemini/config/skills/fixmyvibe/bin/fixmyvibe-audit.sh --staged
```
