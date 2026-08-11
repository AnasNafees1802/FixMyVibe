<div align="center">

# FixMyVibe

**Stop shipping vibe-coded slop.**

One agent skill that makes Claude Code, Codex, and Antigravity write **secure, maintainable code**
and **distinctive, accessible UI** — and *prove* it before saying "done."

`/fixmyvibe` · MIT licensed · works across 5 agents

</div>

---

## The problem

Vibe coding (prompting an agent and shipping whatever it produces) fails in **predictable** ways,
because a model emits the *most probable* output — the average of its training data:

- In **code**, that average is the most common, often insecure pattern: hardcoded secrets, missing
  authorization, string-built SQL, hallucinated dependencies, no tests, happy-path-only.
  *(Real data: ~10% of scanned Lovable apps had exploitable SQLi/XSS; 11% leaked Supabase keys;
  19.7% of AI-suggested packages are hallucinated.)*
- In **UI**, that average is the same template every time: Inter + a purple→blue gradient +
  identical rounded cards, no empty/loading/error states, failing accessibility.

Existing tools fix only the second half. **FixMyVibe fixes both — and makes the gate runnable.**

## What it does

FixMyVibe loads a **craft standard** into your agent and enforces one contract:

> **Read before you write · Refuse the average · Verify before you claim done.**

Three modes:
- **`/fixmyvibe <task>`** — build to the standard (pre-flight scan → deliberate design direction →
  code + UI craft → gate).
- **`/fixmyvibe audit <path>`** — score existing code/UI, return a ranked punch list (no edits).
- **`/fixmyvibe review`** — run the gate on your current diff.

It ships an **executable gate** — `bin/fixmyvibe-audit.{sh,ps1}` — that greps a diff for the
security + slop blocklist and **exits non-zero**. Wire it into CI, a pre-commit hook, or an agent
Stop hook. *(Even the leading design skill has no runnable gate.)*

## Install

**One line — installs into every detected agent (no clone needed):**
```powershell
# Windows (PowerShell)
irm https://raw.githubusercontent.com/AnasNafees1802/FixMyVibe/main/bootstrap.ps1 | iex
```
```bash
# macOS / Linux
curl -fsSL https://raw.githubusercontent.com/AnasNafees1802/FixMyVibe/main/bootstrap.sh | bash
```
Force all three even if not yet detected:
```powershell
$env:FIXMYVIBE_ALL='1'; irm https://raw.githubusercontent.com/AnasNafees1802/FixMyVibe/main/bootstrap.ps1 | iex
```
```bash
curl -fsSL https://raw.githubusercontent.com/AnasNafees1802/FixMyVibe/main/bootstrap.sh | ALL=1 bash
```

**Or from a clone:**
```bash
cd skills/fixmyvibe && ./install.ps1     # Windows   (./install.sh on macOS/Linux; -All / ALL=1 to force)
```

Either way it copies the skill into each agent and registers a **`/fixmyvibe`** slash command
(idempotent). Then open a fresh session and try `/fixmyvibe audit .` on one of your own repos.

| Agent | Skill → | `/fixmyvibe` via |
|---|---|---|
| Claude Code | `~/.claude/skills/fixmyvibe/` | `~/.claude/commands/fixmyvibe.md` |
| Codex | `~/.codex/skills/fixmyvibe/` | `~/.codex/prompts/fixmyvibe.md` |
| Antigravity | `~/.gemini/skills/fixmyvibe/` | `~/.gemini/workflows/fixmyvibe.md` |

Cursor and Gemini are supported manually — see [`skills/fixmyvibe/INSTALL.md`](skills/fixmyvibe/INSTALL.md).

## How it beats the field

| Capability | Hallmark | Koomook | awesome-claude-design | **FixMyVibe** |
|---|:--:|:--:|:--:|:--:|
| Concrete anti-slop design gates | ✅✅ | ✅ | ✅(ref) | ✅✅ |
| Scored self-critique / audit mode | ✅ | ❌ | ❌ | ✅ (code+design) |
| **Security / correctness / deps** | ❌ | ❌ | ❌ | ✅✅ |
| Full-stack (not just HTML/CSS) | ❌ | ❌ | ❌ | ✅ |
| **Executable CI/hook gate** | ❌ | ❌ | ❌ | ✅ |
| Agent ecosystems | 3 | 1 | 1–2 | **5** |

Adopt **one** skill instead of a design skill + a security linter + a review checklist.
Full teardown and citations: [`research/RESEARCH.md`](research/RESEARCH.md).

## What's inside

```
skills/fixmyvibe/
├── SKILL.md                     # entry: persona + laws + build/audit/review + loop
├── install.ps1 / install.sh     # cross-agent installer, registers /fixmyvibe
├── command.md                   # the /fixmyvibe slash-command template
├── references/
│   ├── CODE-CRAFT.md            # security, correctness, maintainability, honesty
│   ├── UI-CRAFT.md              # bespoke design system, every state, a11y
│   ├── DESIGN-DIRECTIONS.md     # aesthetic direction + macrostructure + concrete gates
│   ├── SELF-CRITIQUE.md         # scored pre-emit rubric (code+design) + audit mode
│   ├── FORBIDDEN-PATTERNS.md    # the hard blocklist the gate checks
│   └── FINISH-GATE.md           # verify-before-done self-audit
├── bin/fixmyvibe-audit.sh/.ps1  # executable gate: grep the diff, exit non-zero
└── adapters/                    # claude-code · cursor · codex · antigravity · gemini
research/RESEARCH.md             # evidence base + competitor teardown (30+ sources)
```

## License

MIT © 2026 Anas Nafees. See [LICENSE](LICENSE).
