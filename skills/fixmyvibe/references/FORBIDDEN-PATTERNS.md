# Forbidden patterns and review signals

A catalog of the specific failures this skill exists to prevent, each with what to do instead.
**Block** means a confirmed case stops the work until it is fixed. **Review** means look at it in
context, then fix it or state why it stays. The last column names the audit rule that catches the
common textual form. A dash means only a person or an agent reading the code can catch it.

A text match is not proof. Reachability, framework behavior, and product context decide whether a
review signal is a defect.

Contents: A Unsafe code · B Fragile or dishonest code · C Generic interface · D Missing interface
work · E Copy

## A. Unsafe code

| Level | Pattern | Do instead | Rule |
|---|---|---|---|
| Block | Secret, key, token, or password in source, a client bundle, or logs | Read it from the environment on the server; rotate anything committed | SEC001 to SEC005 |
| Block | `.env` file tracked by git | Add it to `.gitignore`, rotate what it held | SEC006 |
| Block | Secret with a literal fallback value | Fail at startup when the variable is missing | SEC007 |
| Block | Server secret behind a public env prefix, or a model key used in the browser | Keep it on the server and proxy the call | SEC008, SEC009 |
| Block | SQL built by concatenation, interpolation, or string formatting | Bound parameters or the ORM | SEC101 to SEC103, SEC109 |
| Block | `eval`, `new Function`, `exec`, or a shell string built from input | An argument array, a parser, or a lookup table | SEC104, SEC108 |
| Block | TLS or JWT signature verification turned off | Fix the certificate chain or the key; pin the algorithm | SEC105, SEC107 |
| Block | Passwords hashed with MD5 or SHA-1, or home-made crypto | argon2, scrypt, or bcrypt | SEC106 |
| Block | Untrusted event text expanded in a CI script | Pass it through an environment variable | SEC207 |
| Block | Token signed or verified with a literal secret | Read the key from the environment | SEC011 |
| Block | Request input used as a file path, or passed to a process launcher | Resolve inside a fixed root; allow list and argument array | SEC110, SEC104 |
| Block | Request input echoed into HTML, or rendered as a template | Escape it; render a file template | SEC114 |
| Block | Firestore or Realtime Database rules that allow everyone | Require authentication and ownership | SEC210 |
| Block | Endpoint or query that reads or writes a record without checking the caller | Check ownership in the query, deny by default | none |
| Block | Trusting a client-supplied user id, role, price, or permission | Derive it from the session on the server | none |
| Block | Installing a package name without confirming it exists | Look it up in the registry first | none |
| Block | Destructive migration or mass delete run automatically | Backup, tested rollback, human approval | COR004 |
| Review | Raw HTML sink (`innerHTML`, `dangerouslySetInnerHTML`, `v-html`) | Text nodes or a sanitizer; annotate the proof | SEC201 |
| Review | Unsafe deserialization (`pickle`, `yaml.load`, `torch.load`) | A safe loader, or data you produced yourself | SEC202 |
| Review | CORS open to every origin, debug mode on | List origins; turn debug off outside development | SEC203, SEC204 |
| Review | Auth token in `localStorage`, `Math.random` near a secret | HttpOnly cookie; the platform CSPRNG | SEC205, SEC206 |
| Review | Dependency, image, or action pinned to `latest` or a branch; remote script piped to a shell | Pin a version or digest; download and verify | DEP001, DEP002 |
| Review | Server fetches a URL from the request; redirect target from the request | Allow-list hosts, block private addresses; relative paths only | SEC111, SEC112 |
| Review | Whole request body written to the database | Pick the allowed fields | SEC113 |
| Review | Raw query API with interpolation; regular expression built from request input | The parameterized form; escape the input | SEC116, SEC218 |
| Review | Cookie flags off, CSRF protection disabled | Keep HttpOnly, Secure, and CSRF on; a signed webhook is the exception | SEC208, SEC209 |
| Review | Row level security off, or a policy that allows every row | Confirm the table is meant to be public | SEC211 |
| Review | Request body, headers, environment, or a secret written to logs; stack trace sent to the client | Log an id or a redacted summary; return a generic error | SEC212, SEC219 |
| Review | Signature compared with `==` | A constant-time comparison | SEC213 |
| Review | World-writable permissions; infrastructure open to `0.0.0.0/0`; public bucket | The narrowest mode and range that works | SEC214, SEC215 |
| Review | Request over plain HTTP; secret in a URL query string | HTTPS; a header or the body | SEC216, SEC217 |
| Review | User text placed in the system prompt | Keep it in a user message; treat model output as untrusted | AI001 |

## B. Fragile or dishonest code

| Level | Pattern | Do instead | Rule |
|---|---|---|---|
| Block | Swallowed error: empty `catch`, `except: pass` | Handle, rethrow, or annotate why ignoring is safe | COR001 |
| Block | Elision marker written into a file ("rest of the code unchanged") | Write the complete code | HON001 |
| Block | Assertion that cannot fail | Assert the real behavior | HON003 |
| Block | Claiming done without running the code and tests this turn | Run them, report the output | none |
| Block | Calling a function, flag, endpoint, or import that does not exist | Check the real signature or docs | none |
| Block | Happy path only: no handling for empty, invalid, error, unauthorized | Write those branches with the feature | none |
| Block | Unbounded list, loop, upload, or query; network call with no timeout | Paginate, cap, set a timeout | COR003 |
| Review | Placeholder implementation, mock data, simulated call | Finish it, or name it in the report | HON002 |
| Review | Skipped or focused test | Fix the test or state why it is off | HON004 |
| Review | Check silenced wholesale (`@ts-ignore`, blanket `eslint-disable`, `--no-verify`) | Fix the cause, or silence one named rule with a reason | HON005 |
| Review | Debugger statement left behind | Remove it | COR002 |
| Review | Error logged and then dropped (`catch (e) { console.log(e) }`) | Surface it to the caller and the user | COR006 |
| Review | Hardcoded `localhost` URL in application code | Read the base URL from configuration | COR005 |
| Review | Array index as a React key; async function passed to `useEffect` | A stable id; define the async function inside | COR007, COR008 |
| Review | Comment that narrates the edit ("changed from", "added:", "<-- add this") | Delete it; history belongs in the commit | HON006 |
| Review | New dependency where the standard library would do | Use the standard library | none |
| Review | Abstraction, option, or generic layer on first use | Wait for the third repetition | none |
| Review | Feature, endpoint, or setting nobody asked for | Propose it | none |

## C. Generic interface

One default alone proves nothing. Inter, a gradient, or a centered heading can each be right. The
signal is several unexamined defaults together with no link to the product. Review the whole
system before changing one style.

| Level | Pattern | Do instead | Rule |
|---|---|---|---|
| Review | Purple or indigo gradient on the hero, the button, or a background blob | A palette derived from the product | SLOP001 |
| Review | Gradient-filled headline text | Solid color with real typographic contrast | SLOP004 |
| Review | Same large radius and large shadow on every card | Vary size and weight to show hierarchy | SLOP002 |
| Review | Inter or the system font as the only typeface, with no type scale | A type system with roles, chosen for the product | SLOP005 |
| Review | Centered hero, three feature cards, testimonials, pricing, call to action | A structure that follows the content | none |
| Review | Untouched component-library defaults, glass blur with no purpose, stock team photo | Restyle through tokens; real imagery or none | none |
| Review | Animating every property, or the same fade on everything | Name the properties; animate for a reason | UX008 |
| Review | Transition on a layout property (width, height, top, left, margin) | Animate transform or opacity | UX021 |
| Review | Glass panel (blur over a translucent fill) as the default surface | Keep it only where it serves legibility | SLOP006 |
| Review | Hover lift or scale on every card; bouncing or pinging badges | Give hover a job; guard motion with `motion-safe` | SLOP007, SLOP008 |
| Review | `z-index: 9999` and other arbitrary layers | A small named layer scale | UX016 |
| Block | Lorem ipsum or another unreplaced placeholder shipped as content | Real content, or a placeholder the report names | COPY001 |
| Review | Placeholder image service, "John Doe", "Acme Corp" | Real content | COPY002 |
| Block | Redrawn browser chrome, fake code window, or fake device frame presented as the product | A real screenshot, or leave it out | none |

## D. Missing interface work

| Level | Pattern | Do instead | Rule |
|---|---|---|---|
| Block | A view without its empty, loading, and error states | Build every state the view can reach | none |
| Block | A form without inline validation and a pending state on submit | Add both; keep the user's input on error | none |
| Block | Image without alt text; input without a label; icon button without a name | Add them | UX003 |
| Block | Viewport that blocks zoom | Remove `user-scalable=no` and `maximum-scale=1` | UX006 |
| Block | Control that cannot be reached or operated by keyboard | A real button or link, or role, tabindex, and key handlers | UX004 |
| Block | Text or controls below WCAG AA contrast | 4.5:1 for text, 3:1 for large text and controls | none |
| Block | Motion with no `prefers-reduced-motion` fallback | A fade under 150ms or no motion | none |
| Block | Horizontal scroll on the page body | Fix the element that overflows | UX002, SLOP003 |
| Review | Focus outline removed | A visible `:focus-visible` style | UX001 |
| Review | Link with `href="#"`, positive `tabindex`, text under 12px | A real destination or a button; natural order; larger text | UX005, UX007, UX009 |
| Review | `html` element without `lang` | Declare the page language | UX010 |
| Review | Icon-only button or link without a name; placeholder as the only label | `aria-label` or visually hidden text; a real label | UX011, UX012 |
| Review | Media that autoplays with sound | Mute it, or wait for the user | UX013 |
| Review | Paste blocked on a field; autofill turned off on password, email, or phone | Allow paste; set the right `autocomplete` token | UX014, UX015 |
| Review | `height: 100vh` or `h-screen` for a full-height layout | `100dvh`, with `100vh` as the fallback | UX017 |
| Review | Justified body text; link text such as "click here" | Start-aligned text; name the destination | UX018, UX019 |
| Review | `alert()` or `confirm()` as interface | An inline message or a dialog component | UX020 |

## E. Copy

| Level | Pattern | Do instead | Rule |
|---|---|---|---|
| Block | Invented metric, testimonial, customer, award, citation, urgency, or scarcity | Real proof, or none | COPY004 |
| Block | A claim presented as verified when its source was not checked | Check it or cut it | none |
| Block | A destructive action behind "Continue" or "OK" | Name the consequence on the button | none |
| Block | Assistant chat reply left in a file ("Certainly! Here is", "As an AI") | Remove it | COPY007 |
| Review | Filler and hype phrases | Say what the product does in plain words | COPY003 |
| Review | Stock generated phrasing ("delve into", "it is not just X, it is Y", "whether you are a X or a Y") | Say the specific thing | COPY008 |
| Review | Error message that says nothing ("Something went wrong", "Oops!") | State what failed and what the user can do next | COPY009 |
| Review | Em dashes, emoji as bullets | Commas and periods; words or real icons | COPY005, COPY006 |
| Review | Copy that would fit a competitor unchanged | Name the real capability, audience, and limit | none |

## Using this list

Before reporting, check your diff against every Block row. For each Review row you kept, write one
line of reason in the report. One unfixed Block means the task is not done.
