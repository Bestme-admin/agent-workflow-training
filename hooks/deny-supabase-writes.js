#!/usr/bin/env node
// PreToolUse hook: deny write SQL through the Supabase MCP, allow SELECT-class reads.
// Wired against: mcp__supabase__execute_sql
//
// Philosophy: agents are allowed to investigate the database freely. Mutations are
// human-executed so that schema/data changes are visible in git/migrations and never
// silent. The agent should propose the SQL; the human runs it.

const WRITE_KW = [
  // DML mutations
  "insert", "update", "delete", "merge", "upsert", "replace", "truncate",
  // DDL
  "create", "alter", "drop", "rename", "comment\\s+on", "vacuum", "reindex",
  // permissions / roles
  "grant", "revoke",
  // session-mutating
  "set\\s+role", "reset\\s+role", "begin", "commit", "rollback", "savepoint",
  // function/procedure side-effects
  "call",
  // copy is read-from-file or write-to-file — both unsafe via agent
  "copy",
];

const WRITE_RE = new RegExp(
  String.raw`(^|\b|\s|;)(` + WRITE_KW.join("|") + String.raw`)\b`,
  "i"
);

// Strip SQL comments + leading whitespace so keyword detection isn't bypassed by `-- insert ...`.
function normalize(sql) {
  return String(sql || "")
    .replace(/\/\*[\s\S]*?\*\//g, " ")   // /* block */
    .replace(/--[^\n]*/g, " ")            // -- line
    .replace(/\s+/g, " ")
    .trim();
}

function deny(reason) {
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: reason,
    },
  }));
  process.exit(0);
}

let raw = "";
process.stdin.on("data", c => raw += c);
process.stdin.on("end", () => {
  let evt;
  try { evt = JSON.parse(raw); } catch { process.exit(0); }

  const sql = normalize(evt.tool_input && evt.tool_input.query);
  if (!sql) { process.exit(0); }

  if (WRITE_RE.test(sql)) {
    deny(
      "Blocked: Supabase MCP execute_sql with mutating SQL. " +
      "Read queries (SELECT / WITH-SELECT / EXPLAIN / SHOW) are fine. " +
      "Writes (INSERT/UPDATE/DELETE/DDL/etc.) must be run by the human so the change " +
      "is captured in a migration or at minimum visible in their shell history. " +
      "Propose the SQL in chat and ask the human to run it."
    );
    return;
  }

  process.exit(0);
});
