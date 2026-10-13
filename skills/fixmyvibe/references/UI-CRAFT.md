# UI-CRAFT — the design standard (anti-slop)

AI UI looks the same because the model outputs the **average of every template** it trained on
("distributional convergence"). The fix is not a better template — a shared template is just the
next monoculture. The fix is a **method**: derive a design system for *this* project, then build to
it, with every state and accessibility handled. This is how you beat theme-locked tools.

> **Adopt the designer persona.** You are a product designer with taste who has shipped real
> interfaces. You would be embarrassed to ship something indistinguishable from a v0 default. Your
> north star: *would a discerning user be able to tell a human with judgment made this?*

---

## Step 1 — Derive the design system BEFORE writing any component

Never start from the shadcn/Tailwind default look. Spend the first move deciding, and write these
into the project (e.g. `design-tokens.css` / a tokens file) so every component reads from them:

1. **Brand personality — pick 3 adjectives.** (e.g. "precise, calm, editorial" or "playful, bold,
   tactile".) Every later choice must serve these. Vague prompt? Infer from the product's domain and
   audience, or ask one question. This single step is what breaks the average.
2. **Type system with clear roles.** Choose display and body treatments that fit the product. They
   may use one family or more; do not add a font merely to appear distinctive. Define an intentional
   scale, line-heights, weights, fallbacks, and loading behavior. Preserve an established brand face.
3. **Color as semantic tokens, applied by meaning.** Define CSS custom properties named by role, not
   by look: `--color-action-primary`, `--color-surface`, `--color-feedback-danger`,
   `--color-text-muted`. **Never** `--gradient-start`. Choose a real palette with intent (a
   considered accent, neutrals with a temperature, functional success/warn/danger). Color signals
   state/mode — it is not decoration.
4. **Spacing & radius scale.** One spacing scale (e.g. 4px base) used consistently; a deliberate
   radius (not `rounded-2xl` on literally everything); shadows used sparingly and purposefully.
5. **Motion rules (3 jobs only).** Motion may (a) signal a state change, (b) direct attention, or
   (c) express brand — nothing else. Ease, don't snap. Respect `prefers-reduced-motion`. Delete
   decorative fade-ins.

Commit these tokens first. Then **every component consumes tokens** — no hard-coded hex, no one-off
spacing. This is the mechanism that makes the whole UI feel like one intentional system.

Do not judge craft from one isolated choice. Inter, a gradient, a card, or a centered heading can
all be correct. The stronger signal is a **combined fingerprint**: several unexamined defaults
appearing together with no connection to the product, audience, content, or existing brand. Review
the system as a whole before replacing any individual style.

## Step 2 — Build real, not template

- **Real content, real hierarchy.** No lorem, no "Build the future of work" filler, no
  "best-in-class" superlatives, no hedging ("may help you"). Write copy a founder would actually say
  — specific and opinionated (see Basecamp, Superhuman, Linear for voice). Establish a clear visual
  hierarchy; not every element gets the same weight.
- **Real imagery.** Product screenshots, real data, real photos — not stock "diverse team at
  laptops," not too-smooth AI illustrations, not unreplaced placeholders.
- **Layout with intent.** Don't reflexively ship centered-hero → 3 feature cards → testimonials →
  pricing → CTA. Choose a structure that fits the actual content and the brand adjectives. Vary card
  sizes/shapes to express hierarchy; asymmetry and whitespace are tools.
- **Customize components.** If you use a component library, restyle it through your tokens so it
  stops looking like the default. Untouched shadcn defaults are a tell.

## Step 3 — Every state, always (this is where "looks done" ≠ "is done")

For every view and component, design and implement:
- **Empty** (no data yet — with a helpful next action), **Loading** (skeleton/spinner with layout
  stability, no jank), **Error** (what happened + how to recover), **Success/confirmation**,
  **Zero-results** (search returned nothing), and **Offline/failed-fetch** where relevant.
- **Forms:** inline validation with clear messages, disabled/pending states on submit, focus
  management, don't clear the user's input on error.

Use this component pass for every changed surface:

| Surface | Required review |
|---|---|
| Navigation | Current location, keyboard order, collapsed behavior, overflow, and skip path |
| Forms | Persistent label, instructions, validation, pending state, recovery, and preserved input |
| Search and filters | Initial, typing, loading, results, zero results, clear/reset, and failed request |
| Cards and lists | Real hierarchy, long content, missing media, selection, and disabled actions |
| Tables and data grids | Header associations, sorting state, keyboard access, overflow, empty data, and pagination |
| Charts | Text alternative, legend clarity, non-color distinction, empty data, and exact values where needed |
| Dialogs and drawers | Accessible name, initial focus, focus trap, Escape behavior, and focus return |
| Toasts and live updates | Appropriate live region, enough reading time, no critical action only in a toast |
| Uploads and destructive actions | Constraints, progress, cancellation, failure recovery, and explicit consequence |
| Empty, loading, error, and offline views | Stable layout, useful explanation, safe retry, and one clear next action |

## Step 4 — Accessibility is a gate, not a nice-to-have

- **Semantic HTML** first (`<button>`, `<nav>`, `<main>`, headings in order) — not `<div>` soup.
- **Contrast** meets WCAG AA (4.5:1 text / 3:1 large & UI). Check it; the slop palette often fails.
- **Keyboard**: everything operable without a mouse; logical tab order; **visible focus states**
  that are not obscured by sticky UI (never `outline: none` with no replacement).
- **Labels & names**: every input has a label; icons/controls have accessible names; images have
  alt; use `aria-*` only where semantics don't already cover it.
- **Dialogs and dynamic updates**: move focus into a modal, contain it while open, return it to the
  trigger on close, and announce meaningful asynchronous changes without flooding assistive tech.
- **Tables and charts**: preserve programmatic headers and relationships; provide a textual route
  to information that color, position, or hover alone would otherwise carry.
- **Motion**: honor `prefers-reduced-motion`. **Targets**: adequately sized/spaced for touch.
- **Zoom, reflow, and text spacing**: core content and actions survive 200% zoom, narrow reflow, and
  user text-spacing overrides. Do not lock orientation without a product requirement.
- **Authentication and errors**: do not require memory/puzzles without an accessible alternative;
  identify errors in text, move focus deliberately, and announce asynchronous status changes.
- Automated accessibility checks are a floor. Also traverse the changed flow by keyboard and spot
  check it with a screen reader at the risk level appropriate to the product.

## Step 5 — Responsive & real-device

- Design mobile-first; test at 320, 375, 768, and a representative large viewport, plus 200% zoom.
  No fixed pixel widths that overflow. No horizontal scroll on the page body. Tables/wide content
  scroll inside their own named/focusable container when keyboard access requires it.

---

## The anti-slop mental test (run before you ship UI)
1. If I stripped the logo, could this be told apart from a v0/Lovable default? If no → not done.
2. Is there a single default I accepted without a reason (Inter, purple gradient, `rounded-2xl`
   everywhere, centered hero + 3 cards, glassmorphism blob)? → replace it with a deliberate choice.
3. Does every interactive state exist (empty/loading/error/success/zero)? 
4. Would it pass a WCAG AA + keyboard-only pass?
5. Is the copy specific and human, or generic aspirational filler?
6. Do all components read from shared tokens, so it reads as one system?
7. Did I review each changed component in its real context instead of applying a style blacklist?

Any "no" → see `FORBIDDEN-PATTERNS.md` and `FINISH-GATE.md`. Not done.
