# Finish gate

Run this before you report on standard work and above. Every item needs evidence from this turn.
An item you cannot answer is a failure, not a pass. Fix it, then run the whole gate again.

## Gate 0: scope and tier
- [ ] The change does what was asked and nothing more.
- [ ] The tier is stated. For sensitive or critical work, the trust boundaries and the top abuse
      cases are written down (`RISK-PROFILES.md`).

## Gate 1: it runs
- [ ] The code ran this turn.
- [ ] Tests for the new behavior exist, with one edge case and one failure case, and pass now.
- [ ] Lint, format, and type checks pass where the project has them. No check was silenced to
      get there.

## Gate 2: the audit
- [ ] `bin/fixmyvibe-audit` ran with `--changed` and exited 0.
- [ ] Every warning is fixed or has a stated reason. Every suppression has a real reason.
- [ ] Exit 2 or `NOTHING SCANNED` was treated as a failure.

## Gate 3: security, by hand (the audit cannot see these)
- [ ] Every endpoint and query authorizes the caller. Tested as a second user where it matters.
- [ ] Every external input is validated on the server.
- [ ] Every new dependency was confirmed to exist and to be needed.
- [ ] No destructive operation runs without a backup and human approval.
- [ ] For sensitive and critical work, the checks chosen from `SECURITY-VERIFICATION.md` ran.
      A check that could not run is reported as not run.

## Gate 4: correctness
- [ ] Unhappy paths are handled: empty, invalid, error, timeout, unauthorized, duplicate.
- [ ] Resources are bounded: pagination, caps, timeouts.
- [ ] Every call and import resolves to something real.
- [ ] Nothing dead, duplicated, or stubbed is left behind without being named in the report.

## Gate 5: interface (only if UI changed)
- [ ] Every state the view can reach exists: empty, loading, error, success, zero results.
- [ ] Keyboard path walked. Focus is visible and not hidden behind sticky elements.
- [ ] Contrast meets WCAG AA. Inputs have labels, images have alt text, controls have names.
- [ ] No horizontal scroll at 320px. Works at 200% zoom. Reduced motion is honored.
- [ ] With the logo removed, the page could not be mistaken for a generator default.
- [ ] Values come from tokens.

## Gate 6: copy (only if user-facing text changed)
- [ ] Every metric, customer, testimonial, and capability claim is real and checked.
- [ ] Errors say what happened, what is safe, and what to do next.
- [ ] Destructive actions name their consequence on the button.

## Gate 7: AI features (only if a model, retrieval, or agent tool is involved)
- [ ] Model and retrieved output is treated as untrusted and cannot grant permission.
- [ ] Tools have least privilege, validated arguments, limits, and confirmation for
      consequential actions.
- [ ] An evaluation set with thresholds decided in advance was run (`AI-SYSTEMS.md`).

## Passing
All items pass: report in the format from `SKILL.md` section 4, naming what you ran and what you
did not verify. Any item fails: you are not done. Make the failure the next task, fix it, and run
the gate again. If you are blocked after two different approaches, give the user a focused
description of the blocker instead of trying a third time.

## Automating the mechanical part

```bash
bash bin/fixmyvibe-audit.sh --staged              # pre-commit: lines added in the index
bash bin/fixmyvibe-audit.sh --since origin/main   # CI: lines added on this branch
bash bin/fixmyvibe-audit.sh --format json src     # machine output, one finding per line
```

The PowerShell edition takes `-Staged`, `-Since origin/main`, and `-Format Json`. Agent hooks that
run the audit after each edit and before the agent stops are described in `adapters/`.

The audit is a heuristic text scan. It does not prove authorization, data flow, dependency
integrity, accessibility, truthful copy, or design quality. Gates 3 to 7 exist because of that.
