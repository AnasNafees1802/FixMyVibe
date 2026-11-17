# Review method

Use this in audit mode (reviewing existing work without editing it) and in review mode (your own
pending diff). A model scoring its own work from 1 to 5 reports 4s and 5s, so this method does not
use scores. A finding stands only if it survives an attempt to disprove it.

## Step 1: collect candidates

1. Run the audit on the target: `bash bin/fixmyvibe-audit.sh <path>` or
   `fixmyvibe-audit.ps1 <path>`. Each BLOCKER and WARNING is a candidate, not yet a finding.
2. Read the code for what a text scan cannot see. Work through the questions for each axis that
   applies.

| Axis | Questions |
|---|---|
| Security | Who can call this? What stops user A from reaching user B's data? Where does untrusted input enter, and what sink does it reach? |
| Correctness | What happens on empty, invalid, huge, slow, or repeated input? Does every call resolve to a real API? |
| Tests | Does a test fail when the behavior breaks? Is there a failure case? Was anything skipped or silenced? |
| Maintainability | Does it match the project's conventions? Is anything duplicated, dead, or more general than its one use needs? |
| Honesty | Does the work do what was asked, and is every stub or mock disclosed? |
| Interface | Does every state exist? Can it be used by keyboard? Does it read as one system built on tokens? Would it pass for a generator default? |
| Copy | Is every claim real? Could the sentence be pasted into a competitor's page unchanged? |
| AI features | Can model or retrieved output reach a tool, a query, or a permission check unvalidated? |

## Step 2: try to disprove each candidate

Start from the position that the candidate is wrong. Keep it only if you can state all three:

- **Location:** `file:line`.
- **Trigger:** the specific input, user, or sequence that makes it fail.
- **Consequence:** what an attacker gains or what a user loses.

If you cannot trace the path from the trigger to the consequence, drop it or list it under
"could not confirm". Report nothing you are less than about 80 percent sure of as a confirmed
finding.

Not findings: style preferences the project does not share, missing features nobody asked for,
theoretical issues with no reachable trigger, and anything in generated or vendored files.

## Step 3: rank

- **Blocker:** a reachable path to unauthorized access, code execution, secret exposure, or data
  loss; a claim of done for work that does not run; a user who cannot complete the task.
- **Major:** broken behavior or a missing control with real user impact.
- **Minor:** maintainability or polish.

Rank by impact on a real user, not by which rule matched.

## Output format (audit mode)

```
FixMyVibe audit: src/api
Tier: sensitive. Profiles: web API.
Ran: fixmyvibe-audit src/api (2 blockers, 5 warnings), read 14 files.

Findings
1. [blocker][security] src/api/orders.ts:41. GET /orders/:id returns any order by id.
   Trigger: a signed-in user requests another user's order id.
   Consequence: every order is readable by every account.
   Fix: filter by the session's user id in the query.
2. [major][correctness] src/api/upload.ts:18. No size limit on the upload body.
   Trigger: a 5 GB request. Consequence: the process runs out of memory.
   Fix: cap the body and reject with 413.
3. [minor][maintainability] formatDate exists in utils.ts:9 and helpers.ts:22. Keep one.

Could not confirm
- SEC201 at src/ui/Preview.tsx:12 (raw HTML sink). The source of `html` is outside the files reviewed.

Not reviewed: deployment configuration, dependency advisories.
```

Recommend fixes; do not apply them. Applying fixes is a separate request.

## Review mode

Run the same three steps on your own diff, then fix what stands. Review the diff as if someone
else wrote it: read what is there, not what you meant to write. Where the harness offers a
subagent with fresh context, hand it the diff and this file, and treat its findings as candidates.
