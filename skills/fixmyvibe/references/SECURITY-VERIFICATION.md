# Security verification: evidence matched to risk

The bundled audit catches a small set of high-signal text patterns. It cannot prove authorization,
business logic, safe data flow, dependency integrity, runtime configuration, or absence of a
vulnerability. Never translate “no findings” into “secure.”

## Select the verification stack

Use tools already configured by the repository first. For a sensitive or critical change, cover the
applicable layers below. Do not install a random scanner solely to satisfy the checklist.

| Layer | Evidence |
|---|---|
| Behavior | unit, integration, contract, and end-to-end tests for success, edge, failure, and abuse |
| Source | compiler/type checker, linter, SAST, manual source-to-sink review |
| Secrets | full-history secret scanner when exposure is suspected, diff scan for every change |
| Dependencies | lockfile-aware vulnerability audit, provenance/maintainer review, license policy |
| Runtime | authenticated DAST or protocol tests against an authorized disposable environment |
| Infrastructure | IaC/container scan, least-privilege review, deployment plan and rollback test |
| UI | automated accessibility scan plus keyboard, zoom, contrast, and screen-reader spot checks |
| Supply chain | pinned CI inputs, minimal token permissions, artifact inventory/SBOM, signed releases where supported |

Prefer ecosystem tools with maintained rule sets. Examples include Semgrep or CodeQL for source,
Gitleaks for secrets, OSV-Scanner or the package manager's audit for dependencies, Trivy for
containers/IaC, and axe-core for browser accessibility. Tool choice depends on the stack and project.
Verify current documentation before adding one.

## Manual checks automation cannot replace

- authorization and tenant isolation using distinct identities;
- business-logic abuse, race conditions, replay, duplicate side effects, and stale confirmation;
- privacy, retention, logging, backups, recovery, and deletion behavior;
- whether validation occurs at the actual trust boundary and encoding occurs at the output sink;
- whether a warning is reachable with attacker-controlled data;
- whether the UI state and copy tell the truth.

## Finding discipline

Each finding needs a rule or threat, affected location, evidence, reachability, impact, confidence,
recommended fix, and verification step. Rank by exploitable impact, not regex severity alone.

- **Blocker:** credible path to unauthorized access, code execution, secret exposure, data loss,
  safety impact, tenant escape, or an unreviewed critical-risk change.
- **Major:** broken correctness or control with material user impact, or a likely security weakness.
- **Review:** dangerous sink or weak signal whose exploitability needs context.
- **Note:** maintainability or polish issue with no present material impact.

Do not suppress a result because the file is named test, sample, or example. Real credentials leak
there too. Suppress only a proven placeholder or a reviewed finding, as narrowly as possible.
For the bundled audit, use an inline rule-specific annotation with a reason:
`fixmyvibe: allow SEC201 trusted-sanitized-renderer`. The rule ID and non-empty reason are required.
Suppressions remain visible and counted in audit output. Never add one solely to make CI green;
record the data-flow or product reason in review.

## Regression and exit criteria

Turn every confirmed defect into a regression test at the lowest useful layer. Re-run the original
reproduction, the focused test, the relevant suite, and the scan that found it. A finding is closed
only when the exploit or failure no longer reproduces and the intended behavior still works.

If a required tool cannot run, mark the gate incomplete. Report the command, error, affected scope,
and next action. Scanner failure must never become a clean pass.

## Baselines

- OWASP ASVS 5.0 and API Security Top 10 for web and API controls
- OWASP MASVS/MASTG for mobile
- OWASP SCVS and OpenSSF guidance for dependencies and project supply-chain posture
- NIST SP 800-218 SSDF for secure development practice
- W3C WCAG 2.2 Level AA for web accessibility

Check the current official version when the work is sensitive or critical.
