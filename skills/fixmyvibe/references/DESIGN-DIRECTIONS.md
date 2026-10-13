# DESIGN-DIRECTIONS — pick a deliberate direction, then vary it

The average AI UI happens because the model never *chooses* — it defaults. This file forces a
choice: an **aesthetic direction**, a **macrostructure**, and then a **diversification** step so two
FixMyVibe builds never feel like color-swaps of one template. Use this together with
`UI-CRAFT.md` (the token/state/a11y standard). Absorbed and generalized from the best of the field
(Hallmark's macrostructure + diversification, awesome-claude-design's families, Koomook's contrast).

---

## Step A — Choose ONE aesthetic direction (state it on the page)
Match the product's domain, audience, and the 3 brand adjectives from `UI-CRAFT.md`. Do not blend
more than two. Reference exemplars are for *taste*, never to clone.

| Direction | Feel | Type & color signature | Fits |
|---|---|---|---|
| **Editorial Minimal** | calm, confident, spacious | serif display + clean sans body; neutral paper + one restrained accent | SaaS, dev tools, docs (Linear, Stripe, Vercel) |
| **Warm Editorial** | human, approachable, crafted | serif body; terracotta/cream/clay | writing, community, AI-with-warmth (Notion, Substack) |
| **Terminal-Core** | precise, technical, insider | monospace; phosphor green/amber on near-black | CLIs, infra, dev (Warp, Raycast, Ollama) |
| **Data-Dense Pro** | dense, powerful, legible | tight sans; saturated on dark dashboards | analytics, observability (PostHog, ClickHouse) |
| **Cinematic Dark** | dramatic, premium, motion-forward | oversized display; film-grade gradients (purposeful, not the slop blob) | media, launches, hardware (Runway, NVIDIA) |
| **Playful Color** | friendly, energetic, tactile | rounded display; high-saturation + illustration | consumer, education (Figma, Duolingo) |
| **Glass / Soft-Futurism** | sleek, modern, quiet-tech | light sans; frosted translucency, soft depth | Apple-adjacent, hardware/media (use sparingly — near slop) |
| **Neon Brutalist** | bold, loud, opinionated | mixed type, hard edges; one saturated hue on stark ground | editorial, culture, indie (The Verge, PlayStation) |

State it: *"Direction: Terminal-Core — mono display, amber accent on #0b0b0c."*

## Step B — Choose a macrostructure (not the default template)
The slop default is `hero → 3 feature cards → testimonials → pricing → CTA`. Pick a shape driven by
the *content*, and state it:
- **Marquee Hero** (one big claim + proof) · **Bento Grid** (modular capability tiles) ·
  **Long Document / Manifesto** (narrative, editorial) · **Stat-Led** (numbers first) ·
  **Workbench / Product-First** (show the actual UI) · **Gallery / Index** (many items) ·
  **Comparison** (vs. status quo) · **Quote-Led** (voice-driven).
Vary card sizes to express hierarchy; asymmetry and whitespace are tools, not bugs.

## Step C — Diversification rule (kill the monoculture)
Your build must differ from any prior build in the same project on **≥1 axis**: (1) macrostructure,
(2) display-type treatment, (3) accent hue/temperature. If a `design.md`/tokens file already governs
the project, invert this: **conform** to the system instead (consistency wins once a system exists).

---

## Concrete design gates (parity with the best + our additions)
These are hard rules; violations are gate failures (see `FORBIDDEN-PATTERNS.md §C`).

**Tokens & color**
- Every color/font/space value references a named token (`var(--color-accent)`, `--space-md`,
  `--font-display`). No inline hex/OKLCH/`"Some Font"` mid-render — lift new values into `:root` first.
- Prefer OKLCH for a perceptually even palette. Emit a `tokens.css` even for a single page.

**Typography**
- Define display and body roles. One family or several can work; do not add a face only to look custom.
- Use weight, color, underline, or italics according to the type system. Treat default italic headings
  as a review signal, not a universal defect.
- Keep the hero headline specific and proportional to the idea. Build hierarchy instead of enforcing
  an arbitrary word count.

**Layout & responsiveness**
- Image/card grids use `minmax(0, 1fr)`, never bare `1fr` (prevents blowout).
- Root html/body use `overflow-x: clip` (never `hidden` as a scroll-hider). No body horizontal scroll.
- Responsive at 320 / 375 / 414 / 768 / desktop. Clickable text wraps long words
  (`overflow-wrap: anywhere; min-width: 0`) — no two-line buttons breaking layout.

**States & motion**
- Every interactive element ships every applicable state: default, hover, focus, active, disabled,
  pending, error, and success. Do not invent meaningless states for static elements. Every data view
  handles empty, loading, error, success, and zero-results where those outcomes can occur.
- Prefer compositor-friendly motion and named easing tokens. Use layout animation only when its value
  outweighs its cost. Honor `prefers-reduced-motion` with a non-spatial or instant alternative.
- `:focus-visible` ring, ≥3:1 contrast, instant (never animated). Never `outline:none` without a
  replacement.

**Honesty in content (no fake proof)**
- **No invented metrics** ("+47% conversion", "trusted by 50,000+") without real user data — use a
  placeholder (`— metric to confirm`) or a different macrostructure.
- **No redrawn UI chrome** (fake browser bars, code windows, phone frames) — use a real screenshot
  or omit it. No stock "team at laptops", no unreplaced placeholders.
- Cut motion/decoration that carries no information.

## The named-fingerprints blocklist (avoid the *new* averages)
Even "distinctive" defaults converge. Do **not** reflexively ship: teal/cyan `#16d5e6` accent;
animated "live"/AI status dots; 4px decorative left-rules on every card; serif-headline+sans-body as
a thoughtless Anthropic mimic; three-column feature grid in the hero; untouched Lucide icon set;
glassmorphism blob background. Each is allowed *only* as a deliberate, stated choice.
