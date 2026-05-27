# agent-workflow-training

> **Guardrails + iteration loop for Claude Code, installed once and shared across projects.**

This repo is an installable framework that does two things:

1. **Drops policy** — deny rules + PreToolUse hooks — into `~/.claude/` and optionally into a project's `.claude/`, so the agent can't accidentally read your `.env`, force-push to `main`, or run a destructive SQL migration without a human in the loop.
2. **Ships an `ai-workflow` skill** — the canonical *plan → approve → implement → debrief* loop — that every project's `CLAUDE.md` references as required reading.

It's the seatbelt + the driving school, not the car. The car is whatever Claude Code project you bring.

---

## Why this exists

Working with Claude Code is fast. "Fast" is exactly when you cause expensive accidents: an agent that reads your secrets into chat context, runs `git push --force origin main`, or executes an `UPDATE users SET ...` query because it was helpfully trying to "fix the data."

You can't fix this with prompts. Prompts drift, get forgotten, and aren't enforceable. You fix it with **two layers**:

| Layer | Where it lives | What it catches |
|---|---|---|
| `permissions.deny` | `settings.json` | Clear-cut destructive patterns: `Read(.env)`, `Bash(git push --force origin main*)`, etc. |
| `PreToolUse` hooks | `settings.json` → small Node scripts | Cases that need *logic*: parsing SQL for write keywords, detecting `.env` paths inside arbitrary shell commands, etc. |

Anything not auto-denied still surfaces to you as an approval prompt — you stay in the loop on anything that isn't pre-vetted as safe.

The `ai-workflow` skill is the human-readable counterpart: when the agent reads it (one-line `CLAUDE.md` reference triggers it), it knows the team's iteration discipline — investigate before acting, plan before implementing, ask before doing anything irreversible.

---

## What's in the box

```
agent-workflow-training/
├── README.md                   you are here
├── LICENSE                     MIT
├── install.sh                  macOS + Linux installer
├── install.ps1                 Windows installer (PowerShell 7+)
│
├── settings/
│   ├── user.json               ~/.claude/settings.json template
│   └── project.json            <project>/.claude/settings.json template
│
├── hooks/                      cross-platform Node hooks
│   ├── deny-env-access.js      block reads/writes/shell access to .env*
│   └── deny-supabase-writes.js block ad-hoc mutating SQL via Supabase MCP execute_sql
│
├── skills/
│   ├── user/                   installed to ~/.claude/skills/ (cross-project)
│   │   └── ai-workflow/
│   │       └── SKILL.md        the dev iteration loop
│   └── project/                installed to <project>/.claude/skills/ (per-repo)
│       └── supabase-migration-merge/
│           └── SKILL.md        coordinate multi-branch migration merges via gh
│
└── mcp-templates/              per-MCP setup recipes
    ├── README.md
    ├── supabase.md
    ├── freedcamp.md
    ├── google.md
    └── clickup.md
```

---

## Install

### Requirements

- **Node.js 18+** — the hooks run on Node. Same Node you already have for the rest of your stack.
- **git** — to clone this repo.
- **Claude Code** — obviously.

### macOS / Linux

```bash
gh repo clone Bestme-admin/agent-workflow-training
cd agent-workflow-training
chmod +x install.sh
./install.sh                 # user-scope only
# or, to also install into the project you're standing in:
./install.sh --project
```

### Windows (PowerShell 7+)

```powershell
gh repo clone Bestme-admin/agent-workflow-training
cd agent-workflow-training
.\install.ps1                # user-scope only
# or, to also install into the project you're standing in:
.\install.ps1 -Project
```

### Install flags

| Flag (sh / ps1) | What it does |
|---|---|
| `--user-only` / `-UserOnly` | Default. Installs only `~/.claude/`. |
| `--project` / `-Project` | Also install into the current directory's `.claude/`. |
| `--project-only` / `-ProjectOnly` | Skip user scope entirely. |
| `--force` / `-Force` | Overwrite existing `settings.json` instead of writing a sidecar. |
| `--dry-run` / `-DryRun` | Print what would happen, change nothing. |

### What gets written

**User scope** (`~/.claude/`):
- `hooks/deny-env-access.js`
- `hooks/deny-supabase-writes.js`
- Everything under `skills/user/` → `~/.claude/skills/<skill-name>/SKILL.md` (currently: `ai-workflow`)
- `settings.json` *(if missing — otherwise `settings.json.agent-workflow-training` sidecar)*

**Project scope** (`<project>/.claude/`):
- Same hooks (duplicated into the project so the protections travel with the repo)
- Everything under `skills/project/` → `<project>/.claude/skills/<skill-name>/SKILL.md` (currently: `supabase-migration-merge`)
- `settings.json` *(or sidecar if existing)*

### After install: wire skills into your project

Add this block near the top of your project's `CLAUDE.md`:

```markdown
> **Required reading:** the `ai-workflow` skill (installed at `~/.claude/skills/ai-workflow/SKILL.md`).
> Read it before any non-trivial task.
>
> **Project-scope skills:** see `.claude/skills/` for repo-specific skills installed by `agent-workflow-training` — currently `supabase-migration-merge` (invoke when 2+ branches touch `supabase/migrations/`).
```

---

## What the agent can and can't do after install

| Action | Status | Caught by |
|---|---|---|
| Read `.env`, `.env.local`, `.env.prod` | **Denied** | `permissions.deny` + `deny-env-access.js` |
| `cat .env` / `Get-Content .env` in Bash | **Denied** | `deny-env-access.js` |
| Read `.env.example` | Allowed | — |
| Supabase MCP `SELECT * FROM ...` | Allowed | — |
| Supabase MCP `execute_sql` with `INSERT/UPDATE/DELETE/DROP/...` | **Denied** | `deny-supabase-writes.js` |
| Supabase MCP `apply_migration` | **Allowed** — this is the *intended* path for schema changes (versioned, replayable). The `supabase-migration-merge` skill (installed at `<project>/.claude/skills/`) helps when concurrent migrations from multiple branches need to be reconciled. | — |
| `git push --force origin main` | **Denied** | `permissions.deny` |
| `git push` (normal) | Allowed | — |
| `rm -rf /` or `rm -rf ~` | **Denied** | `permissions.deny` |
| Reading the codebase, editing files, running tests | Allowed | — |
| Anything else risky | Approval prompt | (default Claude Code behavior — not pre-allowed) |

---

## Verification after install

Start a Claude Code session in any project and try each of these. They should match the column above:

```
1. Read on a fake .env file        → expected: denied
2. Read on .env.example            → expected: allowed
3. Supabase execute_sql 'SELECT 1' → expected: allowed
4. Supabase execute_sql 'INSERT …' → expected: denied
5. Bash 'cat ./.env'               → expected: denied
6. Bash 'cat package.json'         → expected: allowed
```

If any of these don't match, see `docs/troubleshooting.md` (forthcoming).

---

## MCP setup

The framework doesn't auto-configure your MCPs — that's project-specific and credential-bearing. See [`mcp-templates/`](mcp-templates/) for copy-paste setup recipes:

- [Supabase](mcp-templates/supabase.md) — DB queries, schema inspection
- [Freedcamp](mcp-templates/freedcamp.md) — one MCP per Freedcamp project
- [Google](mcp-templates/google.md) — Gmail, Calendar, Drive (OAuth, user-scope)
- [ClickUp](mcp-templates/clickup.md) — alternative PM tool

---

## Updating the framework

Same as install:

```bash
cd agent-workflow-training
git pull
./install.sh --force        # or .\install.ps1 -Force
```

`--force` overwrites the installed hooks and settings with the latest from this repo. Your `settings.json` customizations live in `settings.json` (user) and `<project>/.claude/settings.json` (project) — re-merge from the new sidecar if upgrade emits one.

---

## Contributing

This is an internal-but-public framework. PRs welcome from BestMe team members. The minimal bar for a new rule:

1. **Why it exists** — describe the incident, near-miss, or class of accident the rule prevents.
2. **Test case** — what tool call should be denied, what tool call should still pass.
3. **Scope** — user, project, or both. Document the choice.

For a new MCP template, follow the structure in [`mcp-templates/README.md`](mcp-templates/README.md).

---

## License

MIT — see [LICENSE](LICENSE).
