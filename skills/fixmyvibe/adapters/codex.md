# Codex

## Install
`install.ps1` or `install.sh` copies this folder to `~/.agents/skills/fixmyvibe/`, the user skill
location Codex reads. For one project, copy it to `<repo>/.agents/skills/fixmyvibe/`. Invoke it
with `$fixmyvibe`, pick it from `/skills`, or let Codex match it from the task.

Older FixMyVibe versions installed to `~/.codex/skills/` and `~/.codex/prompts/`, and added a block
to `~/.codex/AGENTS.md`. Codex does not read the first, and has deprecated the second. Run the
installer with `-RemoveLegacy` (PowerShell) or `REMOVE_LEGACY=1` (shell) to clean them up.

## Enforce it with hooks
Codex reads hooks from `~/.codex/hooks.json` or `<repo>/.codex/hooks.json`, in the same shape as
Claude Code, and asks you to trust them through `/hooks` before they run:

```json
{
  "hooks": {
    "PostToolUse": [
      { "hooks": [{ "type": "command", "command": "bash \"$HOME/.agents/skills/fixmyvibe/bin/fixmyvibe-audit.sh\" --hook edit" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "bash \"$HOME/.agents/skills/fixmyvibe/bin/fixmyvibe-audit.sh\" --hook stop" }] }
    ]
  }
}
```

The stop hook is the one that matters: it scans everything changed since the last commit and
exits 2 with the report when a blocker is present. The edit hook needs the event to carry a
`file_path`; when it does not, the hook does nothing. This project tests hook mode against the
Claude Code event shape only, so confirm the behavior once in Codex before relying on it.

## Always on, without hooks
Add one line to `AGENTS.md`: "For any code, UI, or copy change, follow the fixmyvibe skill."
