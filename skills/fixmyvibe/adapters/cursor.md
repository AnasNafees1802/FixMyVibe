# Cursor

## Install
Cursor loads skills from `~/.cursor/skills/`, `~/.agents/skills/`, and also `~/.claude/skills/`.
`install.ps1` or `install.sh` puts FixMyVibe in `~/.agents/skills/fixmyvibe/` (and in
`~/.claude/skills/` when Claude Code is present), so one install covers Cursor. For one project,
copy the folder to `<repo>/.agents/skills/fixmyvibe/`. Invoke it with `/fixmyvibe` or let Cursor
match it from the task.

## Enforce it with hooks
Cursor runs Claude Code hooks from `~/.claude/settings.json` by default. If you set up the hooks in
`claude-code.md`, they apply in Cursor too. This project has not tested a native
`.cursor/hooks.json` entry, so none is given here.

## Always on, without hooks
Add `.cursor/rules/fixmyvibe.mdc`:

```mdc
---
description: FixMyVibe standard for code, UI, and copy changes
alwaysApply: true
---
For any code, UI, or copy change, follow the fixmyvibe skill: read before you write, choose on
purpose, and prove it before you say done. Run its audit with --changed before reporting.
```
