# SELF-CRITIQUE & AUDIT MODE — score before you ship, or score someone else's build

Two uses of the same rubric:
- **Pre-emit self-critique** (during BUILD, Step 4 of the loop): score your own output *before*
  handing it back; anything below the bar triggers revision — you do not emit until it clears.
- **Audit mode** (verb `fixmyvibe audit <target>`): score an *existing* file/PR/page and return a
  ranked punch list. **Diagnosis only — make no edits.** This is how the skill reviews vibe-coded
  work without rewriting it.

Generalized from Hallmark's 6-axis design critique — but extended to cover **code** too, which no
design skill does.

---

## The scoring rubric (score each axis 1–5)

### Code axes
1. **Security** — secrets out of code, authz enforced, inputs validated, no injection, deps verified.
2. **Correctness** — unhappy paths handled, no fabricated APIs, resources bounded, runs + tests pass.
3. **Maintainability** — matches repo conventions, reuses existing utils, simplest-that-works, no
   dead/duplicated code, clean diff, `why` comments.
4. **Honesty** — did exactly what was asked (no scope creep); done vs drafted stated truthfully.

### Design axes (only if UI is produced)
5. **Hierarchy** — clear information priority; not uniform weight.
6. **Specificity** — distinctive; passes the logo test; no accepted default without a reason.
7. **Restraint** — no decoration/motion clutter; every element earns its place.
8. **Craft & completeness** — tokens, all states, accessibility (WCAG AA, keyboard, focus),
   responsive; real content, not filler/fake proof.

## The bar
- **Every applicable axis must be ≥ 4** to emit (or to call a task done). Any axis **≤ 3** → name the
  specific weakness, fix it, re-score. Do not average away a low axis with high ones.
- **Any hard-blocklist hit** (`FORBIDDEN-PATTERNS.md §A` security, or an un-justified §C slop tell)
  is an automatic fail regardless of scores.

## Stamp the scores (accountability beats good intentions)
Record the critique where the work lives, so choices are visible and revisable:
- Code: a short PR/commit note or a comment block — e.g.
  `// fixmyvibe: sec5 correct5 maint4 honest5 — ran tests(12/12), authz tested as 2nd user`.
- UI: a CSS comment stamp — e.g.
  `/* fixmyvibe: direction=Terminal-Core macro=Stat-Led | hier5 spec4 restraint5 craft4 */`.

Hiding your choices is what makes templated, happy-path output feel inevitable. Stating them keeps a
human able to challenge them.

---

## Audit-mode output format
When invoked as `audit`, return this — and nothing that edits the target:

```
FixMyVibe audit — <target>
Scores: security X/5 · correctness X/5 · maintainability X/5 · honesty X/5
        [hierarchy X/5 · specificity X/5 · restraint X/5 · craft X/5]   ← if UI
Verdict: PASS (all ≥4, no blocklist hit) | FAIL

Punch list (highest impact first):
1. [BLOCKER][security] Supabase service key hardcoded at src/api.ts:14 → move to server env.
2. [BLOCKER][slop] Inter-only + purple gradient hero → pick a direction (DESIGN-DIRECTIONS.md).
3. [major][correctness] No error/empty state on the results view → add both.
4. [minor][maintainability] Duplicate formatDate() at utils.ts:9 and helpers.ts:22 → dedupe.
```
Rank BLOCKER (blocklist hit) > major (axis ≤3) > minor (polish). Cite `file:line`. Recommend the
fix; let the human decide when to apply it. Applying fixes is a separate, explicit action.
