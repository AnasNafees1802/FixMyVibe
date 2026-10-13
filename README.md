<div align="center">

# FixMyVibe

**AI can ship a polished demo and the vulnerability behind it.**

FixMyVibe is an open source skill that makes coding agents inspect the project, reject generic
defaults, test the risky paths, and show evidence before they call the work done.

`/fixmyvibe` | MIT licensed | Claude Code, Codex, Cursor, Antigravity, and Gemini

</div>

## The problem it solves

AI-generated software tends to fail in four places at once:

| Surface | Common failure |
|---|---|
| Code | Missing authorization, unsafe data flow, invented dependencies, swallowed errors, and happy-path-only behavior |
| Interface | Template-shaped layouts, inaccessible controls, missing states, and unexamined component defaults |
| Content | Empty hype, fabricated proof, repetitive phrasing, and copy that could belong to any product |
| AI systems | Prompt injection, unsafe model output, excessive tool authority, privacy leaks, and demos mistaken for evaluations |

FixMyVibe turns those failure modes into a repeatable workflow and a release gate. It combines
engineering judgment, product craft, risk profiles, and runnable repository checks in one portable
skill.

> **Read before you write. Refuse the average. Verify before you claim done.**

## Try it in 60 seconds

Review the installer before running remote code, then install the skill:

```powershell
# Windows
irm https://raw.githubusercontent.com/AnasNafees1802/FixMyVibe/main/bootstrap.ps1 | iex
```

```bash
# macOS or Linux
curl -fsSL https://raw.githubusercontent.com/AnasNafees1802/FixMyVibe/main/bootstrap.sh | bash
```

Open a fresh agent session and run:

```text
/fixmyvibe audit .
```

To install from a clone instead, see
[`skills/fixmyvibe/INSTALL.md`](skills/fixmyvibe/INSTALL.md).

## One skill, four gates

FixMyVibe first reads the repository and selects the rules that match the work. A UI change loads
the design and accessibility standards. An API change loads the relevant security profile. A
model-backed feature adds prompt-injection, privacy, tool-safety, and evaluation checks.

The operating loop is deliberately small:

1. **Inspect:** find the stack, conventions, design system, trust boundaries, and existing tools.
2. **Decide:** classify risk, reject generic defaults, and choose the evidence required to finish.
3. **Build:** handle failure states, authorization, accessibility, content, and AI-specific risks as applicable.
4. **Verify:** run tests, stack-native checks, the FixMyVibe audit, and a scored self-review.
5. **Report:** state what passed, what was not checked, and why any warning remains.

## Modes

```text
/fixmyvibe <task>        Build or change software using the full workflow
/fixmyvibe audit <path>  Diagnose existing work and return a ranked punch list without editing
/fixmyvibe review        Apply the finish gate to the current diff
```

The content standard also distinguishes writing, editing, and detection. Detection identifies the
specific pattern and location without guessing whether AI wrote it. Editing preserves the author's
voice and makes the smallest change that fixes the problem.

## How it compares

The neighboring projects are useful specialists. FixMyVibe is designed for the broader software
delivery boundary.

| Capability | [no-ai-slop](https://github.com/petergyang/no-ai-slop) | [Anti-AI-UI](https://github.com/Vanszs/Anti-AI-UI) | FixMyVibe |
|---|:---:|:---:|:---:|
| Detect and edit generic prose | Strong focus | Partial | Included |
| UI anti-pattern guidance | No | Strong focus | Included |
| Positive UI decision method | No | Component and style references | Project-derived design system |
| Code security and correctness | No | Pattern catalog | Risk-profiled gate |
| AI feature security and evaluations | No | No | Included |
| Web, API, mobile, CLI, library, infrastructure, data, and IoT profiles | No | No | Included |
| Cross-platform repository audit | No | No | PowerShell and shell |
| Explicit evidence-before-done contract | Writing evaluation | UI review workflow | Full delivery workflow |

This is a scope comparison based on the public repositories reviewed on 13 October 2026, not a
claim that one tool replaces every specialist. FixMyVibe adopts their strongest ideas, including
voice-preserving edits, detection without fake authorship claims, detailed component review, and
positive references. It avoids turning a fixed palette, font list, or template catalog into the
next default.

The full evidence and competitor notes are in
[`research/RESEARCH.md`](research/RESEARCH.md).

## The executable audit

The repository includes equivalent PowerShell and shell gates with stable rule IDs, staged
added-line scanning, strict-warning mode, visible suppressions, and machine-readable JSON on
PowerShell.

```powershell
pwsh skills/fixmyvibe/bin/fixmyvibe-audit.ps1 -Staged
pwsh skills/fixmyvibe/bin/fixmyvibe-audit.ps1 -StrictWarnings -Format Json src
pwsh -NoProfile -File tests/audit.tests.ps1
```

```bash
bash skills/fixmyvibe/bin/fixmyvibe-audit.sh --staged
bash skills/fixmyvibe/bin/fixmyvibe-audit.sh --strict-warnings src
bash tests/audit.tests.sh
```

| Exit code | Meaning |
|---:|---|
| `0` | No blockers under the selected mode |
| `1` | A blocking rule matched, or strict warnings remain |
| `2` | The scan could not complete |

A clean heuristic scan does **not** prove that software is secure, correct, accessible, or
well-designed. The skill requires stack-native tests, security tools, manual flow checks, and human
review in proportion to risk. A reviewed false positive can use a narrow suppression such as
`fixmyvibe: allow SEC201 trusted-sanitized-renderer`; the rule ID and reason are required, and the
suppression remains visible in the report.

## What ships

```text
skills/fixmyvibe/
|-- SKILL.md                     Entry point and operating loop
|-- INSTALL.md                   Installation and update guide
|-- command.md                   Slash-command template
|-- install.ps1 / install.sh     Cross-agent installers
|-- adapters/                    Agent-specific integration files
|-- bin/
|   |-- fixmyvibe-audit.ps1      PowerShell audit
|   `-- fixmyvibe-audit.sh       Shell audit
`-- references/
    |-- CODE-CRAFT.md            Security, correctness, maintainability, and honesty
    |-- RISK-PROFILES.md         Risk tiers and system-specific profiles
    |-- SECURITY-VERIFICATION.md Layered evidence and finding discipline
    |-- UI-CRAFT.md              Design method, component states, and accessibility
    |-- CONTENT-CRAFT.md         Write, edit, and detect modes for shipped prose
    |-- AI-SYSTEMS.md            Model, retrieval, data, tool, and evaluation safety
    |-- DESIGN-DIRECTIONS.md     Context-driven visual and structural decisions
    |-- SELF-CRITIQUE.md         Scored review rubric
    |-- FORBIDDEN-PATTERNS.md    Blocking failures and contextual review signals
    `-- FINISH-GATE.md           Evidence required before completion

tests/                           PowerShell and shell regression suites
research/RESEARCH.md             Standards baseline and competitor teardown
```

## Supported agents

| Agent | Skill location | Command integration |
|---|---|---|
| Claude Code | `~/.claude/skills/fixmyvibe/` | `~/.claude/commands/fixmyvibe.md` |
| Codex | `~/.codex/skills/fixmyvibe/` | `~/.codex/prompts/fixmyvibe.md` |
| Antigravity | `~/.gemini/skills/fixmyvibe/` | `~/.gemini/workflows/fixmyvibe.md` |
| Cursor | Manual skill or rules integration | See the install guide |
| Gemini | Manual skill integration | See the install guide |

To force installation for the three auto-detected agents:

```powershell
$env:FIXMYVIBE_ALL='1'; irm https://raw.githubusercontent.com/AnasNafees1802/FixMyVibe/main/bootstrap.ps1 | iex
```

```bash
curl -fsSL https://raw.githubusercontent.com/AnasNafees1802/FixMyVibe/main/bootstrap.sh | ALL=1 bash
```

## License

MIT Copyright 2026 Anas Nafees. See [LICENSE](LICENSE).
