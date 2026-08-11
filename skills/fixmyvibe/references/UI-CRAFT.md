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
2. **Type system (two faces).** A distinctive **display** face for headings + a highly readable
   **body** face. Not Inter-for-everything. Define an intentional modular scale (e.g. 1.25 ratio),
   line-heights, and weights. References for *taste*, not to copy: Linear, Stripe, Vercel/Geist.
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

## Step 4 — Accessibility is a gate, not a nice-to-have

- **Semantic HTML** first (`<button>`, `<nav>`, `<main>`, headings in order) — not `<div>` soup.
- **Contrast** meets WCAG AA (4.5:1 text / 3:1 large & UI). Check it; the slop palette often fails.
- **Keyboard**: everything operable without a mouse; logical tab order; **visible focus states**
  (never `outline: none` with no replacement).
- **Labels & names**: every input has a label; icons/controls have accessible names; images have
  alt; use `aria-*` only where semantics don't already cover it.
- **Motion**: honor `prefers-reduced-motion`. **Targets**: adequately sized/spaced for touch.

## Step 5 — Responsive & real-device

- Design mobile-first; test at small, medium, large. No fixed pixel widths that overflow. No
  horizontal scroll on the page body. Tables/wide content scroll inside their own container.

---

## The anti-slop mental test (run before you ship UI)
1. If I stripped the logo, could this be told apart from a v0/Lovable default? If no → not done.
2. Is there a single default I accepted without a reason (Inter, purple gradient, `rounded-2xl`
   everywhere, centered hero + 3 cards, glassmorphism blob)? → replace it with a deliberate choice.
3. Does every interactive state exist (empty/loading/error/success/zero)? 
4. Would it pass a WCAG AA + keyboard-only pass?
5. Is the copy specific and human, or generic aspirational filler?
6. Do all components read from shared tokens, so it reads as one system?

Any "no" → see `FORBIDDEN-PATTERNS.md` and `FINISH-GATE.md`. Not done.
