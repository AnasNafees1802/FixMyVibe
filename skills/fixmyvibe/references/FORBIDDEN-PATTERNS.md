# Forbidden patterns and review signals

These are concrete failure patterns and review signals. This is the checklist `FINISH-GATE.md` runs
against. Do not confuse a text match with proof: reachability, trust, framework behavior, and product
context decide whether a warning is a defect.

Format: 🚫 = confirmed occurrence blocks release; ⚠️ = inspect in context and record the disposition.
Do not waive 🚫 items. Do not mechanically rewrite ⚠️ items if the existing system has a sound reason.

---

## A. Insecure / unsafe code (never)

- 🚫 Hardcoded secret, API key, token, password, or connection string in source, client bundle, or
  logs. (regex smell: `sk-`, `AKIA`, `Bearer `, `password=`, `://user:pass@`)
- 🚫 SQL built by string concatenation / f-strings with user data. (Use parameters/ORM.)
- 🚫 `dangerouslySetInnerHTML` / `innerHTML` / `eval` / `v-html` with untrusted input. The sink alone
  is ⚠️ until its data flow is reviewed.
- 🚫 Shell command built by interpolating untrusted strings.
- 🚫 Endpoint or query that returns/edits a record without an authorization check (IDOR/BOLA).
- 🚫 Trusting a client-supplied user id, role, price, or permission.
- 🚫 `CORS: *`, public storage bucket, or `debug=true` / stack traces exposed in production.
- 🚫 Passwords stored plaintext or hashed with MD5/SHA1; home-rolled crypto.
- 🚫 Installing/importing a package name the model produced without confirming it exists and is the
  intended one (slopsquatting/hallucinated-dependency risk).
- 🚫 Destructive migration/`DROP`/mass-delete run automatically without backup + human approval.

## B. Fragile / dishonest code (never)

- 🚫 Empty `catch {}` / `except: pass` / swallowed errors.
- 🚫 Happy-path-only: no handling for null/empty/error/unauthorized/zero-results.
- 🚫 Unbounded list/loop/upload/query — no pagination, cap, timeout, or rate limit; N+1 queries.
- 🚫 Calling a function/flag/endpoint/import that doesn't actually exist ("confident wrongness").
- 🚫 Claiming "done"/"working" without having run the code and its tests this session.
- 🚫 Debug-by-regeneration: re-prompting until it passes instead of finding the root cause.
- 🚫 Leaving dead code, duplicated utilities, or commented-out blocks behind.
- ⚠️ Adding a dependency where the standard library / existing util would do (justify it).
- ⚠️ Introducing an abstraction/config/generic layer on first use (abstract on the 3rd repeat).
- ⚠️ Adding a feature/endpoint/setting the user didn't ask for (propose it instead of smuggling it).

## C. AI-slop visual review signals

- ⚠️ Shipping a UI whose only typeface is **Inter** / `system-ui` with no intentional type scale or
  brand reason. One family can be the right system; adding a display font is not automatically craft.
- ⚠️ **Purple/indigo → blue gradient** on hero, CTA, or background blobs as a default decoration
  (`violet-500`, `indigo-600`, `from-purple-500 to-blue-500`).
- ⚠️ The canned template: centered hero + subhead + two buttons → exactly three feature cards →
  testimonials → pricing → CTA footer, shipped without a content-driven reason.
- ⚠️ `rounded-2xl` + `shadow-lg` + uniform `p-6`/24px on every card with identical heights and no
  hierarchy.
- ⚠️ Untouched shadcn/ui (or any library) default components with no product-specific reason.
- ⚠️ Decorative glassmorphism / gradient "blob" background with no purpose.
- ⚠️ Stock "diverse team at laptops" photos or generic generated illustration with no product value.
- 🚫 Unreplaced placeholders or invented imagery presented as the real product.
- ⚠️ Filler copy: "Build the future of work", "Your all-in-one platform", "best-in-class",
  "cutting-edge", "may help you", emoji-bulleted feature lists.
- ⚠️ Uniform fade-in animation applied to everything, or buttons that snap with no easing.
- ⚠️ Repeated hard-coded color/spacing in components instead of shared design tokens.

## C2. Named fingerprints & structural tells (forbidden by default; deliberate reason only)

The "distinctive" defaults that have themselves become averages, plus high-reliability AI tells:
- 🚫 **Invented metrics / fake social proof** — "+47% conversion", "trusted by 50,000+ teams",
  fabricated logos — without real user data. Use a placeholder (`— metric to confirm`) or a
  different macrostructure.
- ⚠️ **Italic headings** used as a default “editorial” shortcut. Keep them when typography and brand
  make the choice deliberate and readable.
- 🚫 **Redrawn UI chrome** — fake browser bars, fake code windows, fake phone frames. Use a real
  screenshot or omit it.
- 🚫 **Bare `1fr` grid tracks** for image/card grids — use `minmax(0, 1fr)` (prevents blowout).
- 🚫 **`overflow-x: hidden`** on html/body as a scroll-hider — use `overflow-x: clip`.
- 🚫 **Two-line clickable text** — buttons/nav/CTA must wrap long words
  (`overflow-wrap: anywhere; min-width: 0`), not break the layout.
- 🚫 **Inline color/font values mid-render** (`oklch(...)`, `#hex`, `font-family:"Some Font"`) that
  bypass the token block — lift new values into `:root` first.
- ⚠️ **Tag-left / heading-right** hanging-label two-column header — the single most reliable
  templated-editorial tell. Prefer a vertical stack (tag above, heading below).
- ⚠️ **teal/cyan `#16d5e6` accent**, **animated "live"/AI status dots**, **4px decorative left-rule
  on every card**, **three-column feature grid in the hero**, **untouched Lucide icon set**,
  **serif-headline+sans-body** as a thoughtless brand mimic — each only with a stated design reason.
- ⚠️ **Raw `ease`/bounce easings** — use three named easings (`--ease-out/-in/-in-out`) and animate
  only `transform`/`opacity`.

## D. Missing-craft omissions (never ship without)

- 🚫 A view without its **empty / loading / error** states.
- 🚫 A form without inline validation feedback and a pending/disabled submit state.
- 🚫 `outline: none` (or removed focus ring) with no visible replacement.
- 🚫 Non-semantic `<div>` soup where a `<button>`/`<nav>`/`<main>`/heading belongs.
- 🚫 Text/UI below WCAG AA contrast (4.5:1 / 3:1).
- 🚫 Interactive element not reachable or operable by keyboard.
- 🚫 Input without an associated label; image without alt; icon-button without an accessible name.
- 🚫 Animation with no `prefers-reduced-motion` fallback.
- 🚫 Layout that causes horizontal scroll on the page body / breaks on mobile.

## E. Generated content failures

- 🚫 Invented metric, testimonial, customer, integration, award, citation, urgency, or scarcity.
- 🚫 A factual claim presented as verified when its source was not checked.
- 🚫 A destructive-action label that hides the consequence behind “Continue,” “Confirm,” or “OK.”
- ⚠️ Generic hype, stock openings, repeated summary, symmetrical prompt-shaped phrasing, rule-of-three
  padding, emoji decoration, or a heading written as a rhetorical question.
- ⚠️ Copy that could be pasted into a competitor unchanged because it names no real capability,
  constraint, audience, or action.

---

**How to use this list:** before declaring done, scan your diff against every 🚫 and ⚠️. For each
⚠️ you kept, write one line justifying it. For every 🚫 present, fix it — there is no justification.
This is a binary gate: one un-fixed 🚫 means the task is **not done**.
