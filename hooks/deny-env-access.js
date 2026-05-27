#!/usr/bin/env node
// PreToolUse hook: block reads/writes/shell access to .env files.
// Wired against: Read | Edit | Write | Bash
//
// Contract:
//   stdin  → { tool_name, tool_input: {...} }
//   stdout → { permissionDecision: "deny" | "ask", permissionDecisionReason: "..." } on intervention
//   exit 0 = decision applied; exit non-zero = hook error (treated as no decision by Claude Code).

const ENV_PATH_RE = /(^|[\\/])\.env(\.|$)/i;

// Bash substrings that read or write .env files. Conservative on purpose — false positives
// just mean a one-shot approval prompt, which is fine.
const BASH_ENV_RE = new RegExp(
  [
    String.raw`(^|\s|[;&|`+"`"+`])(cat|type|less|more|head|tail|bat|nl|od|xxd|hexdump|strings)\s+[^|;]*\.env`,
    String.raw`Get-Content\s+[^|;]*\.env`,
    String.raw`grep\s+[^|;]*\.env(\b|$)`,
    String.raw`rg\s+[^|;]*\.env(\b|$)`,
    String.raw`sed\s+[^|;]*\.env`,
    String.raw`awk\s+[^|;]*\.env`,
    String.raw`>\s*[^|;]*\.env(\s|$)`,         // redirect into .env
    String.raw`Set-Content\s+[^|;]*\.env`,
    String.raw`Out-File\s+[^|;]*\.env`,
    String.raw`cp\s+[^|;]*\.env`,               // copying may exfiltrate
    String.raw`mv\s+[^|;]*\.env`,
    String.raw`Copy-Item\s+[^|;]*\.env`,
    String.raw`Move-Item\s+[^|;]*\.env`,
  ].join("|"),
  "i"
);

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

function passthrough() {
  process.exit(0);
}

let raw = "";
process.stdin.on("data", chunk => raw += chunk);
process.stdin.on("end", () => {
  let evt;
  try { evt = JSON.parse(raw); } catch { passthrough(); return; }

  const tool = evt.tool_name;
  const input = evt.tool_input || {};

  if (tool === "Read" || tool === "Edit" || tool === "Write" || tool === "NotebookEdit") {
    const p = input.file_path || input.notebook_path || "";
    if (ENV_PATH_RE.test(p)) {
      deny(`Blocked: ${tool} on a .env file (${p}). Secrets stay out of agent context — ask the human to run it, or read the .env.example template instead.`);
      return;
    }
  }

  if (tool === "Bash" || tool === "PowerShell") {
    const cmd = input.command || "";
    if (BASH_ENV_RE.test(cmd)) {
      deny(`Blocked: shell command touches a .env file. Secrets stay out of agent context — ask the human to share only the specific value you need, or use the project's .env.example.`);
      return;
    }
  }

  passthrough();
});
