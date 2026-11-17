# Claude Code

## Install
`install.ps1` or `install.sh` copies this folder to `~/.claude/skills/fixmyvibe/`. For one project,
copy it to `<repo>/.claude/skills/fixmyvibe/` instead. Claude Code finds the skill on its own and
loads it when a task matches the description. `/fixmyvibe` invokes it by name, and
`/fixmyvibe audit src/` runs audit mode. No separate command file is needed.

## Enforce it with hooks
Instructions can be skipped; a hook cannot. Two hooks make the audit part of every session:

- **After each edit**, the audit checks the lines just added to that file and reports blockers back
  to Claude straight away.
- **Before Claude stops**, the audit checks everything changed since the last commit. If there is a
  blocker, Claude is sent back to fix it. It blocks once per stop, so it cannot trap the session.

Add this to `~/.claude/settings.json` (every project) or `<repo>/.claude/settings.json` (one project):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [{ "type": "command", "command": "bash \"$HOME/.claude/skills/fixmyvibe/bin/fixmyvibe-audit.sh\" --hook edit" }]
      }
    ],
    "Stop": [
      {
        "hooks": [{ "type": "command", "command": "bash \"$HOME/.claude/skills/fixmyvibe/bin/fixmyvibe-audit.sh\" --hook stop" }]
      }
    ]
  }
}
```

On Windows, Claude Code runs hook commands in Git Bash when it is installed, so the same lines
work. Without Git Bash, use the PowerShell edition:

```json
{ "type": "command", "shell": "powershell", "command": "& \"$HOME\\.claude\\skills\\fixmyvibe\\bin\\fixmyvibe-audit.ps1\" -Hook stop" }
```

Hook behavior: exit 0 when there are no blockers, exit 2 with the report on stderr when there are
(Claude reads it and continues), exit 1 when the scan itself failed (shown to you, does not block).
Warnings never block a hook; they appear when the audit is run by hand.

The hook mode is tested in this repository with the event shape Claude Code documents
(`tool_input.file_path`, `stop_hook_active`). Confirm it once in your own setup: ask Claude to add
`const k = eval(input)` to a file and check that the edit hook objects.

## Always on, without hooks
To apply the standard to every task without waiting for the skill to trigger, add one line to
`CLAUDE.md`: "For any code, UI, or copy change, follow the fixmyvibe skill."
