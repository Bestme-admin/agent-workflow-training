# ClickUp MCP — setup template

## What this is for

Alternative PM tool if your project uses ClickUp instead of (or alongside) Freedcamp. Covers tasks, lists, folders, comments, time tracking, custom fields, chat channels.

Most BestMe projects use Freedcamp — see [`freedcamp.md`](freedcamp.md). This template is included for projects that use ClickUp.

## Required env vars

| Var | Purpose | Where to get it |
|---|---|---|
| `CLICKUP_API_KEY` | Personal API token | ClickUp → Settings → My Apps → API Tokens |
| `CLICKUP_WORKSPACE_ID` | Team/workspace ID | ClickUp URL: `app.clickup.com/<workspace_id>/...` |

## .mcp.json snippet

```json
{
  "mcpServers": {
    "clickup": {
      "command": "npx",
      "args": ["-y", "@clickup/mcp-server@latest"],
      "env": {
        "CLICKUP_API_KEY": "${CLICKUP_API_KEY}",
        "CLICKUP_WORKSPACE_ID": "${CLICKUP_WORKSPACE_ID}"
      }
    }
  }
}
```

## .env.example entry

```bash
CLICKUP_API_KEY=
CLICKUP_WORKSPACE_ID=
```

## Recommended guardrails

ClickUp's MCP exposes destructive operations (delete task, delete list). Add project-level deny patterns:

```json
"deny": [
  "mcp__clickup__clickup_delete_task"
]
```

For *create/update* operations, leave them allowed — same logic as Freedcamp. PM-tool state is reversible and the agent often legitimately needs to log decisions, create follow-ups, update statuses.

## Verification

1. `mcp__clickup__clickup_get_workspace_hierarchy` — should return your workspace tree.
2. `mcp__clickup__clickup_search` with a known task title — should find it.
3. `mcp__clickup__clickup_delete_task` — should be denied by the deny pattern above.
