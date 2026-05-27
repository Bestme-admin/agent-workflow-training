# Google MCPs (Gmail / Calendar / Drive) — setup template

## What this is for

OAuth-based access to a team member's personal Google services. Used sparingly — most project work shouldn't touch personal email or calendar. Common legitimate uses:

- Reading a forwarded spec/email thread referenced in a task.
- Pulling a Google Doc the team is using as a working draft.
- Reading calendar to coordinate "when can we ship" timing.

**Not for**: sending email on the user's behalf, calendar invites, or anything that creates outbound state. Treat these MCPs as read-mostly and confirm before writes.

## Scope

User scope (`~/.claude.json`), not project scope. These authenticate against the individual's Google account; they don't belong in committed project config.

## Setup

The Google MCPs use a delegated OAuth flow. There's no API key to paste — the first invocation runs an `authenticate` tool that opens a browser, user grants scopes, server stores a refresh token locally.

### Initial auth (run once per machine)

```
mcp__claude_ai_Gmail__authenticate
mcp__claude_ai_Gmail__complete_authentication
```

Same pattern for Calendar and Drive — each authenticates independently because they have different OAuth scope sets.

## ~/.claude.json snippet

```json
{
  "mcpServers": {
    "claude_ai_Gmail": {
      "type": "http",
      "url": "https://mcp-gateway.anthropic.com/google/gmail"
    },
    "claude_ai_Google_Calendar": {
      "type": "http",
      "url": "https://mcp-gateway.anthropic.com/google/calendar"
    },
    "claude_ai_Google_Drive": {
      "type": "http",
      "url": "https://mcp-gateway.anthropic.com/google/drive"
    }
  }
}
```

*(URLs are illustrative — use the actual gateway URLs from your team's MCP server registry.)*

## Recommended guardrails

If you wire these in, add a project-level deny pattern for write operations:

```json
"deny": [
  "mcp__claude_ai_Gmail__send_email",
  "mcp__claude_ai_Gmail__create_draft",
  "mcp__claude_ai_Google_Calendar__create_event",
  "mcp__claude_ai_Google_Calendar__delete_event",
  "mcp__claude_ai_Google_Drive__create_file"
]
```

The agent can read inbox/calendar/drive but not mutate any of them. Mutation = human via the actual app.

## Verification

1. Run authenticate flow once per service.
2. Test reads (`Gmail.search`, `Calendar.list_events`) — should succeed.
3. Test a denied write (`Gmail.send_email`) — should be denied by `permissions.deny`.

## When NOT to wire these

If the project genuinely doesn't need them, skip them entirely. Don't install OAuth-backed read access "just in case" — every additional credential is a potential leak vector.
