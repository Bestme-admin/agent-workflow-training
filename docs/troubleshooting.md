# Troubleshooting

## "Hook isn't firing"

**Symptoms:** an action you expected to be denied (e.g. reading `.env`, running an `INSERT` via Supabase MCP) goes through without intervention.

**Check, in order:**

1. **Hooks file exists.** Run `ls ~/.claude/hooks/` (or `ls <project>/.claude/hooks/` for project scope). If empty, re-run the installer.
2. **Settings reference the right path.** Open `~/.claude/settings.json` (or `<project>/.claude/settings.json`). Each hook entry has a `command` that should resolve to the actual hook file. On user scope it's an absolute path; on project scope it's `${CLAUDE_PROJECT_DIR}/.claude/hooks/<name>.js`.
3. **Node is on the agent's PATH.** Hooks invoke `node`. From a Claude Code session, run a quick `Bash` of `node --version` — if "command not found", Node isn't visible to the agent's shell environment.
4. **Matcher matches.** The `matcher` field in the hook entry is a regex (or pipe-separated list) of tool names. If you're calling `mcp__supabase__execute_sql` but the matcher says `mcp__supabase__execute_query`, no match → no hook.
5. **Restart the session.** Claude Code reads settings on session start. After editing `settings.json`, exit and re-launch.

## "Hook is firing but blocking things it shouldn't"

E.g., `deny-env-access.js` blocking a read of `environment.yml`.

The regex in `deny-env-access.js` matches `.env` anywhere in a path component. `environment.yml` shouldn't match (no `.env` segment), but if it does, the regex is wrong — open an issue or PR with the false-positive example.

For false positives in `deny-supabase-writes.js` — the SQL keyword detector is conservative on purpose. If a legitimate read-only query is being blocked, post the SQL and we tighten the regex.

## "settings.json sidecar was written instead of the real file"

This is the safe default — the installer never overwrites an existing `settings.json`. To merge:

1. Open both files side by side: `~/.claude/settings.json` (your existing) and `~/.claude/settings.json.agent-workflow-training` (the new content).
2. Copy the `permissions.deny` array entries from the sidecar into your existing `permissions.deny`.
3. Copy the `hooks.PreToolUse` entries from the sidecar into your existing `hooks.PreToolUse`.
4. Delete the sidecar.

If you trust the installer to replace your existing settings, re-run with `--force` / `-Force` and it'll overwrite. Back up first.

## "Node not found" during install

Install Node 18+ from https://nodejs.org. If you use a version manager (nvm, fnm, volta), make sure the installed Node is in PATH when the installer runs — open a fresh terminal after install so `node --version` resolves.

## "Permission denied" running install.sh on macOS / Linux

```bash
chmod +x install.sh
./install.sh
```

## "Execution policy" error running install.ps1 on Windows

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install.ps1
```

The `-Scope Process` flag only affects the current shell — no permanent system change.

## "I want to add a new hook"

1. Drop a new `.js` file in `hooks/`.
2. Add a matcher + command entry to the appropriate `settings/*.json` template.
3. Update README's "What the agent can and can't do" table.
4. Add a test case to this troubleshooting doc.
5. PR.

## "I want to disable a rule for one specific session"

Don't. Open an issue describing why the rule is wrong, propose a fix to the underlying pattern. If the rule is genuinely wrong in a specific context that can be detected programmatically, the hook should detect that context — not get bypassed.

If you really need a temporary bypass, edit your local `settings.json` to comment out the matcher, restart, do the thing, re-enable. Don't commit the disabled version.
