# FixMyVibe — Research Synthesis

*Deep dive into vibe-coding failure modes and generic AI UI/UX, and the landscape of existing
fixes. This is the evidence base for the `fixmyvibe` skill. Compiled 2026-08-11.*

## Standards baseline update (2026-10-13)

The original research identified useful failure patterns but leaned too heavily on vendor articles,
aggregate claims, and web UI. The current skill architecture now starts from primary standards and
uses secondary research only as supporting context.

### What changed in the skill

1. **Risk profiles instead of one universal checklist.** Web/API work maps to OWASP ASVS 5.0 and the
   API Security Top 10; mobile maps to MASVS/MASTG; IoT maps to ISVS; software components map to
   SCVS and OpenSSF guidance. Desktop/CLI, library, infrastructure, and data-pipeline profiles cover
   trust boundaries those web-focused sources miss.
2. **A layered evidence model.** NIST SSDF calls for security practices across the development
   lifecycle, including code review, automated analysis, dynamic testing, regression tests, root
   cause analysis, and risk-based testing. A regex audit is now described honestly as one heuristic
   layer, not a security verdict.
3. **AI systems are a separate attack surface.** NIST AI 600-1 and current OWASP GenAI guidance
   require attention to prompt injection, data privacy, model/tool supply chains, unsafe output,
   excessive agency, evaluation, monitoring, and incident response. The skill now treats every model
   and retrieval result as untrusted data and keeps authorization outside the model.
4. **Accessibility targets WCAG 2.2 Level AA.** The UI gate now includes focus not obscured, zoom and
   reflow, target size, error identification, accessible authentication, keyboard traversal, and a
   screen-reader spot check. Automated accessibility scans remain a floor, not a conformance claim.
5. **Supply-chain posture is explicit.** Dependency review now covers ownership, provenance, release
   artifacts, CI token permissions, pinned build inputs, lockfiles, and SBOMs where supported. OpenSSF
   itself describes Scorecard output as heuristic evidence, not a verdict, which informed the audit's
   output language and `secure: null` JSON field.

### Primary baselines

- OWASP ASVS 5.0: https://owasp.org/projects/asvs
- OWASP API Security Top 10: https://api-security.owasp.org/editions/2023/en/0x03-introduction/
- OWASP MASVS and MASTG: https://mas.owasp.org/MASVS/
- OWASP Software Component Verification Standard: https://owasp.org/projects/software-component-verification-standard
- OWASP Internet of Things Security Verification Standard: https://owasp.org/projects/iot-security-verification-standard
- NIST SP 800-218 Secure Software Development Framework: https://csrc.nist.gov/pubs/sp/800/218/final
- NIST AI 600-1 Generative AI Profile: https://www.nist.gov/itl/ai-risk-management-framework/ai-risk-management-framework-resources
- W3C WCAG 2.2: https://www.w3.org/TR/WCAG22/
- OpenSSF Scorecard: https://github.com/ossf/scorecard

### Research discipline

- Do not repeat a percentage without the underlying study, sample, date, and method.
- Do not treat a top-ten awareness list as a complete risk assessment.
- Do not claim compliance from a scanner. Conformance needs the controls and evidence required by
  the named standard.
- Re-check versions of primary standards for sensitive and critical releases.

---

## 0. What "vibe coding" is (and why it fails predictably)

**Vibe coding** = building software by prompting an AI agent in natural language and largely
accepting whatever it produces, without reading, reviewing, or understanding the code. The term was
popularized in early 2025 (Andrej Karpathy: "give in to the vibes… forget that the code even
exists"). It's fantastic for speed and prototyping and genuinely dangerous in production, because the
model optimizes for *"produces something that looks like it works on the happy path"* — not for
security, maintainability, correctness under edge cases, or design taste.

The failures are **predictable and systemic**, not random, because they come from *how* LLMs
generate code:

- **Statistical averaging** — the model outputs the most probable continuation. In code that's the
  most common (often insecure) pattern; in UI that's the average of every template it trained on
  ("distributional convergence"). ([shuffle.dev](https://shuffle.dev/blog/2026/01/why-do-most-ai-generated-websites-look-the-same/), [Medium/dminhk](https://medium.com/@dminhk/why-do-ai-generated-websites-all-look-identical-02a68015613d))
- **"By definition, Copilot is an average of all developers' shared work… all the security failings
  added to all known public codebases are part of the corpus."** ([Glide](https://www.glideapps.com/blog/vibe-coding-risks))
- **Functionality over security** — models prioritize "make it run" and skip the checklist a human
  would apply. ([Wiz](https://www.wiz.io/academy/ai-security/vibe-coding-security), [Checkmarx](https://checkmarx.com/blog/security-in-vibe-coding/))
- **Vague prompts → safest default** — with no constraints the model picks the most statistically
  common layout/stack. ([DEV](https://dev.to/_46ea277e677b888e0cd13/why-every-ai-generated-landing-page-looks-the-same-and-how-to-fix-it-1kmo))
- **Uncritical acceptance** — teams assume output is production-ready, so vulnerabilities move
  downstream with no validation. ([IBM](https://www.ibm.com/think/insights/vibe-coding-security-risks))

---

## A. Code-craft failure modes (the "vibe-coded mistakes")

Each: what goes wrong → root cause → prevention. Citations inline.

1. **Secrets hardcoded / exposed in the frontend.** API keys, DB creds committed to repos or shipped
   in client bundles. *11% of vibe-coded apps were found leaking Supabase keys.* Root cause: model
   inlines a working key to make the demo run; no concept of secret boundaries.
   Prevent: env vars + server-only secrets; scan for high-entropy strings before commit.
   ([HN](https://news.ycombinator.com/item?id=46662304), [vietanh.dev](https://www.vietanh.dev/blog/2026-03-12-securing-vibe-coded-apps))

2. **Broken / missing authorization (BOLA/IDOR, no RLS).** Endpoints trust the client; row-level
   security never enabled. *Lovable left a broken-auth flaw open 48 days; 303 vulnerable endpoints
   across 170 of 1,645 scanned apps (~10%).* Root cause: auth is invisible on the happy path, so the
   model omits it. Prevent: deny-by-default, server-side authz checks, enable RLS, test as a
   different user. ([Medium/Somanath](https://medium.com/@somanathtv/the-lovable-supabase-stack-when-ai-driven-speed-becomes-your-biggest-liability-e94aad6f0102), [baytech](https://www.baytechconsulting.com/blog/vibe-coded-apps-exposed-what-it-means))

3. **Injection (SQLi / XSS / command).** String-built queries, unescaped output. *A Swedish audit
   found ~10.3% of live Lovable apps had exploitable SQLi/XSS.* Prevent: parameterized queries,
   output encoding, an ORM/query builder, a template engine that auto-escapes.
   ([vibe-eval](https://vibe-eval.com/ai-security/vibe-coding-vulnerabilities/))

4. **Hallucinated dependencies → slopsquatting supply-chain attacks.** Models invent package names;
   *19.7% of generated packages were hallucinated and 43% reappear on re-runs*, so attackers
   pre-register them. (`huggingface-cli` decoy: 30k+ downloads.) Prevent: verify every dependency
   exists and is the intended one before install; lockfiles; don't auto-install.
   ([VibeDoctor](https://vibedoctor.io/blog/slopsquatting-ai-hallucinated-packages-malware))

5. **No input validation / trusting the client.** Happy-path inputs only; no length/type/range
   checks; client-side "validation" only. Prevent: validate + sanitize on the server at every trust
   boundary. ([Contrast](https://www.contrastsecurity.com/glossary/vibe-coding))

6. **No error handling / swallowed errors.** `try/except: pass`, unhandled promise rejections, <!-- fixmyvibe: allow COR001 documented-pattern -->
   crashes on the first unexpected input. Root cause: errors don't appear on the demo path.
   Prevent: handle and surface errors; fail loud in dev, gracefully in prod.

7. **Insecure defaults & over-broad permissions.** Public buckets, `chmod 777`, CORS `*`, admin keys
   in client, debug mode in prod. ([Databricks](https://www.databricks.com/blog/passing-security-vibe-check-dangers-vibe-coding))

8. **Cryptographic failures.** Plaintext passwords, MD5/SHA1, homemade crypto, weak/no hashing.
   Prevent: use a vetted library, bcrypt/argon2, TLS everywhere. ([arXiv 2606.23130](https://arxiv.org/pdf/2606.23130))

9. **Arbitrary code execution / memory corruption even when it "appears functional."** The academic
   (In)Security study found deployed vibe-coded apps with ACE and memory-corruption bugs behind a
   working UI. ([arXiv 2606.23130](https://arxiv.org/pdf/2606.23130))

10. **No tests (or fake/trivial tests).** Nothing proves it works or stays working; regressions ship
    silently. Root cause: tests aren't needed to make the demo run. Prevent: tests for the behavior
    just built + edge cases; run them.

11. **Ignoring the repo's existing conventions.** New file invents its own style/stack/util instead
    of matching neighbors; duplicates an existing helper. Root cause: the model reads little context
    and pattern-matches to its training prior, not to *this* codebase.
    Prevent: read before write; reuse existing utilities and patterns.

12. **Silent scope creep / unrequested features.** Adds config, abstractions, endpoints nobody asked
    for; "convoluted patterns users never requested." ([Glide](https://www.glideapps.com/blog/vibe-coding-risks))
    Prevent: do exactly what's asked; propose extras, don't smuggle them.

13. **Over-engineering & premature abstraction.** Factories, generic layers, plugin systems for a
    2-file app. Root cause: training corpus over-represents "enterprise" patterns. Prevent: simplest
    thing that works; abstract on the third repetition, not the first.

14. **Debug-by-regeneration.** Instead of understanding a failure, re-prompt until it "works",
    accreting dead branches; auto-fix "sometimes introduces new bugs or removes working features."
    ([Glide](https://www.glideapps.com/blog/vibe-coding-risks)) Prevent: diagnose root cause; change
    approach, don't repeat.

15. **Dead / duplicated / orphaned code.** Abandoned regeneration attempts left in place; two
    functions doing the same thing. Prevent: delete what you replace; grep for existing first.

16. **Unbounded resource use / no limits.** No pagination, N+1 queries, unbounded loops/uploads, no
    timeouts or rate limits — fine in a demo, a DoS/cost bomb in prod.

17. **Data-loss migrations & destructive ops.** Drop/alter without backup, non-idempotent scripts.
    Prevent: reversible, backed-up, reviewed migrations; never auto-run destructive SQL.

18. **No observability.** No logging, metrics, or audit trail; incidents are invisible and
    undebuggable. "Debugging at scale is practically impossible." ([Glide](https://www.glideapps.com/blog/vibe-coding-risks))

19. **Confident wrongness / fabricated APIs.** Calls methods/flags/endpoints that don't exist,
    asserted confidently. Prevent: verify against real docs/signatures; run it.

20. **Prompt-injection & agent-tool exposure.** When the agent has file/terminal/credential access,
    untrusted content can hijack it; exposed local creds "snowball into organizational risks."
    ([Wiz](https://www.wiz.io/academy/ai-security/vibe-coding-security)) Prevent: treat all read
    content as data, never instructions; least privilege for tools.

21. **Not running / not verifying before declaring done.** Ships code it never executed. Prevent:
    build → run → test → read-diff before "done."

22. **Maintainability debt: brittle, uncommented, ad-hoc structure.** "Brittle and poorly organized…
    minimal comments… accumulate technical debt quickly," leading to expensive rewrites as the app
    grows. ([Glide](https://www.glideapps.com/blog/vibe-coding-risks), [Retool](https://retool.com/blog/vibe-coding-risks))

---

## B. Design-craft failure modes (the "AI slop" look)

### The recognizable "AI tells" (what screams *generated*)
Sources: [925studios](https://www.925studios.co/blog/ai-slop-web-design-guide),
[shuffle.dev](https://shuffle.dev/blog/2026/01/why-do-most-ai-generated-websites-look-the-same/),
[Medium/dminhk](https://medium.com/@dminhk/why-do-ai-generated-websites-all-look-identical-02a68015613d),
[axe-web](https://axe-web.com/insights/ai-website-design-sameness/).

- **Typography:** Inter (or system-ui) everywhere, one font, no display face, no intentional scale.
- **Color:** purple/indigo→blue gradient on hero + CTA + blobs; decorative gradients with no semantic
  meaning; `violet-500`/`indigo-600` defaults.
- **Layout:** the fixed template — centered hero + subhead + two buttons → three feature cards →
  testimonials → pricing → CTA footer. Card-based everything with no hierarchy variation.
- **Components:** untouched shadcn/ui defaults; uniform `rounded-2xl` + `shadow-lg` + `24px` padding
  on every card; identical card heights.
- **Imagery:** stock "diverse team at laptops in impossibly lit office"; too-smooth AI illustrations;
  unreplaced placeholders; glassmorphism + gradient blobs.
- **Copy:** vague aspirational headlines ("Build the future of work", "Your all-in-one platform"),
  superlatives ("best-in-class", "cutting-edge"), hedging ("may help you"), emoji bullets.
- **Motion:** uniform fade-ins on everything, or none; buttons snap instead of ease; no
  micro-interactions; decorative animation with no purpose.

### UX failure modes (deeper than looks)
- Missing **states**: no empty / loading / error / success / zero-results / offline states.
- **Accessibility ignored**: poor contrast, no visible focus states, no keyboard nav, no `aria`,
  non-semantic `<div>` soup, no labels, motion without `prefers-reduced-motion`.
- **No real information architecture** or content hierarchy; everything same visual weight.
- **Forms** with no validation feedback, no inline errors, no disabled/pending states.
- **Not responsive-tested**; breaks on mobile; fixed pixel widths.
- **Dark patterns** or meaningless motion that harms usability.
- **Over-engineered UX**: "questionable taste… unnecessary complexity… prioritizes aesthetics over
  functional UX." ([Glide](https://www.glideapps.com/blog/vibe-coding-risks))

### What good looks like instead (principles)
Sources: [925studios](https://www.925studios.co/blog/ai-slop-web-design-guide),
[nayamoss](https://nayamoss.com/how-i-use-ai/teach-ai-agents-design-system).
- **Design tokens first**: semantic CSS custom properties (`--color-action-primary`,
  `--color-feedback-success`), never `--gradient-start`. Color applied by state/mode, not decoration.
- **Two-font system**: a distinctive display face + a readable body face; an intentional modular type
  scale. (Linear, Stripe, Vercel/Geist as references.)
- **Real content**: product screenshots, real data, real team photos — not stock or lorem.
- **Opinionated voice**: headlines a founder would actually say (Basecamp, Superhuman, Linear).
- **Motion with 3 jobs only**: signal state change, direct attention, express brand — else delete it.
- **Every state designed**: empty/loading/error/success/zero.
- **Accessibility as a gate**: WCAG AA contrast, visible focus, keyboard path, semantic HTML, labels,
  reduced-motion.
- **A design system, derived per project** — build brand-specific tokens/components that *override*
  the AI defaults, and review pages against it before shipping. (This is the anti-"average" move.)

---

## C. What every AI agent/tool is doing (cross-cutting patterns)

- **Convergent default stack:** React + Tailwind + shadcn/ui + Supabase/Next is the near-universal
  output of v0, Lovable, Bolt.new, Replit Agent — which is exactly why outputs look and fail alike.
  ([Medium/Somanath](https://medium.com/@somanathtv/the-lovable-supabase-stack-when-ai-driven-speed-becomes-your-biggest-liability-e94aad6f0102))
- **Shared behavioral failure modes** (all agents): don't-read-before-write; eager dependency adds;
  don't-run/verify; happy-path only; ignore repo conventions; over-generate boilerplate; confident
  wrongness; scope creep.
- **How the ecosystem tries to constrain them:** rules files (`.cursor/rules/*.mdc`, `.cursorrules`),
  **AGENTS.md** (build/test/style/architecture/boundaries context), **CLAUDE.md**, **skills**
  (`SKILL.md`), plan mode, and verification loops. Best-practice guidance:
  - Give the agent a **design philosophy + persona** ("experienced designer following Dieter Rams"),
    not just rules — LLMs respond to persona. ([nayamoss](https://nayamoss.com/how-i-use-ai/teach-ai-agents-design-system))
  - **Modular** rules over one mega-file; **read design rules before generating**.
    ([DEV/Cursor](https://dev.to/mkomeyl94/from-prompt-to-production-mastering-rules-skills-and-subagents-in-cursor-47m4), [morphllm](https://www.morphllm.com/agents-md-guide), [builder.io](https://www.builder.io/blog/agents-md))
  - Separate concerns: agent *behavior* vs project *code style*.
    ([cursor-alternatives](https://cursor-alternatives.com/blog/system-prompts-for-ai-coding-agents/))

---

## D. Existing solutions and the gap FixMyVibe addresses

| Solution | What it does well | What it misses (our opening) |
|---|---|---|
| **no-ai-slop** (`petergyang/no-ai-slop`) | Sharp write/edit/detect workflow; preserves voice; reports changes; does not pretend style can prove AI authorship | Prose only; no code, UI, security, accessibility, or AI-system release gate |
| **Anti-AI-UI** (`Vanszs/Anti-AI-UI`) | Extensive UI and code pattern catalogs; component references; accessibility checks; searchable design data | UI-centric and highly prescriptive; long fixed menus and absolute bans can create another monoculture; no full delivery security model |
| **Hallmark** (`nutlope/hallmark`) | Detailed anti-slop UI gates; agent-agnostic skill; audit mode; pre-emit self-critique | UI only; theme catalogs can become another monoculture; web/HTML-CSS focused |
| **awesome-cursorrules / .cursorrules collections** | Lots of stack-specific conventions | Vague ("write clean code"); no UI anti-slop; no enforcement/verification; not portable across agents |
| **AGENTS.md templates** ([morphllm](https://www.morphllm.com/agents-md-guide), [builder.io](https://www.builder.io/blog/agents-md)) | Standard place for build/test/style context | Project-context, not a reusable craft standard; no anti-slop; no gate |
| **"Design system for AI" guides** ([nayamoss](https://nayamoss.com/how-i-use-ai/teach-ai-agents-design-system)) | Persona + tokens + "read rules first" is exactly right | Manual, per-user, not packaged; UI only |
| **Security guides** (Wiz/Checkmarx/IBM/vietanh) | Great checklists | Prose, not an agent-loadable enforceable skill |

**FixMyVibe's differentiators:**
1. **Four axes in one skill** — code, design, content, and AI-system craft, selected by risk profile.
2. **Teach a method, don't ship themes** — derive a bespoke design system per project so output stays
   distinctive instead of converging on "theme #7".
3. **Enforcement, not exhortation** — a mandatory **Finish-Gate self-audit** that dogfoods a concrete
   FORBIDDEN-PATTERNS blocklist; "done" is impossible on a red gate. Pairs with Perpetua's Stop guard.
4. **Truly agent-agnostic packaging** — one folder, adapters for Claude Code, Cursor, Codex,
   Antigravity, Gemini.
5. **Persona + philosophy + concrete rules** — the combination the research says works best.

---

## D2. Deep competitor-repo teardown

Studied the actual repositories, not just blog summaries. Findings:

### `petergyang/no-ai-slop`

This is the strongest writing-specific workflow reviewed. It separates editing from detection,
preserves personal voice, asks for the minimum effective edit, returns a concise change report, and
explicitly refuses to infer AI authorship from prose patterns. Its pattern catalog catches more than
generic buzzwords: binary contrasts, throat-clearing, fake revelations, importance inflation,
weasel attribution, synonym cycling, robotic rhythm, and conclusions that merely recap.

FixMyVibe adopts the operating principles, not the wording: write/edit/detect are distinct
operations; detect mode points to exact text without rewriting; edit mode preserves voice and
reports material changes; factual claims still require source checks. The remaining difference is
scope. `no-ai-slop` intentionally focuses on prose, while FixMyVibe applies content review inside a
larger code, UI, security, and AI-system delivery gate.
([repo](https://github.com/petergyang/no-ai-slop),
[skill](https://github.com/petergyang/no-ai-slop/blob/main/skills/no-ai-slop/SKILL.md),
[evaluation](https://github.com/petergyang/no-ai-slop/blob/main/skills/no-ai-slop/eval.md))

### `Vanszs/Anti-AI-UI`

This repository combines three useful layers: a detailed anti-pattern filter, positive component
references, and a searchable UI/UX design database. Its strongest contribution is coverage depth.
It reviews specific surfaces such as navigation, forms, tables, dialogs, feedback, accessibility,
and common generated-code mistakes instead of stopping at colors and gradients.

Its main tradeoff is prescriptiveness. Large style menus, fixed font and palette recommendations,
and absolute visual bans can replace one default with another. FixMyVibe therefore adopts
component-level coverage and positive alternatives while treating individual visual traits as
contextual signals. A combined fingerprint of unexplained defaults is stronger evidence than one
font, color, library, or layout choice. The project also extends beyond UI into authorization,
injection, dependency provenance, data loss, AI tool boundaries, and release evidence.
([repo](https://github.com/Vanszs/Anti-AI-UI))

### Hallmark — `Nutlope/hallmark`
A detailed anti-slop design skill with mechanisms worth respecting:
- **Macrostructure-first:** picks 1 of 21 named page shapes (Marquee Hero, Bento, Long Document,
  Manifesto…) *before* visuals, and states the pick on the page (accountability).
- **Diversification rule:** each build must differ from the last on ≥1 axis (paper-band / display
  style / accent hue); reads `.hallmark/log.json` project memory to avoid repeating the last 3–5.
- **Pre-emit self-critique:** scores output 1–5 on 6 axes (philosophy, hierarchy, execution,
  specificity, restraint, variety); anything <3 triggers revision; scores stamped in a CSS comment.
- **58-gate slop test** (genre-aware), extremely concrete: OKLCH tokens only, `minmax(0,1fr)` not
  bare `1fr`, `:focus-visible` required, no italic headers, no fake browser/code chrome, no invented
  metrics, `overflow-x: clip` not `hidden`, buttons wrap long words, responsive at 320/375/414/768.
- **Surgical progressive loading:** loads only the genre + chosen macrostructure/component files,
  never the whole catalogue; `slop-test.md` loaded only at the final gate.
- **8 states per interactive element**, 3 named easings, `prefers-reduced-motion`, token file emitted.
- **4 verbs:** default (build) · `audit` (score, no edits) · `redesign` (revisual inside boundaries)
  · `study` (extract design DNA from a URL/screenshot into a portable `design.md`).
- **Pre-flight scan:** reads the repo's existing font/palette/spacing/framework before asking anything.
- **Weakness we exploit:** **design only.** Zero coverage of security, authz, injection, secrets,
  tests, dependencies, data-loss migrations — i.e. the failures that actually get vibe-coded apps
  breached. Also HTML/CSS-centric; not full-stack. *How we beat it: keep every good mechanism, then
  generalize the self-critique, audit, diversification, pre-flight, and progressive-loading ideas to
  CODE as well, and add executable enforcement it lacks.*
  ([repo](https://github.com/nutlope/hallmark), [SKILL.md](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/SKILL.md), [explainx](https://www.explainx.ai/blog/nutlope-hallmark-anti-ai-slop-design-skill-july-2026))

### `Koomook/claude-frontend-skills` — single `distinctive-frontend` skill
Extreme font-weight contrast (100–200 vs 800–900), cultural aesthetic palettes
(Cyberpunk/Brutalist/Vaporwave/Nordic), staggered load animations, layered/noise backgrounds; a
tidy anti-pattern checklist (no Inter/Roboto, no 400–600 weights, no purple-blue gradient, no flat
white bg, no pastel low-contrast). *Beat it: it's a single visual recipe with no code/security axis,
no verify loop, no enforcement.* ([repo](https://github.com/Koomook/claude-frontend-skills))

### `rohitg00/awesome-claude-design` — a reference collection
Nine **aesthetic families** (Editorial Minimalism, Terminal-Core, Warm Editorial, Data-Dense Pro,
Cinematic Dark, Playful Color, Glass/Soft-Futurism, Neon Brutalist, Cult/Indie) + catalogued
"default fingerprints" to avoid (teal `#16d5e6`, animated live-dots, 4px card left-rules, 3-col hero
grids, Lucide defaults, serif-headline+sans-body cliché). *Beat it: it's a curated list/prompt pack,
not an enforceable skill; no code axis.* We borrow its aesthetic-family taxonomy as our
DESIGN-DIRECTIONS menu. ([repo](https://github.com/rohitg00/awesome-claude-design))

### `wilwaldon/Claude-Code-Frontend-Design-Toolkit` — a directory of tools
Organizes 70+ tools into 10 categories (design skills, tokens, motion, UX intel, design-to-code,
testing/Playwright visual regression, docs/context, framework skills, deploy, stacks). *Beat it:
it's a shopping list that assumes you assemble it yourself; no single enforceable standard, no code
security.* We take one idea: pair the skill with visual-regression/a11y tooling in the gate.
([repo](https://github.com/wilwaldon/Claude-Code-Frontend-Design-Toolkit))

### `PatrickJS/awesome-cursorrules` & the AGENTS.md standard
Hundreds of stack-specific `.cursorrules`/MDC templates; in 2026 Google/OpenAI/Sourcegraph/Cursor/
Factory converged on **AGENTS.md** as the universal agent-context file. *Beat it: these are
project-context conventions, not a portable craft standard, and are vague ("write clean code") with
no anti-slop and no gate.* We ride the AGENTS.md standard in our adapters.
([awesome-cursorrules](https://github.com/PatrickJS/awesome-cursorrules), [AGENTS.md standard](https://www.morphllm.com/agents-md-guide))

### Scope scoreboard

| Capability | no-ai-slop | Anti-AI-UI | Hallmark | **FixMyVibe** |
|---|:--:|:--:|:--:|:--:|
| Voice-preserving prose workflow | Strong | Partial | No | Included |
| Detailed UI review | No | Strong | Strong | Included |
| Positive design direction | No | Catalog | Catalog | Project-derived method |
| Code security, correctness, and dependencies | No | Pattern list | No | Risk-profiled gate |
| AI-system security and evaluation | No | No | No | Included |
| Non-web profiles | No | No | No | Mobile, CLI, library, infra, data, IoT |
| Executable repository gate | No | Search tooling | No | PowerShell and shell |
| Evidence-before-done workflow | Content eval | UI workflow | Design gate | Full delivery gate |

**Thesis:** a useful craft skill must connect code, design, content, and AI-system risks to evidence.
Its executable checks are one heuristic layer beside stack-native scanners, tests, and human review,
not a replacement for them.

## Sources
- https://github.com/petergyang/no-ai-slop
- https://github.com/petergyang/no-ai-slop/blob/main/skills/no-ai-slop/SKILL.md
- https://github.com/petergyang/no-ai-slop/blob/main/skills/no-ai-slop/eval.md
- https://github.com/Vanszs/Anti-AI-UI
- https://github.com/nutlope/hallmark
- https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/SKILL.md
- https://www.explainx.ai/blog/nutlope-hallmark-anti-ai-slop-design-skill-july-2026
- https://github.com/Koomook/claude-frontend-skills
- https://github.com/rohitg00/awesome-claude-design
- https://github.com/wilwaldon/Claude-Code-Frontend-Design-Toolkit
- https://github.com/PatrickJS/awesome-cursorrules
- https://github.com/sanjeed5/awesome-cursor-rules-mdc
- https://github.com/DVC2/cursor_prompts
- https://github.com/daymade/claude-code-skills
- https://www.glideapps.com/blog/vibe-coding-risks
- https://www.wiz.io/academy/ai-security/vibe-coding-security
- https://checkmarx.com/blog/security-in-vibe-coding/
- https://www.ibm.com/think/insights/vibe-coding-security-risks
- https://arxiv.org/pdf/2606.23130  (Understanding the (In)Security of Vibe-Coded Applications)
- https://www.guidepointsecurity.com/blog/vibe-coding-real-code-real-risks-or-both/
- https://www.databricks.com/blog/passing-security-vibe-check-dangers-vibe-coding
- https://retool.com/blog/vibe-coding-risks
- https://www.contrastsecurity.com/glossary/vibe-coding
- https://arxiv.org/pdf/2509.12491  (Good Vibrations? Qualitative study of vibe coding)
- https://news.ycombinator.com/item?id=46662304  (11% of vibe-coded apps leaking Supabase keys)
- https://www.vietanh.dev/blog/2026-03-12-securing-vibe-coded-apps
- https://medium.com/@somanathtv/the-lovable-supabase-stack-when-ai-driven-speed-becomes-your-biggest-liability-e94aad6f0102
- https://vibe-eval.com/ai-security/vibe-coding-vulnerabilities/
- https://vibedoctor.io/blog/slopsquatting-ai-hallucinated-packages-malware
- https://www.baytechconsulting.com/blog/vibe-coded-apps-exposed-what-it-means
- https://vibe-eval.com/vibe-hacking/
- https://www.clarista.io/blog/vibe-coding-security-limitations
- https://labs.cloudsecurityalliance.org/research/csa-research-note-ai-codegen-vulnerability-debt-20260406-csa/
- https://shuffle.dev/blog/2026/01/why-do-most-ai-generated-websites-look-the-same/
- https://medium.com/@dminhk/why-do-ai-generated-websites-all-look-identical-02a68015613d
- https://www.925studios.co/blog/ai-slop-web-design-guide
- https://axe-web.com/insights/ai-website-design-sameness/
- https://dev.to/_46ea277e677b888e0cd13/why-every-ai-generated-landing-page-looks-the-same-and-how-to-fix-it-1kmo
- https://dev.to/rams901/hallmark-stop-ai-generated-ui-slop-in-one-command-in-2026-3p9n
- https://nayamoss.com/how-i-use-ai/teach-ai-agents-design-system
- https://www.morphllm.com/agents-md-guide
- https://www.builder.io/blog/agents-md
- https://cursor-alternatives.com/blog/system-prompts-for-ai-coding-agents/
- https://dev.to/mkomeyl94/from-prompt-to-production-mastering-rules-skills-and-subagents-in-cursor-47m4

---

## D3. November 2026 round: what the strongest alternatives do, and what we took

Sources were opened on 2026-11-16. Star counts are as read that day.

| Project | Mechanism that changes behavior | What we took |
|---|---|---|
| obra/superpowers (verification-before-completion) | A claim, evidence, not-evidence table and a red-flags list written against measured agent rationalizations | `SKILL.md` sections 4 and 5 |
| leonxlnx/taste-skill 2.5 | A Stop hook that blocks once, with an anti-trap budget and waivers that need a reason | `--hook stop`, one block per stop, reasoned `allow` annotations |
| pbakaus/impeccable | Deterministic detector with a per-edit tier and a Stop tier | `--hook edit` reports blockers only; warnings wait for a manual run |
| Anthropic security-guidance plugin | Regex rules scoped by path and extension | Rule scopes in `bin/rules.conf` |
| Anthropic security-review, code-review | Findings need 80 percent confidence and an exploit scenario, checked by a separate pass | The refutation method in `references/SELF-CRITIQUE.md`, replacing 1 to 5 self-scores |
| Anthropic skill-creator, agentskills.io | `evals/evals.json`, with-skill and without-skill runs | `evals/` |
| trailofbits/skills (insecure-defaults) | Fallback-secret seeds; a test that every documented example fires a rule; POSIX classes only | SEC007, the corpus coverage test, the rule-pack lint |
| gitleaks | Judge the captured value: skip pure-letter values and template references | The `unless` clause on SEC003, SEC004, SEC005 |

Sources:
- https://github.com/obra/superpowers/blob/main/skills/verification-before-completion/SKILL.md
- https://github.com/leonxlnx/taste-skill
- https://github.com/pbakaus/impeccable
- https://github.com/anthropics/claude-plugins-official/tree/main/plugins/security-guidance
- https://github.com/anthropics/claude-code-security-review
- https://github.com/anthropics/skills/tree/main/skills/skill-creator
- https://agentskills.io/specification
- https://github.com/trailofbits/skills
- https://github.com/gitleaks/gitleaks
- https://code.claude.com/docs/en/hooks and https://code.claude.com/docs/en/skills

Not adopted, with the reason: rendered-page checks in a real browser (needs Node and Chrome, which
breaks the no-dependency rule), a central baseline file for legacy findings (the diff modes cover
the same need), and hook wiring for Gemini CLI, Cursor native hooks, and Antigravity (their event
formats were not tested here, so no configuration is published for them).
