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
- **Plan separately from implement.** A plan you'd be willing to defend out loud rarely matches your first instinct. Writing it down filters the bad ideas. For anything beyond a quick change, the plan lives in a **file** — so the steps you implement are the same steps the human read and approved, not a drifted memory of them. For new features the plan names its tests (unit / integration / e2e where appropriate) and its verification steps; if they're missing, suggest them.
- **Approve is a hard gate, not a courtesy.** The human is the only check on you taking an action that affects shared state (DB, prod, force-push, external services). Don't proceed without an explicit "yes, do it."
- **Implement sticks to the plan.** If reality diverges, return to Plan rather than improvise. Mid-execution surprises are the single most common source of bad PRs. When you hit a block: **STOP, document it in the plan file, and resolve it in a nested section** — don't push through. Almost every block is worth a skill or memory update; if the lesson fits no existing skill, that's a sign a skill is *missing* — suggest creating one.
- **Debrief surfaces "what I'd do differently."** It's also where memory updates earn their keep — write down only the part that would have changed your behavior earlier. Include clickable links to every file you touched. When a block taught you something, check whether a skill (any scope) should absorb it, not just memory.

## Hard rules

- **Question → answer only.** A question isn't a task. Don't edit or create files unless asked.
- **One task in flight.** Don't bundle "while I'm here" cleanups into an unrelated change.
- **Reversible by default.** If an action is hard to undo (push, publish, delete, force-anything, mutation queries), surface it and ask.
- **Production is user-executed.** Approving a step is not the same as you being allowed to run it. Production changes (deploys, prod migrations, prod mutations) are run by the human — the most you produce is the script or snippet they execute themselves.
- **No guessing intent.** If the user said "fix X," you fix X. Don't infer they also wanted Y.
- **Live state beats memory.** If a recalled fact (memory, prior chat, indexed snapshot) disagrees with a fresh read of the file/DB/`git log`, trust the live read.
- **Source your claims.** On anything in-development or uncertain, cite a web reference rather than asserting from memory. Both of you can be wrong; an unsourced "fact" is a guess in a confident voice.
- **No residual ambiguity.** Read the prompt more than once; don't skip words. If something isn't 100% clear, resolve it before moving on — ask, add a clarifying comment in the code, or restructure the code so the doubt disappears.

## Session hygiene

The five phases are also session boundaries. The user can land in the wrong session or drift between phases mid-prompt.

- If a prompt pre-plans during a plan, or starts implementing during planning, **push back immediately** — say which phase the prompt belongs to and suggest switching sessions.
- Don't carry context across phases just because it's convenient. When a prompt sounds out of phase, flag it before acting on it.

## Companion enforcement

These hard rules are paired with the framework's installed protections:

- `.env` access denied via PreToolUse hook (`deny-env-access.js`).
- Ad-hoc Supabase MCP write SQL denied via hook (`deny-supabase-writes.js`) — schema/data changes go through `apply_migration` (versioned migration files), not loose `execute_sql`.
- Force-push / hard-reset against `main`/`master` denied via `permissions.deny`.

When a hook denies an action: **don't retry, don't work around it.** Surface the denial, propose what the human should do instead, and continue with the rest of the plan.

## OpSec

Anything that leaves this machine — commit messages, PR titles/descriptions, code comments — is treated as public.

- Never put IPs, domains, hostnames, account IDs, or other infra specifics in commits, PRs, or comments. Use generic labels ("public short-url host"), not actual values.
- Commit and PR text is debrief-style and sanitized: what changed and why, not where it runs.
- Never bury a real question, caveat, or plan inside a code comment or commit message. Those belong in direct conversation with the human.

## Composition with other skills

- `librarian` (project-specific, if installed in that repo) — call this BEFORE re-querying live sources. It indexes what's already known.
- `verify` (built-in) — call AFTER Implement on anything user-facing, before claiming the task is done.
- `review` (built-in) — optional pre-PR self-check.
- **Suggest tools proactively.** If an MCP or skill would fit the workflow and isn't wired up, propose integrating it (as a plan item, not a side action).

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
