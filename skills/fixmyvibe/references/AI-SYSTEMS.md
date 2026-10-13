# AI systems: security, safety, and quality gate

Use this whenever the product calls a model, embeds content, retrieves documents, trains or fine-tunes
a model, or gives an agent tools. Apply the normal software risk profile too.

## Core model

Treat prompts, retrieved content, model output, tool results, model metadata, and uploaded files as
untrusted data. A system prompt is policy text, not a security boundary. Authorization, validation,
and confirmation must be enforced by deterministic code outside the model.

## Mandatory controls

1. **Prompt injection and data flow:** keep instructions separate from data where the API allows it.
   Mark untrusted context, minimize what is retrieved, and never let retrieved text alter permissions.
   Test direct and indirect injection through pages, documents, images, tool output, and memory.
2. **Tool safety:** use an allowlist with typed arguments, least-privilege credentials, timeouts,
   budgets, and audit logs. Require a human confirmation immediately before irreversible, financial,
   public, or cross-user actions. Re-check authorization at execution time.
3. **Output handling:** validate model output against a schema before parsing or acting. Encode it for
   the destination. Never pass raw output to SQL, a shell, HTML, a template engine, code execution,
   file paths, or privileged API parameters.
4. **Privacy:** minimize prompt data, redact secrets and personal data, define retention, honor data
   residency, and verify provider training settings. Do not log raw prompts by default.
5. **Retrieval:** enforce tenant filters before retrieval, not after generation. Preserve document
   ACLs, cite source identity, resist poisoned documents, and test cross-tenant queries.
6. **Model and dependency supply chain:** pin model/version where possible, authenticate artifacts,
   review licenses and data lineage, and test before changing a model, embedding model, system prompt,
   safety policy, or retrieval index.
7. **Availability and cost:** cap tokens, tool calls, recursion, retries, file size, concurrency, and
   spend. Handle provider timeout, refusal, malformed output, rate limits, and partial tool failure.
8. **Human factors:** disclose meaningful AI use, do not invent certainty, and provide correction,
   appeal, and fallback paths when output affects people. Never present generated citations as real
   until they resolve to the claimed source.

## Evaluation, not anecdotes

Create a versioned evaluation set from the actual product risks. Include ordinary tasks, edge cases,
abuse cases, multilingual input where relevant, and previously fixed failures. Record model, prompt,
tools, parameters, dataset version, and date so results can be reproduced.

Measure task-specific outcomes. At minimum assess correctness, harmful action rate, authorization
bypass, sensitive-data disclosure, injection resistance, refusal quality, citation validity, latency,
and cost. Set thresholds before running the evaluation. A few hand-picked demos do not count.

Run deterministic unit and integration tests around the model boundary. Run statistical evaluations
multiple times when nondeterminism can change the result. Preserve failing cases as regressions.

## Agent-specific abuse tests

- Untrusted content tells the agent to ignore policy, reveal secrets, or call a tool.
- A tool returns instructions disguised as data.
- The user requests another user's object by changing an identifier.
- The model supplies extra arguments, a dangerous URL, a traversal path, or a shell fragment.
- A confirmation becomes stale because the target or amount changes before execution.
- The agent loops, retries a side effect, exceeds its budget, or resumes after partial completion.
- Memory stores poisoned instructions, secrets, or data from the wrong tenant.
- A model/provider outage occurs halfway through a multi-step operation.

## Release evidence

State the model and prompt versions, applicable risk tier, evaluation dataset and thresholds, observed
results, unresolved limitations, monitoring signals, kill switch, and rollback target. Never claim an
AI system is safe or hallucination-free. State what was tested and the bounded result.

Primary baselines: NIST AI RMF and NIST AI 600-1 Generative AI Profile, plus the current OWASP
GenAI/LLM security guidance. Re-check their current versions for sensitive or critical releases.
