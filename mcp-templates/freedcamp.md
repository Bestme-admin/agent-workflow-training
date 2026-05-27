# Freedcamp MCP — setup template

## What this is for

Project management integration with Freedcamp — tasks, comments, lists, time tracking. The pattern is **one MCP server per Freedcamp project**, not one server for the whole workspace, because the MCP scopes operations to its configured project_id.

If your team has multiple Freedcamp projects (the BestMe workspace has 4: App, B-Control, Web, General), you wire up one MCP per project and they appear as separate tool namespaces:

```
freedcamp-app        →  mcp__freedcamp-app__freedcamp_*
freedcamp-bcontrol   →  mcp__freedcamp-bcontrol__freedcamp_*
freedcamp-web        →  mcp__freedcamp-web__freedcamp_*
freedcamp-general    →  mcp__freedcamp-general__freedcamp_*
```

This is by design: it makes "create a task in the App project" different from "create a task in the B-Control project" at the tool-call level. No accidental cross-project writes.

## Required env vars (per project instance)

| Var | Purpose | Where to get it |
|---|---|---|
| `FREEDCAMP_API_KEY_<PROJECT>` | API key for the project | Freedcamp → Profile → API |
| `FREEDCAMP_API_SECRET_<PROJECT>` | API secret (used for HMAC-SHA1 signing) | Same place |
| `FREEDCAMP_PROJECT_ID_<PROJECT>` | The numeric project_id | URL: `freedcamp.com/view/<project_id>/...` |

Replace `<PROJECT>` with a stable slug: `APP`, `BCONTROL`, `WEB`, `GENERAL` etc.

## .mcp.json snippet (one project)

```json
{
  "mcpServers": {
    "freedcamp-app": {
      "command": "npx",
      "args": ["-y", "@freedcamp/mcp-server@latest"],
      "env": {
        "FREEDCAMP_API_KEY": "${FREEDCAMP_API_KEY_APP}",
        "FREEDCAMP_API_SECRET": "${FREEDCAMP_API_SECRET_APP}",
        "FREEDCAMP_PROJECT_ID": "${FREEDCAMP_PROJECT_ID_APP}"
      }
    }
  }
}
```

For multiple projects, repeat the block with a different server name + suffix.

## .env.example entry

```bash
# Freedcamp — one set per project
FREEDCAMP_API_KEY_APP=
FREEDCAMP_API_SECRET_APP=
FREEDCAMP_PROJECT_ID_APP=

FREEDCAMP_API_KEY_BCONTROL=
FREEDCAMP_API_SECRET_BCONTROL=
FREEDCAMP_PROJECT_ID_BCONTROL=

# etc.
```

## Verification after install

1. `mcp__freedcamp-<project>__freedcamp_list_tasks` — should return the project's tasks.
2. Try a creation in a test list before trusting the agent with real lists.

## Working pattern

- **Create + update tasks** are *not* denied by the framework — Freedcamp tasks are reversible and don't affect production state. The agent can create follow-up tasks, log decisions, etc.
- **Delete tasks** are technically allowed but should be rare. If your team uses Freedcamp delete operations, add a project-level deny pattern for `mcp__freedcamp-*__freedcamp_delete_task`.
- The agent will **not** see private project history — only what the API key's owner has access to.

## Direct API fallback

If a one-shot operation isn't covered by the MCP, the Freedcamp REST API works with HMAC-SHA1 signing:

```
signature = HMAC-SHA1(secret, api_key + timestamp)
GET https://freedcamp.com/api/v1/<endpoint>?api_key=...&timestamp=...&hash=...
```

Useful when you need bulk operations or fields the MCP doesn't expose. Document the script in your project's `tools/` or similar.
