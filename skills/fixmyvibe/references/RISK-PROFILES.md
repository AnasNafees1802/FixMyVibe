# Risk profiles: choose the checks that match the system

No checklist covers every kind of software. Before editing, identify every applicable profile below.
Load the named standard, map trust boundaries, then test the failure modes that can cause real harm.
If the project spans profiles, combine them. A mobile app with an API needs both profiles.

Contents: Risk tier · Common core · Web and API · Mobile · Desktop and CLI · Library · Infrastructure
and CI · Data pipeline · Embedded · AI-enabled · Evidence rule

## Risk tier

Choose the highest tier that applies to the change. `SKILL.md` section 1 adds a Quick tier below
Standard for changes with no new input, data flow, or UI state.

- **Standard:** local presentation or pure logic with no new trust boundary. Run project tests, static
  checks, the FixMyVibe audit, and UI checks where relevant.
- **Sensitive:** authentication, authorization, money, personal data, uploads, network calls,
  parsers, dependencies, migrations, cryptography, or privileged automation. Add a written abuse
  case, security tests, dependency and secret scans, and manual review of the boundary.
- **Critical:** safety, healthcare, finance, identity, destructive operations, production access,
  multi-tenant isolation, or an agent that can take consequential actions. Stop before deployment
  unless a qualified human reviews the threat model, tests, residual risk, and rollback plan.

Never lower the tier because a patch is small. A one-line authorization error can be critical.

## Common core, every profile

1. List assets, actors, entry points, trust boundaries, sensitive data, and worst credible abuse.
2. Trace untrusted data from source to validation, authorization, storage, logs, and dangerous sinks.
3. Prove deny-by-default access, least privilege, safe failure, bounded work, and safe recovery.
4. Verify dependencies, lockfiles, build inputs, release artifacts, and secret handling.
5. Record what was tested, what was not, scanner limitations, and any accepted residual risk.

## Web application and API

Baseline: OWASP ASVS 5.0 for web controls and OWASP API Security Top 10 for API abuse cases.

- Test object, property, and function-level authorization using two users and at least two roles.
- Validate request body, path, query, headers, content type, upload bytes, and response shape.
- Check injection, XSS, CSRF, SSRF, open redirects, request smuggling assumptions, and unsafe parsing.
- Bound pagination, payloads, uploads, expensive queries, retries, and sensitive business flows.
- Review sessions, cookies, token audience/issuer/expiry, logout/revocation, CORS, cache headers, and
  security headers. Do not put authorization decisions only in the client.

## Mobile application

Baseline: OWASP MASVS and MASTG. Review the backend as a separate Web/API profile.

- Check secure local storage, backups, logs, screenshots, clipboard use, and notification content.
- Check deep links, WebViews, exported components, intents/IPC, permissions, and platform boundaries.
- Validate TLS configuration, endpoint identity, update policy, signing, and release build settings.
- Treat device input, QR codes, files, NFC/Bluetooth, restored backups, and API responses as untrusted.
- Decide whether tamper resistance is needed. Never treat obfuscation or root detection as access control.

## Desktop application and CLI

- Treat file paths, archives, config files, environment variables, stdin, plugins, URLs, and IPC as
  untrusted. Prevent traversal, symlink races, unsafe temp files, and archive extraction outside root.
- Use argument arrays for child processes. Never assemble a shell command from untrusted strings.
- Follow OS credential-store and least-privilege conventions. Do not require administrator rights
  without a concrete reason.
- Make destructive commands explicit, previewable, scoped, and recoverable. Test cancellation and
  partial failure. Never silently overwrite user data.
- Sign releases where the ecosystem supports it and verify update metadata before installation.

## Library, SDK, and package

- Treat the public API, serialized formats, and compatibility promises as trust boundaries.
- Test malformed input, concurrency, cancellation, resource exhaustion, and version skew.
- Minimize transitive dependencies and exported surface. Pin release tooling and generate an SBOM
  when the ecosystem supports it.
- Document security assumptions and safe defaults. A library must not quietly weaken its caller.
- Check package ownership, provenance, typosquatting risk, release permissions, and artifact contents.

## Infrastructure, CI/CD, and cloud

- Scan IaC with the ecosystem's established tool. Review public exposure, IAM, network boundaries,
  encryption, secret references, backups, retention, and deletion protection.
- Pin CI actions and build images to immutable versions where practical. Restrict token permissions,
  fork behavior, artifact trust, caches, and deployment environments.
- Never run untrusted pull-request code with production secrets or a privileged runner.
- Plan rollback and disaster recovery. Validate the plan rather than only documenting it.
- Treat generated plans as review evidence. Do not auto-apply destructive infrastructure changes.

## Data pipeline and backend job

- Validate provenance, schema, encoding, size, partition keys, and late or duplicate records.
- Make retries idempotent. Define checkpoint, replay, poison-record, and partial-write behavior.
- Prevent formula injection in exported spreadsheets and unsafe deserialization in imported data.
- Bound memory, concurrency, fan-out, and spend. Test an empty batch and a maximum-size batch.
- Protect sensitive fields through collection, transit, storage, logs, analytics, and deletion.

## Embedded and IoT

Baseline: OWASP ISVS plus relevant hardware and safety standards.

- Review boot trust, firmware signing, update rollback, debug ports, device identity, key storage,
  physical access, radio interfaces, and offline behavior.
- Fail safe when power, clock, network, sensor, or dependency data is wrong.
- Separate safety controls from convenience features. Remote access must not bypass local safety.
- Plan credential rotation, fleet recovery, end-of-life updates, and vulnerability disclosure.

## AI-enabled system

Load `AI-SYSTEMS.md`. AI output is untrusted input, and model behavior is nondeterministic. Apply the
underlying Web/API, data, mobile, or infrastructure profile too.

## Evidence rule

For every applicable profile, report:

- risk tier and selected profiles;
- trust boundaries and top abuse cases;
- tests and scanners run, with versions or commands;
- findings fixed, findings accepted with owner/reason, and checks not run;
- rollback or recovery path for sensitive and critical work.

A missing applicable profile is a gate failure.
