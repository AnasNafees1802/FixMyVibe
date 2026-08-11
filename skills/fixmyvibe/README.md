# FixMyVibe

**A portable, agent-agnostic skill that stops AI coding agents from shipping vibe-coded mistakes and
generic "AI slop" UI/UX.** Drop it into Claude Code, Cursor, Codex, Antigravity, or Gemini and the
agent switches from "produce the most probable output" to **crafted, secure, maintainable,
distinctive** — and it must *prove* the work before claiming done.

## Why it exists
Unsupervised AI code fails in predictable ways because a model emits the *average* of its training
data. In code that average is the most common (often insecure, untested, happy-path-only) pattern;
in UI it's the average template (Inter + purple gradient + identical rounded cards). See
`../../research/RESEARCH.md` for the evidence base (Lovable's 48-day auth flaw across ~10% of scanned
apps; 11% leaking Supabase keys; 19.7% hallucinated dependencies; the "why all AI sites look the
same" literature).

## What makes it better than existing tools
The best existing anti-slop tool, **Hallmark** (~12.3K★), is superb — but **design-only and
HTML/CSS-only**. It does nothing about the failures that actually get vibe-coded apps breached
(leaked keys, missing authz, injection, hallucinated deps). The rest (Koomook, awesome-claude-design,
awesome-cursorrules) are single-aesthetic skills or curated lists. See the full scoreboard in
`../../research/RESEARCH.md §D2`. FixMyVibe:
1. **Covers two axes** — code-craft (security/correctness/maintainability) *and* design-craft.
   Adopt **one** skill instead of a design skill + a security linter + a review checklist.
2. **Absorbs the best mechanisms and generalizes them to code** — pre-flight scan, a scored
   pre-emit **self-critique**, an **audit** mode, progressive loading, and a **diversification**
   rule now apply to *code*, not just UI.
3. **Matches the design rigor** — concrete gates (OKLCH tokens, `minmax(0,1fr)`, `:focus-visible`,
   8 states, no italic headers / fake chrome / invented metrics) + an aesthetic-direction menu.
4. **Enforces executably** — a mandatory **Finish Gate** *plus* `bin/fixmyvibe-audit.{sh,ps1}` that
   greps a diff and exits non-zero. Even Hallmark has no runnable gate.
5. **Runs on any agent** — one folder, adapters for **five** ecosystems (Hallmark supports three).

## What's inside
```
fixmyvibe/
├── SKILL.md                     # entry point (persona + laws + build/audit/review modes + loop)
├── README.md                    # this file
├── INSTALL.md                   # one-command + manual install per agent
├── install.ps1 / install.sh     # installer: copies skill into each agent, registers /fixmyvibe
├── command.md                   # the /fixmyvibe slash-command template (SKILL_DIR is substituted)
├── references/
│   ├── CODE-CRAFT.md            # security, correctness, maintainability, honesty
│   ├── UI-CRAFT.md              # derive a design system; states; accessibility; anti-slop
│   ├── DESIGN-DIRECTIONS.md     # aesthetic direction + macrostructure + diversification + gates
│   ├── SELF-CRITIQUE.md         # scored pre-emit rubric (code+design) + audit mode
│   ├── FORBIDDEN-PATTERNS.md    # the hard blocklist (what the gate checks)
│   └── FINISH-GATE.md           # verify-before-done self-audit
├── bin/
│   └── fixmyvibe-audit.sh / .ps1  # executable gate: grep the diff, exit non-zero on a blocker
└── adapters/
    ├── claude-code.md  cursor.md  codex.md  antigravity.md  gemini.md
```

## Quick start — one command, all agents
From inside this folder:
```powershell
./install.ps1        # Windows — auto-detects Claude Code, Codex, Antigravity
```
```bash
./install.sh         # macOS/Linux — same
```
It copies the skill into each detected agent and registers a **`/fixmyvibe`** slash command in each
(`-All` / `ALL=1` forces all three). Then open a fresh session and type `/fixmyvibe <task>` — or
`/fixmyvibe audit <path>` to review existing code/UI. Full matrix + manual/Cursor/Gemini steps in
`INSTALL.md`.

## The one-sentence contract
*Read before you write · refuse the average · verify before you claim done.*
