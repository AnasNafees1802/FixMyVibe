# FixMyVibe

FixMyVibe is a portable craft and release-gate skill for AI coding agents. It reviews four connected
surfaces: code, interface, user-facing content, and AI-enabled features. The agent must inspect the
project first, apply the relevant risk profile, and show fresh evidence before claiming completion.

The full public overview, comparison, install options, and audit examples are in
[`../../README.md`](../../README.md).

## Why it exists

A polished result can still hide missing authorization, unsafe output handling, fabricated proof,
inaccessible controls, or untested failure paths. FixMyVibe converts those predictable failures into
an operating loop:

1. Read the repository and identify its existing conventions.
2. Classify the risk and select only the relevant references.
3. Build or review the work across every affected surface.
4. Run the finish gate and report both evidence and limitations.

The bundled audit is a fast heuristic layer. It does not replace stack-native testing, security
analysis, accessibility checks, threat modeling, or qualified human review.

## Quick start from this folder

```powershell
./install.ps1
```

```bash
./install.sh
```

The installer copies the skill to detected Claude Code, Codex, and Antigravity locations and
registers `/fixmyvibe`. Cursor and Gemini have manual adapters. See [`INSTALL.md`](INSTALL.md) for
the complete matrix and pinned-install guidance.

After opening a fresh agent session:

```text
/fixmyvibe <task>
/fixmyvibe audit <path>
/fixmyvibe review
```

## Package map

```text
fixmyvibe/
|-- SKILL.md                     Entry point and operating loop
|-- INSTALL.md                   Installation and update guide
|-- command.md                   Slash-command template
|-- install.ps1 / install.sh     Cross-agent installers
|-- bin/                         PowerShell and shell audit gates
|-- adapters/                    Agent-specific integration files
`-- references/
    |-- CODE-CRAFT.md            Security, correctness, maintainability, and honesty
    |-- RISK-PROFILES.md         Risk tiers and system profiles
    |-- SECURITY-VERIFICATION.md Evidence selection and finding discipline
    |-- UI-CRAFT.md              Design method, component states, and accessibility
    |-- CONTENT-CRAFT.md         Write, edit, and detect modes
    |-- AI-SYSTEMS.md            Model, retrieval, privacy, tool, and evaluation safety
    |-- DESIGN-DIRECTIONS.md     Context-driven visual decisions
    |-- SELF-CRITIQUE.md         Scored review rubric
    |-- FORBIDDEN-PATTERNS.md    Blocking failures and contextual signals
    `-- FINISH-GATE.md           Evidence required before completion
```

The contract is simple: **read before you write, refuse the average, and verify before you claim
done.**
