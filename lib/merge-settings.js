#!/usr/bin/env node
// merge-settings.js — deep-merge the framework's settings overlay into an
// existing Claude Code settings.json WITHOUT clobbering user keys.
//
// Usage:  node merge-settings.js <base.json|/dev/null> <overlay.json>
// Prints the merged JSON to stdout. Pure: reads only, never writes.
//
// Merge rules:
//   permissions.deny        -> set-union (dedup), base order first
//   hooks.<Event>[]         -> append overlay hook-groups whose command
//                              strings aren't already present (idempotent)
//   $schema                 -> taken from overlay only if base lacks it
//   everything else in base -> left exactly as-is

"use strict";
const fs = require("fs");

function readJson(p) {
  if (!p || p === "/dev/null") return {};
  if (!fs.existsSync(p)) return {};
  const raw = fs.readFileSync(p, "utf8").trim();
  if (!raw) return {};
  return JSON.parse(raw); // throws on malformed -> caller aborts, base untouched
}

function unionDeny(baseArr, overlayArr) {
  const seen = new Set();
  const out = [];
  for (const v of [...(baseArr || []), ...(overlayArr || [])]) {
    if (!seen.has(v)) { seen.add(v); out.push(v); }
  }
  return out;
}

function mergeHookGroups(baseGroups, overlayGroups) {
  const result = Array.isArray(baseGroups) ? baseGroups.map((g) => ({ ...g })) : [];
  const present = new Set();
  for (const g of result) for (const h of g.hooks || []) present.add(h.command);

  for (const g of overlayGroups || []) {
    const fresh = (g.hooks || []).filter((h) => !present.has(h.command));
    if (fresh.length) {
      result.push({ ...g, hooks: fresh });
      for (const h of fresh) present.add(h.command);
    }
  }
  return result;
}

function main() {
  const [, , basePath, overlayPath] = process.argv;
  if (!overlayPath) {
    process.stderr.write("usage: merge-settings.js <base.json> <overlay.json>\n");
    process.exit(2);
  }
  const base = readJson(basePath);
  const overlay = readJson(overlayPath);
  const out = { ...base };

  if (overlay.$schema && !out.$schema) out.$schema = overlay.$schema;

  if (overlay.permissions && overlay.permissions.deny) {
    out.permissions = { ...(out.permissions || {}) };
    out.permissions.deny = unionDeny(out.permissions.deny, overlay.permissions.deny);
  }

  if (overlay.hooks) {
    out.hooks = { ...(out.hooks || {}) };
    for (const ev of Object.keys(overlay.hooks)) {
      out.hooks[ev] = mergeHookGroups(out.hooks[ev], overlay.hooks[ev]);
    }
  }

  process.stdout.write(JSON.stringify(out, null, 2) + "\n");
}

main();
