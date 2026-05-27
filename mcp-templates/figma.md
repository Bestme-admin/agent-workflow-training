# Figma MCP — setup template

## What this is for

Read access to Figma files from the agent — component inspection, frame-by-frame walkthroughs of a flow, exporting an image of a specific frame for a PR description, pulling design tokens (colors / spacing / typography) into code. The BestMe team has found this MCP particularly productive for translating designs into implementation tickets and for keeping the implementation faithful to the spec.

**Read-mostly tool.** Don't wire it up for write operations — comments and version history live in Figma; the agent shouldn't be posting to design files.

## Required env vars

| Var | Purpose | Where to get it |
|---|---|---|
| `FIGMA_ACCESS_TOKEN` | Personal access token (read scope is enough) | Figma → Settings → Account → Personal access tokens → "Generate new token" |

Scope the token to the minimum needed. If the upstream MCP supports a read-only flag, use it.

## .mcp.json snippet

```json
{
  "mcpServers": {
    "figma": {
      "command": "npx",
      "args": ["-y", "<figma-mcp-package>@latest"],
      "env": {
        "FIGMA_ACCESS_TOKEN": "${FIGMA_ACCESS_TOKEN}"
      }
    }
  }
}
```

**Pin to a specific upstream package.** There are multiple Figma MCP implementations; the team should agree on one and put the exact `npx -y <pkg>@<version>` in the project's `.mcp.json`. Don't rely on `@latest` long-term — newer versions can change tool names and break agent workflows that depend on them.

Consult the chosen upstream package's README for the exact config shape; the above is the standard skeleton.

## .env.example entry

```bash
# Figma MCP — personal access token, read scope
FIGMA_ACCESS_TOKEN=
```

## Working pattern

- **Frame links.** The most useful agent input is a direct Figma frame URL (`figma.com/file/<id>/<name>?node-id=<x>`). The agent fetches the frame, summarizes structure, and can pull the underlying tokens.
- **Export to image.** Useful when including a screenshot in a PR description — agent fetches the PNG via the MCP, doesn't need a human to manually screenshot.
- **Component diffing.** When asked "does the implemented X match the design?", the agent pulls the Figma component and compares prop-by-prop.

## Recommended guardrails

The framework doesn't ship a Figma-specific hook because there isn't a write-class operation worth gating at MCP level (no `apply_migration` equivalent). If your team's chosen Figma MCP exposes write ops you don't want, add a project-level deny pattern by tool name.

## Verification after install

1. List components in a known file — should return component names.
2. Fetch a frame image by node-id — should return image data.
3. Pull design tokens (colors, typography) from a known style — should match what's in the Figma UI.

If any of these fail, double-check the `FIGMA_ACCESS_TOKEN` scope and that the file is in a workspace the token's owner can read.
