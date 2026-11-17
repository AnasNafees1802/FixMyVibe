# Evals

Two tasks, each run by a fresh agent in an isolated copy of a fixture project, under three
conditions: no skill, the previous FixMyVibe (commit 2c20608), and this version. Each cell was run
once on Claude Fable 5.2 and once on Claude Haiku 5.5, on 2026-11-16 and 2026-11-17. The tasks,
fixtures, and assertions are in `evals.json` and `fixtures/`.

One run per cell is a small sample. Read the tables as what happened in twelve runs, not as a
measured effect size.

## Task 1: review a flawed project (`audit-shipfast`)

The fixture has 16 seeded defects. The agent is asked what is wrong before shipping and told not
to change files. Scored out of 18: one point per seeded defect found, one for giving file and line
on at least 12 findings, one for leaving the files untouched.

| Model | No skill | Previous skill | This skill |
|---|---|---|---|
| Fable 5.2 | 18 | 18 | 18 |
| Haiku 5.5 | 16 | 17 | 17 |

Haiku without a skill skipped the stylesheet and reported no accessibility defects and no open
CORS. With either skill it ran the audit, which surfaced them. Both skill runs described the events
query as a data leak but did not call out the missing limit, which is the point they lost.

Tokens used by the agent, Fable: 70k without a skill, 109k with the previous skill, 87k with this
one. Haiku: 69k, 88k, 78k.

What differs is the shape of the report. With this skill, each finding states a trigger and a
consequence, and the report ends with what could not be confirmed and what was not reviewed. The
previous skill produced 1 to 5 scores instead.

**The scan alone, no agent.** Run on the same fixture, the previous audit flags 6 of the 16 seeded
defects and this audit flags 13. The 3 it cannot see are a missing ownership check, an
unauthenticated webhook, and an unbounded query. The rule for the thirteenth (a stack trace sent
to clients) was written after looking at this fixture. The agent runs in the tables above used the
earlier 58-rule pack, which flagged 12; they were not repeated with the current 101-rule pack.

## Task 2: build a feature (`build-signup`)

The request is deliberately loose: add a newsletter signup and an admin page that lists
subscribers, and make it look good. The traps are an existing email validator, an existing body
reader with a size cap, a parameterized database helper, design tokens, and an admin page nobody
said to protect. `grade-build.sh` checks the result mechanically and starts the server to see
whether the admin data is readable without a credential.

| Check | Fable, none | Fable, previous | Fable, this | Haiku, none | Haiku, previous | Haiku, this |
|---|---|---|---|---|---|---|
| Tests pass (count) | yes (7) | yes (13) | yes (12) | yes (8) | yes (10) | yes (11) |
| Failure-case assertions in tests | 1 | 7 | 4 | 4 | 4 | 5 |
| Reuses `isEmail` and `readJsonBody` | yes | yes | yes | yes | yes | yes |
| SQL parameterized, duplicates handled | yes | yes | yes | yes | yes | yes |
| Admin data refused without a credential | yes | yes | yes | yes | yes | yes |
| No new color values outside the tokens | yes | yes | yes | yes | yes | yes |
| `fixmyvibe-audit --changed` blockers | 0 | 0 | 0 | 0 | 0 | 0 |
| Report says what was not verified | yes | yes | yes | partly | yes | yes |

Every run passed every scripted check, including the two with no skill. On these models and this
fixture the baseline is already at the ceiling, so this eval does not show the skill improving the
built result.

Two things did differ:

- **Dodging the scanner.** The Haiku run with the previous skill hit a blocker on a test password
  and rewrote the test to generate the value at runtime so the scan would pass. This version tells
  the agent to annotate the line with a reason or tell the user instead. No run with this version
  reshaped code to get past a rule.
- **Collateral damage.** The Haiku run without a skill stopped its test server with
  `taskkill /F /IM node.exe`, which kills every Node process on the machine, and said so in its
  report. Neither skill version addresses this, and it is outside what the audit checks.

## What this says

- A strong model follows most of this standard without being told. The instructions in `SKILL.md`
  add the most where the model is weaker or the task is larger than these fixtures.
- The part that does not depend on the model is the audit. It doubled what the scan catches on the
  review fixture, and as a hook it runs whether or not the agent remembers.
- The fixtures are too easy to separate the conditions. Harder ones are the next step: a larger
  codebase, a longer task, a prompt that pushes for speed, and several runs per cell.

## Run it yourself

1. Copy a fixture to a scratch folder and commit it as a baseline (`git init`, `git add -A`,
   `git commit`).
2. Give an agent the prompt from `evals.json`, with or without the skill loaded.
3. For the build task, grade with `bash evals/grade-build.sh <run-folder>`. For the review task,
   check the agent's findings against the assertions in `evals.json`.
