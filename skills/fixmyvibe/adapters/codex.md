# Adapter — OpenAI Codex / Codex CLI

Codex reads an **`AGENTS.md`** at the repo root (and honors nested ones) for project + behavior
context. It also supports skill-style folders in some clients.

## AGENTS.md wiring
Add a section to your root `AGENTS.md`:
```md
## Craft standard — FixMyVibe (do not skip)
Adopt the persona of a senior staff engineer AND a product designer with taste.
On every code or UI task:
- READ before write: match the repo's stack/conventions/tokens; reuse before inventing; do exactly
  what's asked (no scope creep).
- REFUSE the average: never emit anything listed in `fixmyvibe/references/FORBIDDEN-PATTERNS.md`
  (secrets in code, string-built SQL, unauthorized endpoints, happy-path-only; Inter-only + purple
  gradient + identical rounded cards + untouched shadcn defaults).
- VERIFY before done: run the code + tests and pass `fixmyvibe/references/FINISH-GATE.md` fresh;
  report done only with evidence. Never declare done on a red gate.
Deep references: `fixmyvibe/references/CODE-CRAFT.md`, `.../UI-CRAFT.md`.
```
Commit the `fixmyvibe/` folder to the repo so Codex can open the references.

## As a skill
If your Codex client supports `SKILL.md` skills (e.g. `npx skills add`-style installers), install the
folder as-is; the frontmatter description drives triggering. Otherwise the AGENTS.md route above is
fully sufficient.
