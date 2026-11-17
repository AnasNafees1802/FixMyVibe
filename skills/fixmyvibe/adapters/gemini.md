# Gemini CLI

## Install
Gemini CLI loads skills from `~/.agents/skills/` and `~/.gemini/skills/`. `install.ps1` or
`install.sh` puts FixMyVibe in `~/.agents/skills/fixmyvibe/`. You can also let the CLI fetch it:

```bash
gemini skills install https://github.com/AnasNafees1802/FixMyVibe.git --path skills/fixmyvibe --scope user
```

Invoke it with `/fixmyvibe` or let the CLI match it from the task.

## Hooks
Gemini CLI has hooks (`AfterTool`, `AfterAgent`) with their own event format. This project has not
tested the audit's hook mode against them, so no configuration is given here. Run the audit by
hand, in a git pre-commit hook, or in CI:

```bash
bash ~/.agents/skills/fixmyvibe/bin/fixmyvibe-audit.sh --changed
```

## Always on
Add one line to `GEMINI.md` (project) or `~/.gemini/GEMINI.md` (everywhere): "For any code, UI, or
copy change, follow the fixmyvibe skill."
