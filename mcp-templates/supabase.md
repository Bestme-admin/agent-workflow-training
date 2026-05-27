# Supabase MCP — setup template

## What this is for

Direct query access to your Supabase database from the agent — schema inspection, log fetching, migration drafting + applying, advisor checks. **The framework restricts ad-hoc writes only:**

- `mcp__supabase__execute_sql` with mutating SQL is **denied** by `deny-supabase-writes.js`. Ad-hoc DML/DDL via the SQL editor bypasses the migration record — propose the SQL, then turn it into a migration.
- `mcp__supabase__apply_migration` is **allowed** — this is the intended write path. Migrations are versioned files under `supabase/migrations/`, replayable on staging/prod, reviewable in PRs.

This split keeps schema/data changes visible and replayable while still preventing one-shot `UPDATE users SET ...` accidents.

## Required env vars

| Var | Purpose | Where to get it |
|---|---|---|
| `SUPABASE_PROJECT_REF` | The project ref (`xxxxxx.supabase.co` → `xxxxxx`) | Supabase Dashboard → Project Settings → General |
| `SUPABASE_ACCESS_TOKEN` | Personal access token for the management API | Supabase Dashboard → Account → Access Tokens |

For local-only Supabase (Docker):

| Var | Purpose | Default |
|---|---|---|
| `SUPABASE_LOCAL_URL` | Local Postgres URL | `postgresql://postgres:postgres@127.0.0.1:54322/postgres` |
| `SUPABASE_LOCAL_PUBLISHABLE_KEY` | Local anon publishable key | from `npx supabase status` |

## .mcp.json snippet (cloud)

```json
{
  "mcpServers": {
    "supabase": {
      "command": "npx",
      "args": [
        "-y",
        "@supabase/mcp-server-supabase@latest",
        "--project-ref=${SUPABASE_PROJECT_REF}",
        "--read-only"
      ],
      "env": {
        "SUPABASE_ACCESS_TOKEN": "${SUPABASE_ACCESS_TOKEN}"
      }
    }
  }
}
```

**Note on `--read-only`:** Supabase's own MCP server supports a `--read-only` flag that prevents the server from even *attempting* writes. Use it — it's defense in depth alongside the framework's hook. The hook catches it at the agent boundary; `--read-only` catches it at the server boundary.

## .mcp.json snippet (local Docker)

```json
{
  "mcpServers": {
    "supabase-local": {
      "command": "npx",
      "args": ["-y", "@supabase/mcp-server-postgres@latest"],
      "env": {
        "DATABASE_URL": "${SUPABASE_LOCAL_URL}"
      }
    }
  }
}
```

## .env.example entry

Add to your project's `.env.example`:

```bash
# Supabase MCP
SUPABASE_PROJECT_REF=your-project-ref-here
SUPABASE_ACCESS_TOKEN=your-pat-here

# Local Supabase (optional)
SUPABASE_LOCAL_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres
```

## Verification after install

In a fresh Claude Code session:

1. Ask the agent to run `mcp__supabase__list_tables` — should succeed.
2. Ask the agent to run `mcp__supabase__execute_sql` with `SELECT 1` — should succeed.
3. Ask the agent to run `mcp__supabase__execute_sql` with `INSERT INTO ...` — should be **denied by the hook** with the framework's message about human-execution.

If step 3 doesn't deny, the hook isn't wired — check `<project>/.claude/settings.json` `hooks.PreToolUse` matches `mcp__supabase__execute_sql`.

## Why ad-hoc writes are blocked but migrations are not

- **`execute_sql` writes** = invisible. Run once, gone — no trace in git, no replay possible. That's the failure mode the hook prevents.
- **`apply_migration`** = visible by construction. Each migration is a numbered file under `supabase/migrations/` that gets committed, replayed on staging, and reviewable in a PR. The agent can apply migrations directly because the *file* is the audit trail.

Workflow: agent investigates schema → drafts migration file → runs `apply_migration` → human reviews the migration file in PR.

For conflicting migrations from multiple agents/devs in flight, see the `supabase-migration-merge` skill (coming soon).
