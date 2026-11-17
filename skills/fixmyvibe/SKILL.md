---
name: fixmyvibe
description: >-
  Engineering and design standard for AI coding agents, with a runnable audit gate. Use when
  writing, changing, or reviewing code, building or styling a UI, writing user-facing copy, or
  adding an AI feature, and whenever the user asks for production-ready work, a code or security
  review, an audit of AI-generated code, or a landing page, dashboard, form, or component. Covers
  secrets, authorization, injection, error handling, tests, accessibility, design that is not the
  generic AI default, and proof before claiming done. Not for explanations that neither inspect
  nor change a project.
license: MIT
---

# FixMyVibe

A model writes the most likely continuation. In code, the most likely continuation is the happy
path with the common shortcut. In UI, it is the template every other model also produces. This
skill replaces those defaults with choices you can defend and evidence you can show.

Three rules hold for every task:

1. **Read before you write.** Match what the project already does.
2. **Choose on purpose.** A default you took without a reason is a defect.
3. **Prove it before you say done.** Done is something you ran, not something you expect.

## 1. Size the work first

Pick the highest tier that applies. The tier sets how much process the task gets.

| Tier | Applies when | Required |
|---|---|---|
| Quick | Typo, rename, copy tweak, or a one-line fix that adds no input, data flow, or UI state | The three rules, the affected test, the audit |
| Standard | Anything else: a feature, a component, a refactor, a bug fix | The full loop in section 2 |
| Sensitive | Auth, permissions, money, personal data, uploads, parsers, outbound requests, crypto, migrations, new dependencies, agent tools | Standard, plus written abuse cases before code and `references/RISK-PROFILES.md` |
| Critical | Safety, health, finance, identity, destructive operations, production access, tenant isolation, agents that take consequential actions | Sensitive, plus stop for human review before anything deploys |

A small diff is not a low-risk change. A one-line authorization mistake is critical. When unsure,
go up a tier.

## 2. The loop

**Read**
- State what exists, with `file:line`: stack, package manager, test and lint commands, how errors
  and names are handled. For UI: design tokens, type scale, component library.
- Restate the request in one sentence. If an ambiguity would change the result, ask one question.
  Otherwise state your assumption and continue.
- Search for an existing helper before writing a new one. If a design system exists, follow it.

**Plan**
- Name the simplest change that fully works. No abstraction before the third use. Do not add
  features nobody asked for; propose them instead.
- Match the project's stack. On a new project, pick a stack for this problem and give the reason
  in one line.
- Before installing a dependency, confirm the package exists and is the one you mean
  (`references/CODE-CRAFT.md` has the commands). Models invent package names.
- For UI, state the direction, the page structure, and the three dials before writing markup, then
  check that plan against the brief once (`references/DESIGN-DIRECTIONS.md`).
- Decide what will prove the change: the test for the new behavior, one failure case, and for
  sensitive work the abuse case.

**Build**
- Handle the unhappy paths as you write each piece: invalid input, empty result, error, timeout,
  unauthorized caller, duplicate request.
- For UI, build every state the view can be in (empty, loading, error, success), keyboard access,
  and visible focus. Read values from tokens.
- Delete what you replace. If something is a stub or uses mock data, the report must say so.

**Prove**
- Run the code and the tests now. Results from earlier in the session do not count.
- Run the audit (section 3) and resolve what it reports.
- Report with evidence (section 4).

## 3. Run the audit

The audit lives in `bin/` beside this file. Run it from the project root:

```bash
bash <this-skill-dir>/bin/fixmyvibe-audit.sh --changed
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <this-skill-dir>\bin\fixmyvibe-audit.ps1 -Changed
```

- `--changed` scans the lines you added since the last commit, plus new files. That is your work,
  not the project's legacy code. Pass a path instead to scan whole files (audit mode). Use
  `--staged` in a pre-commit hook and `--since origin/main` in CI.
- Exit 0 means no blockers. Exit 1 means blockers. Exit 2 means the scan did not complete, which
  is a failed gate. `NOTHING SCANNED` is not a pass either.
- **BLOCKER:** fix it. If it is a false positive, append `fixmyvibe: allow RULE-ID reason` in a
  comment on that line. The reason is required and the suppression stays visible in every report.
- **WARNING:** fix it, or say in your report why it stays.
- Do not edit `.fixmyvibeignore`, disable a rule, or reshape code only to slip past a pattern
  (splitting a string, renaming a variable). Those need the user's approval. Tell the user what
  the audit found and why you think it is wrong.

The audit is a text scan. It catches a useful set of leaked secrets, injection shapes, request
input reaching files, redirects and templates, weak configuration, swallowed errors, accessibility
slips, placeholder code, and generic UI and copy. It cannot see authorization logic, business
rules, contrast, missing states, or whether a design is good. A clean audit is required and never sufficient.

## 4. Report with evidence

End every task with a short report in this shape:

```
Done: signup form posts to /api/signup and shows inline errors.
Tier: sensitive (collects email)
Ran: npm test (14 passed, 0 failed), audit --changed (0 blockers, 1 warning)
Kept: UX008 on the theme toggle, it animates two properties on one icon
Not verified: Safari, screen reader
```

| Claim | Evidence it needs | Not evidence |
|---|---|---|
| Tests pass | The test command's output from this turn, zero failures | An earlier run, "should pass" |
| It works | You ran it and saw the behavior | It compiles, the code looks right |
| Bug fixed | The original reproduction now passes | The code changed |
| Accessible | A keyboard pass, and the checks you ran by name | It looks fine |
| Secure | Never claim it. Name the checks you ran and what they cannot see | A clean audit |

If something failed or was not run, say so in plain words. Drafted is not done.

## 5. Red flags

Each of these thoughts means stop and do the thing in the right column.

| Thought | Do this instead |
|---|---|
| "This is too small for the gate." | The Quick tier still runs the affected test and the audit. |
| "I'll add error handling and tests afterwards." | Write them now. Afterwards does not arrive. |
| "The audit is wrong, I'll reword the code to get past it." | Annotate with a reason, or tell the user. |
| "It should work." | Run it. |
| "I'll hardcode or mock this for now." | Allowed only if the report says so in plain words. |
| "The user wants speed, so skip verification." | Speed comes from a smaller scope, not from skipped proof. |
| "The failing test is unrelated." | Show the failure. Do not skip or delete the test. |
| "A purple gradient, Inter and three cards will do." | That is a default taken without a reason. Choose. |
| "I checked that earlier." | Evidence comes from this turn. |

## 6. Modes

- **build** (default): the loop above.
- **audit `<target>`**: review existing work without editing it. Run the audit on the target path,
  then review by hand with `references/SELF-CRITIQUE.md`. Return ranked findings, each with
  `file:line` and the input or situation that makes it fail.
- **review**: apply the Prove step to your own pending diff before handing it back.
- **fix `<target>`**: repair existing work. Run the audit on the target path and review by hand as
  in audit mode, then fix in this order: blockers, findings from the hand review, warnings. Fix
  the cause, never the pattern: a suppression or a reworded line is not a fix. Rerun the tests and
  the audit after each batch. Stop and ask before any change that alters behavior the user did not
  mention, such as adding authentication to a route. Report what was fixed, what was kept and why,
  and what the audit cannot see.

## 7. References

Load a reference when the task needs it, not before.

| File | Load when |
|---|---|
| `references/CODE-CRAFT.md` | Writing or reviewing code |
| `references/RISK-PROFILES.md` | The tier is sensitive or critical, or the system type is unfamiliar |
| `references/SECURITY-VERIFICATION.md` | Choosing checks for sensitive work, triaging a finding |
| `references/UI-CRAFT.md` | Building or reviewing interface |
| `references/DESIGN-DIRECTIONS.md` | Starting a new page, screen, or visual system |
| `references/CONTENT-CRAFT.md` | Writing or editing copy that ships to users |
| `references/AI-SYSTEMS.md` | The product calls a model, retrieves documents, or gives an agent tools |
| `references/FORBIDDEN-PATTERNS.md` | The Prove step, and audit mode |
| `references/FINISH-GATE.md` | The Prove step on standard work and above |
| `references/SELF-CRITIQUE.md` | Audit mode and review mode |
| `adapters/` | Wiring the audit into an agent as an edit hook or a stop hook |

With Perpetua, make "the FixMyVibe gate is green" part of the mission's definition of done.
