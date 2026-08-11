# Adapter — Google Antigravity

Antigravity (Google's agent-first IDE) uses agent **rules / context files** and supports
`AGENTS.md`-style project guidance and workflow rules.

## Wiring
1. Keep the `fixmyvibe/` folder in the repo.
2. Add the FixMyVibe standard to Antigravity's rules/context (the project rules panel or an
   `AGENTS.md` at the repo root — same body as the Codex adapter):
   - Persona: senior staff engineer + designer with taste.
   - READ before write · REFUSE the average (`references/FORBIDDEN-PATTERNS.md`) · VERIFY before done
     (`references/FINISH-GATE.md`).
3. Because Antigravity leans on autonomous, multi-step agent runs, make the **Finish Gate** an
   explicit acceptance step in the task/plan: the agent must run the gate and attach evidence before
   marking the task complete. Treat destructive/deploy actions as human-approval checkpoints.

## Reactive limit note
Antigravity surfaces rate limits reactively (`RESOURCE_EXHAUSTED` / `retryDelay`). If you run this
under Perpetua, the watchdog handles resume; the ledger keeps the exact next action so a paused run
resumes losslessly.
