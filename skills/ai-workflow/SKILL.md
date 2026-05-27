---
name: ai-workflow
description: Canonical dev-iteration loop for working with Claude Code on BestMe projects. INVOKE at the START of any non-trivial task (anything beyond a single read/edit) — you read this, then drive the work through its five phases. Each project's CLAUDE.md must reference this skill as a requirement.
---

# ai-workflow — the iteration loop

Five phases. **Stop at any fork.** A "fork" is anywhere the spec is ambiguous, the user could plausibly want a different answer, or a fact you'd need to verify against live state.

| # | Phase | What you produce | What the human does |
|---|---|---|---|
| 1 | **Investigate** | A short read of current state — files inspected, facts confirmed, contradictions surfaced. | Reads, points out what you missed, corrects mental model. |
| 2 | **Plan** | A concrete step list with file paths + actions. Identifies risky steps, reversibility, blast radius. | Approves, edits, or sends back to Investigate. |
| 3 | **Approve** | (No new output — wait state.) | Says go, refines scope, or stops the task entirely. |
| 4 | **Implement** | The change itself, applied in the order from Plan, with brief status updates. | Catches drift in real time; you stop on any deviation. |
| 5 | **Debrief** | One paragraph: what changed, what didn't go as planned, anything the next session should know. Memory updates if applicable. | Acknowledges or asks for cleanup. |

## Why each phase exists

- **Investigate first.** Most "obvious" bugs aren't what they look like at first read. Acting on the second-impression understanding is cheaper than acting on the first.
- **Plan separately from implement.** A plan you'd be willing to defend out loud rarely matches your first instinct. Writing it down filters the bad ideas.
- **Approve is a hard gate, not a courtesy.** The human is the only check on you taking an action that affects shared state (DB, prod, force-push, external services). Don't proceed without an explicit "yes, do it."
- **Implement sticks to the plan.** If reality diverges, return to Plan rather than improvise. Mid-execution surprises are the single most common source of bad PRs.
- **Debrief surfaces "what I'd do differently."** It's also where memory updates earn their keep — write down only the part that would have changed your behavior earlier.

## Hard rules

- **Question → answer only.** A question isn't a task. Don't edit or create files unless asked.
- **One task in flight.** Don't bundle "while I'm here" cleanups into an unrelated change.
- **Reversible by default.** If an action is hard to undo (push, publish, delete, force-anything, mutation queries), surface it and ask.
- **No guessing intent.** If the user said "fix X," you fix X. Don't infer they also wanted Y.
- **Live state beats memory.** If a recalled fact (memory, prior chat, indexed snapshot) disagrees with a fresh read of the file/DB/`git log`, trust the live read.

## Companion enforcement

These hard rules are paired with the framework's installed protections:

- `.env` access denied via PreToolUse hook (`deny-env-access.js`).
- Ad-hoc Supabase MCP write SQL denied via hook (`deny-supabase-writes.js`) — schema/data changes go through `apply_migration` (versioned migration files), not loose `execute_sql`.
- Force-push / hard-reset against `main`/`master` denied via `permissions.deny`.

When a hook denies an action: **don't retry, don't work around it.** Surface the denial, propose what the human should do instead, and continue with the rest of the plan.

## Composition with other skills

- `librarian` (project-specific, if installed in that repo) — call this BEFORE re-querying live sources. It indexes what's already known.
- `verify` (built-in) — call AFTER Implement on anything user-facing, before claiming the task is done.
- `review` (built-in) — optional pre-PR self-check.

## When to skip phases

- **Trivial tasks** (rename a variable, fix a typo, run a known one-shot command): skip Investigate + Plan, go straight to Implement → quick Debrief.
- **Pure questions** ("what does X do?"): no phases needed. Answer in chat.
- **Recovery from a failed Implement**: never skip — go all the way back to Investigate to understand *why* it failed before re-Planning.

## What "done" looks like

A task is done when:
1. The plan is executed (or the plan was explicitly amended by the human and re-executed).
2. For UI/feature work — the change was exercised in the running app, not just type-checked.
3. The Debrief paragraph exists, even if it's three sentences.
4. Memory is updated **only if** the lesson would have changed your behavior earlier in the task.
