# Design directions

Generic AI interfaces happen because the model never chooses; it defaults. This file makes you
choose a direction, a structure, and three dials before any markup, and then check that plan once
against the brief. Use it with `UI-CRAFT.md`, which covers tokens, states, and accessibility.

If the project already has a design system (a tokens file, a `design.md`, an established component
library), skip the choosing and conform to it. Consistency wins once a system exists.

Contents: A Direction · B Structure · C Dials · D Check the plan · Motion recipes · Design gates

## A. Choose one direction

Match the product's domain, its audience, and the three brand adjectives from `UI-CRAFT.md`. Blend
at most two. The exemplars are for calibration, not for copying.

| Direction | Feel | Type and color | Fits |
|---|---|---|---|
| Editorial Minimal | calm, confident, spacious | serif display with a clean sans; paper neutrals and one restrained accent | SaaS, developer tools, docs |
| Warm Editorial | human, approachable, crafted | serif body; terracotta, cream, clay | writing, community |
| Terminal | precise, technical | monospace; green or amber on near-black | CLIs, infrastructure |
| Data-Dense | dense, powerful, legible | tight sans; saturated accents on dark | analytics, observability |
| Cinematic Dark | dramatic, premium | oversized display; purposeful gradients | media, launches, hardware |
| Playful Color | friendly, energetic | rounded display; high saturation and illustration | consumer, education |
| Soft Glass | sleek, quiet | light sans; translucency and soft depth | hardware, media (close to a generic default, use with care) |
| Brutalist | bold, opinionated | mixed type, hard edges; one saturated hue on a stark ground | editorial, culture |
| Industrial | engineered, exact | condensed grotesque; steel neutrals and a signal color | manufacturing, logistics, tools |

State it in one line: "Direction: Terminal. Mono display, amber accent on #0b0b0c."

## B. Choose a structure

The default page is hero, three feature cards, testimonials, pricing, call to action. Pick a shape
from the content instead, and state it:

- **Marquee:** one large claim and its proof.
- **Bento:** capability tiles of different sizes.
- **Long document:** a narrative, read top to bottom.
- **Stat-led:** real numbers first.
- **Workbench:** the actual product interface is the page.
- **Index:** many items, built for scanning.
- **Comparison:** this against the status quo.
- **Quote-led:** a real voice carries the page.

Vary card sizes to show what matters most. Asymmetry and whitespace are tools.

## C. Set three dials

Each runs 1 to 10. Pick values from the brief, state them, and let the user override them ("make it
denser", "less motion"). Defaults are in the middle band.

- **Variance:** distance from a safe centered layout. 1 to 3 calm and centered, 4 to 6 confident
  asymmetry and varied card sizes, 7 to 10 experimental with broken grids and overlap. Do not
  exceed what the content can carry.
- **Motion:** how much moves. 1 to 2 state changes only, 3 to 5 hover and one-time scroll reveals,
  6 to 10 orchestrated or scroll-driven sequences.
- **Density:** information per screen. 1 to 3 spacious, 4 to 6 balanced product, 7 to 10 dense
  dashboard. Density never costs hierarchy or touch target size.

State them: "Dials: variance 5, motion 4, density 4." Two builds from one brief with different
dials should feel like different products.

## D. Check the plan once before building

Read your stated direction, structure, and dials against the brief and answer:

1. Which choice comes from this product, and could not have been made for a different one?
2. Which choice is still a default? Change it or give the reason.
3. Does the structure put the user's first question first?

Revise the plan, then build. Checking a plan costs a minute; rebuilding a page costs the task.

## Motion recipes

Scale how often these appear by the motion dial. Use CSS first; reach for a library only above 6.

- **Tokens:** `--dur-fast: 150ms; --dur-mid: 240ms; --dur-slow: 420ms;` and three named easings
  (`--ease-out`, `--ease-in`, `--ease-in-out`). No raw `ease`, no bounce.
- **State change (every dial value):**
  `transition: transform var(--dur-fast) var(--ease-out), opacity var(--dur-fast) var(--ease-out);`
  Pressed: `:active { transform: translateY(1px); }`
- **Entrance (motion 3 and up):** start at `opacity: 0; transform: translateY(12px)`. An
  `IntersectionObserver` adds a class that sets `opacity: 1; transform: none`. Stagger children with
  `transition-delay: calc(var(--i) * 60ms)`. Reveal once; never loop.
- **Loading:** a skeleton that matches the final layout, so nothing shifts. Not a spinner alone on
  an empty page.
- **Library tier (motion 6 and up):** keep the same durations and easings as the tokens. Animate
  `transform`, `opacity`, and `filter` only, never width, height, top, or left.
- **Reduced motion:** replace all movement with an opacity fade of 150ms or less.

If removing an animation loses no information, remove it.

## Design gates

**Tokens and color**
- Every color, font, and space value comes from a named token. Lift a new value into `:root`
  before using it. Emit a tokens file even for a single page.
- Name tokens by role (`--color-action`, `--color-surface`), not by appearance.
- Prefer OKLCH for a palette that steps evenly.

**Type**
- Define display and body roles. One family can be enough; do not add a face only to look custom.
- Size the headline to the idea. Build hierarchy with size, weight, and space.

**Layout**
- Grids of cards or images use `minmax(0, 1fr)`, not bare `1fr`.
- No horizontal scroll on the body. Fix the element that overflows; do not hide it.
- Check 320, 375, 768, and a large viewport. Long words in buttons wrap
  (`overflow-wrap: anywhere; min-width: 0`).

**States and focus**
- Each interactive element has the states it can reach: hover, focus, active, disabled, pending,
  error, success. Each data view handles empty, loading, error, and zero results.
- Focus uses `:focus-visible`, at least 3:1 contrast, and is never animated.

**Honest content**
- No invented metrics or social proof. Use a different structure, or a placeholder that the report
  names.
- No redrawn browser bars, code windows, or phone frames presented as the product. Use a real
  screenshot or leave it out.

**Defaults that have become their own average**
Each of these needs a stated reason: a teal or cyan accent, animated "live" status dots, a thin
colored left border on every card, a serif headline over a sans body chosen only to look
editorial, a three-column feature grid in the hero, an untouched icon set.
