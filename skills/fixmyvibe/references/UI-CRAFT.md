# UI craft

AI interfaces look alike because a model produces the average of the templates it learned from. A
better template only moves the average. The fix is a method: derive a design system for this
project, build to it, and finish every state and the accessibility work.

The test for the result: could a careful user tell that a person with judgment made this?

Contents: 1 Design system first · 2 Real content · 3 Every state · 4 Accessibility · 5 Responsive
· Final check

## 1. Derive the design system before any component

If the project has a design system, use it and skip to step 2. Otherwise decide these first and
write them into a tokens file that every component reads.

1. **Three brand adjectives,** for example "precise, calm, editorial". Infer them from the
   product's domain and audience, or ask one question. Every later choice serves them.
2. **A type system with roles.** Display and body treatments that fit the product, with a scale,
   line heights, weights, fallbacks, and loading behavior. One family can be enough. Keep an
   established brand face.
3. **Color as semantic tokens.** Name by role: `--color-action`, `--color-surface`,
   `--color-danger`, `--color-text-muted`. Choose a considered accent, neutrals with a temperature,
   and functional success, warning, and danger colors. Color signals state; it is not decoration.
4. **One spacing scale and a deliberate radius.** A 4px base works. Use shadows sparingly.
5. **Motion with three jobs only:** signal a state change, direct attention, or express the brand.
   Recipes are in `DESIGN-DIRECTIONS.md`.

Then every component consumes tokens. No hard-coded hex values, no one-off spacing. This is what
makes the interface read as one system.

## 2. Build with real content

- **Real copy and hierarchy.** No lorem ipsum, no filler headline. Write what the product does,
  specifically (`CONTENT-CRAFT.md`). Not every element gets the same weight.
- **Real imagery.** Product screenshots, real data, real photos. If none exists, leave the slot
  out or mark the placeholder in your report.
- **Structure from content.** Choose the page shape in `DESIGN-DIRECTIONS.md`.
- **Restyle library components** through your tokens so they stop looking like the library.

## 3. Build every state

For each view and component, design and implement the states it can reach:

- **Empty**, with a helpful next action. **Loading**, with stable layout. **Error**, saying what
  happened and how to recover. **Success.** **Zero results.** **Offline or failed fetch** where
  it applies.
- **Forms:** inline validation with clear messages, a pending state on submit, managed focus, and
  the user's input preserved on error.

| Surface | Review |
|---|---|
| Navigation | Current location, keyboard order, collapsed behavior, overflow, skip link |
| Forms | Persistent label, instructions, validation, pending state, recovery, preserved input |
| Search and filters | Initial, typing, loading, results, zero results, reset, failed request |
| Cards and lists | Real hierarchy, long content, missing media, selection, disabled actions |
| Tables | Header associations, sort state, keyboard access, overflow, empty data, pagination |
| Charts | Text alternative, clear legend, distinction without color, empty data, exact values |
| Dialogs and drawers | Accessible name, initial focus, focus trap, Escape, focus return |
| Toasts and live updates | A live region, enough reading time, no critical action only in a toast |
| Uploads and destructive actions | Limits, progress, cancel, failure recovery, stated consequence |

## 4. Accessibility is part of done

- **Semantic HTML first:** `button`, `nav`, `main`, headings in order.
- **Contrast** meets WCAG AA: 4.5:1 for text, 3:1 for large text and controls. Measure it.
- **Keyboard:** everything works without a mouse, in a logical order, with focus that is visible
  and not covered by sticky elements.
- **Names:** every input has a label, every image has alt text (empty for decoration), every icon
  control has an accessible name. Use ARIA only where native semantics fall short.
- **Dialogs and updates:** move focus into a modal, keep it there, return it on close. Announce
  asynchronous changes without flooding the screen reader.
- **Tables and charts:** keep programmatic headers, and give a text route to anything carried by
  color, position, or hover.
- **Motion:** honor `prefers-reduced-motion`. **Targets:** large enough and spaced for touch.
- **Zoom and reflow:** content and actions survive 200% zoom, narrow reflow, and user text
  spacing. Never block zoom.
- **Errors and sign-in:** identify errors in text and move focus to them. Do not require a memory
  test or a puzzle without an alternative.

Automated checks are a floor. Walk the changed flow by keyboard, and spot-check with a screen
reader at the level the product's risk calls for.

## 5. Responsive

Design from the narrow viewport up. Check 320, 375, 768, and a large viewport, plus 200% zoom. No
fixed widths that overflow. No horizontal scroll on the body. Wide content such as a table scrolls
inside its own focusable, named container.

## Final check

1. With the logo removed, could this be told apart from a generator default?
2. Is there a default I accepted without a reason?
3. Does every reachable state exist?
4. Does it pass WCAG AA and a keyboard-only walk?
5. Is the copy specific, or would it fit any product?
6. Do all components read from the same tokens?

A "no" means not done. See `FORBIDDEN-PATTERNS.md` and `FINISH-GATE.md`.
