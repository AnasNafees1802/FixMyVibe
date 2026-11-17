# FixMyVibe (skill folder)

This folder is the installable skill. The project overview, measured results, and comparison with
other skills are in the repository's top-level `README.md`.

| Path | What it is |
|---|---|
| `SKILL.md` | The instructions an agent loads: size the work, the loop, the audit, the report format |
| `references/` | Detail the agent loads on demand: code, UI, design directions, copy, AI features, risk profiles, the finish gate, the review method, the pattern catalog |
| `bin/fixmyvibe-audit.sh`, `bin/fixmyvibe-audit.ps1` | The audit, in two editions that report the same findings |
| `bin/rules.conf` | The rule pack both editions read |
| `adapters/` | Per-agent install notes and hook configuration |
| `install.ps1`, `install.sh` | Copy this folder to where each agent looks for skills |

## Use the audit on its own

The audit needs only bash with grep and awk, or PowerShell 5.1 or later. It has no other dependency.

```bash
bash bin/fixmyvibe-audit.sh --changed          # lines added since the last commit, plus new files
bash bin/fixmyvibe-audit.sh src                # whole files under src
bash bin/fixmyvibe-audit.sh --staged           # for a pre-commit hook
bash bin/fixmyvibe-audit.sh --since origin/main --format json   # for CI
```

```powershell
./bin/fixmyvibe-audit.ps1 -Changed
./bin/fixmyvibe-audit.ps1 src
./bin/fixmyvibe-audit.ps1 -Staged
./bin/fixmyvibe-audit.ps1 -Since origin/main -Format Json
```

Exit codes: 0 no blockers, 1 blockers (or warnings with `--strict-warnings`), 2 the scan did not
complete.

## Tune it for a project

- **One line:** append `fixmyvibe: allow RULE-ID reason` in a comment on the line. The reason is
  required, and the suppression is listed in every report.
- **Paths and rules:** a `.fixmyvibeignore` file in the project root takes one path glob per line,
  and `rule:RULE-ID` lines to turn a rule off. The audit lists what is disabled, and flags a change
  to this file for review. A person should own it, not the agent.
- **Your own rules:** `--rules FILE` (or `-Rules FILE`) loads another rule pack in the format
  documented at the top of `bin/rules.conf`.

## Limits

The audit matches text, one line at a time. It finds a useful share of leaked secrets, injection
shapes, swallowed errors, placeholder code, accessibility slips, and generic UI and copy. It cannot
see authorization, business logic, data flow across files, or whether a design is good. A clean
result is not a security verdict. Full scans in the PowerShell edition are about three times slower
than the shell edition; the diff modes are fast in both.
