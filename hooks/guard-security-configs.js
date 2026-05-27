#!/usr/bin/env node
// PreToolUse hook: escalate (NOT deny) edits/writes to security-sensitive config files.
// Wired against: Edit | Write | NotebookEdit
//
// Returns permissionDecision="ask" instead of "deny" — these files have legitimate
// edit reasons (adding a project allowlist, tweaking a run config) but should always
// cross the human's eyes consciously, not happen silently mid-task.
//
// Hard denies in permissions.deny fire BEFORE this hook, so anything already on the
// hard-deny list (e.g. .env writes) never reaches here.

const PROTECTED_PATTERNS = [
  // Framework's own config — agent shouldn't disable its own guardrails silently
  /\/\.claude\/settings\.json$/,
  /\/\.claude\/settings\.local\.json$/,
  /\/\.claude\/hooks\//,

  // IDE run configurations — arbitrary code execution vector on IDE startup
  /\/\.idea\/runConfigurations\//,
  /\/\.run\//,

  // Secret-bearing paths (defense-in-depth; mostly hard-denied already)
  /\/\.env(\.|$)/,
  /\/secrets\//,
  /\/credentials\//,
  /\/\.ssh\//,
  /\/\.aws\//,
];

function normalizePath(p) {
  return String(p || "").replace(/\\/g, "/");
}

let raw = "";
process.stdin.on("data", c => raw += c);
process.stdin.on("end", () => {
  let evt;
  try { evt = JSON.parse(raw); } catch { process.exit(0); }

  const filePath = normalizePath(
    (evt.tool_input && (evt.tool_input.file_path || evt.tool_input.notebook_path)) || ""
  );
  if (!filePath) { process.exit(0); }

  // Pad with leading "/" so leading patterns like /\.claude\// still match relative paths
  const padded = filePath.startsWith("/") ? filePath : "/" + filePath;

  for (const pat of PROTECTED_PATTERNS) {
    if (pat.test(padded)) {
      process.stdout.write(JSON.stringify({
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "ask",
          permissionDecisionReason:
            "Security-sensitive config (" + filePath + ") — manual approval required. " +
            "These files (.claude/, IDE run configs, secrets) should always cross the human's eyes " +
            "consciously, not be edited silently mid-task. Approve only if this is the explicit task.",
        },
      }));
      process.exit(0);
    }
  }

  process.exit(0);
});
