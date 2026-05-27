#!/usr/bin/env node
// SessionStart hook: print a one-time orientation banner so the human
// understands where deny errors will come from before they encounter one.
//
// The banner goes to stderr (visible to the user in their terminal).
// We also emit additionalContext on stdout so the AGENT knows the framework
// is active and which reference doc to point the user at when a deny fires.

const os = require("os");
const path = require("path");

const whyDeniedPath = path.join(os.homedir(), ".claude", "WHY-DENIED.md");

// USER-visible banner (stderr). Keep it compact — runs every session.
process.stderr.write(
  "\n" +
  "⚡ agent-workflow-training is enforcing project rules.\n" +
  "   If you see a 'denied by permissions.deny' error, see\n" +
  "   " + whyDeniedPath + "\n" +
  "   for the rationale + workaround for each pattern.\n" +
  "\n"
);

// AGENT-visible context (stdout, structured). Helps the agent self-explain
// when a deny fires — it can cite the framework + point at the reference doc.
process.stdout.write(JSON.stringify({
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext:
      "This session has the agent-workflow-training framework active. " +
      "If a tool call hits 'denied by permissions.deny pattern <X>' or the " +
      "deny-env-access / deny-supabase-writes hook fires, that's the framework " +
      "protecting the human's shared state (secrets, DB, force-push, etc.). " +
      "When you encounter a deny, briefly explain to the user what was blocked " +
      "and point them at " + whyDeniedPath + " for the full rationale, " +
      "then propose how they should run the action themselves if it's legitimate.",
  },
}));

process.exit(0);
