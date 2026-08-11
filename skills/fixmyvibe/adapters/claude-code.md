# Adapter — Claude Code

FixMyVibe is already a native Claude Code **skill** (`SKILL.md` with frontmatter). Two ways to use it.

## Option A — as a skill (recommended)
1. Copy the whole `fixmyvibe/` folder into your skills directory:
   - Global: `~/.claude/skills/fixmyvibe/`  (Windows: `C:\Users\<you>\.claude\skills\fixmyvibe\`)
   - Or per-project: `<repo>/.claude/skills/fixmyvibe/`
2. Claude Code auto-discovers it. The `description` in `SKILL.md` makes it trigger whenever you ask
   to build/generate/style code or UI. You can also invoke it explicitly with `/fixmyvibe`.
3. Claude reads `SKILL.md` first and pulls in `references/*` on demand (progressive disclosure).

## Option B — always-on via CLAUDE.md
If you want the standard applied on *every* task without waiting for the trigger, add to your
project `CLAUDE.md` (or `~/.claude/CLAUDE.md`):
```md
## Craft standard (FixMyVibe)
Before writing/generating/refactoring code or building any UI, follow
`.claude/skills/fixmyvibe/SKILL.md`: read-before-write, refuse the average, and pass
`references/FINISH-GATE.md` before claiming done. Never emit anything in
`references/FORBIDDEN-PATTERNS.md`.
```

## Enforcement (make "done" impossible while red)
Pair with **Perpetua**: arm a mission whose Definition of Done includes "FixMyVibe Finish Gate is
green." Perpetua's Stop-guard hook then blocks the agent from stopping while the gate is red. Or add
a lightweight `Stop` hook that greps the diff for FORBIDDEN-PATTERNS §A (secrets/injection) and
re-injects a "gate not passed" message on a hit.
