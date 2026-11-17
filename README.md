# FixMyVibe

A skill for AI coding agents, plus an audit you can run without one. The skill tells the agent how
to size a task, what to check, and what evidence to show before it says done. The audit is a
dependency-free scan that catches the common ways generated code, UI, and copy go wrong, and it
can run as a hook so the agent cannot skip it.

Works with Claude Code, Codex, Cursor, Gemini CLI, and Antigravity. MIT licensed.

## What you get

| Part | What it does |
|---|---|
| `SKILL.md` | Sizes the work into four tiers, runs a read, plan, build, prove loop, and requires a report with evidence |
| `references/` | Ten on-demand references: code, UI, design directions, copy, AI features, risk profiles, security checks, the finish gate, the review method, the pattern catalog |
| `bin/fixmyvibe-audit` | 101 rules over secrets, injection, request input reaching files, redirects and templates, weak configuration, swallowed errors, placeholder code, test gaming, accessibility, generic UI, and generated copy. Bash and PowerShell editions read one rule pack |
| Hook mode | Runs the audit after each edit and before the agent stops. Blocks on blockers, once per stop |
| `tests/`, `evals/` | A labeled corpus both editions must agree on, behavior tests, and two agent evals |

## Install

```bash
npx skills add AnasNafees1802/FixMyVibe -g
```

Or clone and run `skills/fixmyvibe/install.ps1` (Windows) or `skills/fixmyvibe/install.sh`. Details
and the one-line bootstrap are in [`skills/fixmyvibe/INSTALL.md`](skills/fixmyvibe/INSTALL.md).

Then, in a new agent session:

```text
/fixmyvibe audit .      report what is wrong, change nothing
/fixmyvibe fix .        repair it: blockers first, then review findings, then warnings
```

## What the audit checks

| Family | Rules | Examples |
|---|---|---|
| Secrets | 11 | Provider keys, private keys, hardcoded passwords, `.env` in git, a literal JWT signing secret |
| Injection and request input | 15 | SQL built from strings, `eval`, request input reaching a file path, a redirect, a template, or a server-side fetch |
| Weak configuration | 21 | TLS or CSRF turned off, open CORS, open database rules, secrets in logs, stack traces sent to clients |
| Correctness and honesty | 15 | Swallowed errors, placeholder code, tests that cannot fail, silenced checks, comments that narrate the edit |
| Interface | 21 | Missing alt text and labels, icon buttons with no name, blocked zoom or paste, `100vh` layouts, layout-property transitions |
| Generic UI | 8 | Default purple gradient, glass panels, hover lift on every card, gradient headline text |
| Copy | 9 | Lorem ipsum, hype phrases, invented metrics, chat replies left in files, "Something went wrong" |
| AI features | 1 | User text placed in the system prompt |

Most rules are warnings to review. Blockers are kept for matches that are close to proof on one
line. The full catalog with the fix for each is in
[`FORBIDDEN-PATTERNS.md`](skills/fixmyvibe/references/FORBIDDEN-PATTERNS.md).

## The audit on its own

```bash
bash skills/fixmyvibe/bin/fixmyvibe-audit.sh --changed     # what you added since the last commit
bash skills/fixmyvibe/bin/fixmyvibe-audit.sh src           # whole files
```

```powershell
./skills/fixmyvibe/bin/fixmyvibe-audit.ps1 -Changed
```

Sample output:

```text
== FixMyVibe audit: 7 files ==
BLOCKER SEC007 src/auth.js:3  secret with a hardcoded fallback: fail at startup when the variable is missing instead
        (excerpt withheld so the secret is not copied into logs)
BLOCKER SEC101 src/server.js:23  SQL built with template interpolation: use bound parameters
        const rows = await db.query(`SELECT * FROM users WHERE email = '${email}' ...
WARNING SEC205 public/app.js:12  auth secret in web storage is readable by any script on the page: prefer an HttpOnly cookie
----------------------------------------
FAIL: 12 blocker(s), 14 warning(s), 0 suppression(s). Fix the blockers, then run the audit again.
```

Exit 0 means no blockers, 1 means blockers, 2 means the scan did not complete. Secret values are
never echoed. A false positive is silenced on its own line with `fixmyvibe: allow RULE-ID reason`,
and stays listed in every report.

## Make it mandatory

Instructions can be skipped. A hook cannot. For Claude Code, add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [{ "matcher": "Edit|Write|MultiEdit", "hooks": [{ "type": "command", "command": "bash \"$HOME/.claude/skills/fixmyvibe/bin/fixmyvibe-audit.sh\" --hook edit" }] }],
    "Stop": [{ "hooks": [{ "type": "command", "command": "bash \"$HOME/.claude/skills/fixmyvibe/bin/fixmyvibe-audit.sh\" --hook stop" }] }]
  }
}
```

Other agents, Windows without Git Bash, pre-commit, and CI are covered in
[`skills/fixmyvibe/adapters/`](skills/fixmyvibe/adapters/).

## Measured, not claimed

Everything in this section was run between 2026-11-16 and 2026-11-17 on Windows 11 with Git Bash and
Windows PowerShell 5.1. The scripts are in `tests/` and `evals/`.

**The two editions agree.** 421 labeled corpus lines cover every rule with at least one line that
must fire and one that must not. Both editions pass all of them and report the same 240 findings
on the corpus. On five public repositories (Express, Flask, a Next.js app, and two deliberately
vulnerable apps) they reported identical findings, line for line.

**Fewer false alarms, more real catches, compared with the previous version of this audit.**

| Check | Previous audit | This audit |
|---|---|---|
| Seeded defects caught by the scan, of 16, in `evals/fixtures/audit-shipfast` | 6 | 13 |
| Blockers reported on Express (216 files, mature code) | not measured | 0 |
| SQL injection in the vulnerable Flask app `dvpwa` | not measured | caught |
| `eval` on request input in OWASP NodeGoat | not measured | caught |
| Full scan of this repository, shell edition | 15.7 s | about 3 s |
| Scan of a small change (the hook path), shell edition | 4.8 s for 15 files | about 1.3 s |

The three seeded defects the scan cannot catch are a missing ownership check, an unauthenticated
webhook, and an unbounded query. Those need a reader, which is what the skill's review method is
for. The thirteenth catch (a stack trace sent to clients) comes from a rule written after looking
at this fixture, so count it as a regression test, not as an independent result.

**What the skill changes in agent behavior.** See [`evals/README.md`](evals/README.md) for the
method, every number, and the limits of a small eval.

## Limits

- The audit matches text one line at a time. It cannot see authorization, business logic, or data
  flow across files. A clean result is not a security verdict.
- Full scans in the PowerShell edition take about three times as long as the shell edition (8 to
  16 seconds on a 200-file repository here). The diff modes take about 2 seconds in both.
- Hook mode is tested against the Claude Code event format. Codex uses the same shape but was not
  run here. No hook configuration is published for Gemini CLI, Cursor native hooks, or Antigravity.
- The CI workflow in `.github/workflows/test.yml` covers Linux and macOS, but it has not run yet.
  Only Windows results exist so far.

## Repository layout

```text
skills/fixmyvibe/     the installable skill (SKILL.md, references, bin, adapters, installers)
tests/                corpus.txt, run.sh, run.ps1
evals/                evals.json, fixtures, grade-build.sh, results
research/             notes on the problem and on other skills
```

Run the tests:

```bash
bash tests/run.sh
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run.ps1
```

## License

MIT. See [`LICENSE`](LICENSE).
