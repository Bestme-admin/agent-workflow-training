# MCP setup templates

Per-MCP recipes for wiring tools into a Claude Code project. **Do NOT commit real credentials** — every template uses placeholder values that you replace from your team's secret store (1Password, Bitwarden, the deployment vault, etc.).

## What's in here

| Template | What it does | Scope |
|---|---|---|
| [`supabase.md`](supabase.md) | Supabase MCP — DB schema queries, log inspection, migration drafting. Read-only via the framework's hook (writes go to humans). | per-project |
| [`freedcamp.md`](freedcamp.md) | Freedcamp MCP — one MCP **per project** in your Freedcamp workspace. Tasks, comments, lists. | per-project, one server per Freedcamp project |
| [`figma.md`](figma.md) | Figma MCP — read access to design files, frame export, component/token inspection. Read-mostly. | per-project |

## Where MCP config lives

Claude Code reads MCP server config from `.mcp.json` at the project root, or from `~/.claude.json` for user-scope servers. This framework recommends:

- **Project scope** for anything that talks to project-specific data (your Supabase DB, your Freedcamp project ID). Commit `.mcp.json` so the team shares it; keep secrets in `.env` (which the framework already blocks the agent from reading).
- **User scope** for personal tools that aren't project-bound (your personal Gmail, generic search). Goes in `~/.claude.json` (per-user, not committed).

## Pattern for credential handling

1. Add the MCP server config to `.mcp.json` with placeholders like `${SUPABASE_PUBLISHABLE_KEY}`.
2. Document the required env vars in `.env.example` (committed) — names only, no values.
3. Real values go in `.env` (gitignored, agent can't read it).
4. The MCP server reads from the shell environment at startup.

This way the agent has the tool available but never sees the secret directly.

## Adding a new MCP

If you're wiring up an MCP that isn't in this folder yet:

1. Copy the closest template as a starting point.
2. Write a one-paragraph "What is this for" so the next person knows when to use it.
3. List the required env vars in a small table.
4. Note any framework hook interactions (e.g., "writes go through `deny-X-writes.js`").
5. PR it back to `agent-workflow-training` so other projects benefit.
