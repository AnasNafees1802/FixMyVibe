# FINISH-GATE — verify before you claim done

The single rule that makes this skill real: **you may not report success until this gate passes,
run fresh.** Not remembered results — run them *now*. A model's instinct is to declare victory on
the happy path; this gate is the discipline that overrides that instinct. It pairs directly with
Perpetua's Stop-guard: while the gate is red, the mission's Definition of Done is unmet.

> If any item is ❌ or "unsure", the task is **NOT DONE**. Log the specific failure, make it the
> next action, fix it, and re-run the *entire* gate. Never report success on a red gate. Never
> soften a ❌ into a "mostly done."

---

## Gate 0 — Scope, honesty & scored self-critique
- [ ] I did exactly what was asked — no silent scope creep, no unrequested features.
- [ ] I can state what I ran and what passed. Anything unverified is labeled unverified.
- [ ] I selected the risk tier and every applicable profile from `RISK-PROFILES.md`; for sensitive
      or critical work I recorded trust boundaries and top abuse cases.
- [ ] I scored the work with `SELF-CRITIQUE.md`; **every applicable axis is ≥4** (security,
      correctness, maintainability, honesty plus applicable design/content/AI-system axes);
      no axis averaged away; scores stamped where the work lives.

## Gate 1 — It actually runs (evidence, not vibes)
- [ ] I executed the code this session; it runs.
- [ ] Tests exist for the new behavior (incl. ≥1 edge case + ≥1 failure case) and **pass now**.
- [ ] Lint/format/typecheck (if the project has them) pass.

## Gate 2 — Security scan (against FORBIDDEN-PATTERNS §A)
- [ ] No secret in source, client bundle, or logs (grepped the diff).
- [ ] Every query parameterized; no injection sink on untrusted input.
- [ ] Every endpoint/query authorizes the caller; tested that user A can't touch user B's data.
- [ ] Every external input validated + sanitized server-side.
- [ ] Every new dependency verified to exist, be correct, and be necessary.
- [ ] No destructive/data-losing operation runs without backup + human approval (Perpetua guardrail).
- [ ] I selected and ran risk-appropriate layers from `SECURITY-VERIFICATION.md`; scanner errors or
      skipped required checks are failures, not clean results.
- [ ] For sensitive/critical changes, confirmed findings have regression tests and residual risk has
      an owner, reason, and verification or review path.

## Gate 3 — Robustness (against FORBIDDEN-PATTERNS §B)
- [ ] No swallowed errors; unhappy paths handled (null/empty/error/unauthorized/zero).
- [ ] Resources bounded (pagination, caps, timeouts, no N+1).
- [ ] No fabricated APIs; every call/import resolves to something real.
- [ ] No dead/duplicated code left; reused existing patterns/utilities.

## Gate 4 — Design (only if UI was produced; against FORBIDDEN-PATTERNS §C & §D)
- [ ] **Logo test:** with branding stripped, this is *not* mistakable for a v0/Lovable default.
- [ ] No un-justified slop tell (Inter-only, purple gradient, canned hero+3-cards, uniform
      rounded-2xl/shadow, untouched shadcn, glassmorphism blob, stock photo, filler copy).
- [ ] Components read from shared design tokens; it reads as one intentional system.
- [ ] Every state present: empty / loading / error / success / zero-results; forms give feedback.
- [ ] Accessibility: semantic HTML, WCAG AA contrast, keyboard-operable, visible focus, labels/alt,
      reduced-motion honored.
- [ ] Responsive: no body horizontal scroll; works at mobile/tablet/desktop.
- [ ] WCAG 2.2 checks include unobscured focus, zoom/reflow, target size, error identification, and
      accessible authentication where applicable; keyboard path was checked manually.

## Gate 4B — Content (only if user-facing prose was produced)
- [ ] Every metric, customer, testimonial, integration, citation, and capability claim is verified.
- [ ] Copy names the real product behavior, audience, action, and consequence; no filler or fake urgency.
- [ ] Errors and destructive actions say what happened, what remains safe, and what the user can do.
- [ ] I ran the read-aloud and product-specificity checks in `CONTENT-CRAFT.md`.

## Gate 4C — AI systems (only if models, retrieval, embeddings, or agent tools are involved)
- [ ] Model/retrieved/tool output is untrusted and cannot grant permission or flow raw into a sink.
- [ ] Tools use least privilege, typed/validated arguments, bounds, audit logs, and fresh confirmation
      for consequential actions.
- [ ] Tenant isolation, privacy, retention, prompt injection, failure, cost, and recovery were tested.
- [ ] Versioned evaluations passed predeclared thresholds; model/prompt/data versions and limits recorded.

## Gate 5 — The maintainer test
- [ ] A stranger (or you at 3am) could read this, understand *why*, and safely extend it.
- [ ] Comments explain non-obvious *why*; the tree is clean.

---

## Passing the gate
- **All green** → report done **with evidence**: what you ran, what passed, and one line on each
  deliberate ⚠️ you kept. If under Perpetua, mark the criterion/mission complete only now.
- **Any red** → not done. Append the failure to the ledger/todos as the next task, fix it, re-run
  the whole gate. Repeat until green or, if truly blocked past your breaker count, escalate a
  focused blocker to the human (don't spin).

### Minimal automatable slice (wire into CI / a script where possible)
```bash
# 1) FixMyVibe's own executable gate — greps the diff for the security + slop blocklist, exits 1 on a blocker
bash bin/fixmyvibe-audit.sh --staged            # or: pwsh bin/fixmyvibe-audit.ps1 -Staged
# 2) the rest, adapted to the stack
run tests            # Gate 1
lint + typecheck     # Gate 1
secret scan diff     # Gate 2 (gitleaks/trufflehog complements the audit's high-entropy grep)
a11y check on UI     # Gate 4 (axe/pa11y/Lighthouse); visual-regression via Playwright if available
```
`bin/fixmyvibe-audit.*` scans only added lines in staged mode. Exit 1 means a blocker (or a warning
under strict mode); exit 2 means the scan failed and the gate is incomplete. The PowerShell edition
also supports JSON output for CI. Obvious placeholder values are suppressed narrowly, but test and
example files are not globally exempt because real credentials leak there too.

This is a heuristic text scan, not a parser or a security verdict. It cannot prove authorization,
safe data flow, dependency integrity, accessibility, content truth, or design quality. Use the risk
profiles, stack-native tools, tests, and manual checks above.
