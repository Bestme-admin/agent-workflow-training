#!/usr/bin/env bash
# agent-workflow-training :: installer for macOS + Linux
#
# Usage:
#   ./install.sh                  # install user-scope only (~/.claude/...)
#   ./install.sh --project        # also install project-scope into $PWD
#   ./install.sh --project-only   # skip user scope, install only into $PWD
#   ./install.sh --force          # overwrite without prompts
#   ./install.sh --dry-run        # show what would happen, change nothing
#
# Safe by default: never overwrites an existing settings.json — writes a sibling
# .agent-workflow-training file and prints merge instructions instead.

set -euo pipefail

# -------- defaults --------
DO_USER=1
DO_PROJECT=0
FORCE=0
DRY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)        DO_PROJECT=1 ;;
    --project-only)   DO_PROJECT=1; DO_USER=0 ;;
    --user-only)      DO_USER=1; DO_PROJECT=0 ;;
    --force)          FORCE=1 ;;
    --dry-run)        DRY=1 ;;
    -h|--help)
      sed -n '2,15p' "$0"
      exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2 ;;
  esac
  shift
done

# -------- locate self --------
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
USER_HOME="${HOME}"
USER_CLAUDE="${USER_HOME}/.claude"
PROJECT_DIR="${PWD}"
PROJECT_CLAUDE="${PROJECT_DIR}/.claude"

# -------- pre-flight --------
log() { printf "  %s\n" "$*"; }
hdr() { printf "\n== %s ==\n" "$*"; }
warn() { printf "  ! %s\n" "$*" >&2; }
die() { printf "\nERROR: %s\n" "$*" >&2; exit 1; }
run() {
  if [[ "$DRY" == "1" ]]; then
    printf "  [dry] %s\n" "$*"
  else
    eval "$@"
  fi
}

hdr "agent-workflow-training :: installer"
log "Source:   ${SCRIPT_DIR}"
log "User:     ${USER_CLAUDE}    (install: $([ $DO_USER == 1 ] && echo yes || echo no))"
log "Project:  ${PROJECT_CLAUDE} (install: $([ $DO_PROJECT == 1 ] && echo yes || echo no))"
[[ "$DRY" == "1" ]] && log "Mode:     DRY RUN — no changes will be written"

command -v node >/dev/null 2>&1 || die "Node.js is required for the hook scripts but was not found on PATH. Install Node 18+ (https://nodejs.org) and retry."
NODE_V=$(node --version)
log "Node:     ${NODE_V}"

if [[ $DO_PROJECT == 1 ]]; then
  if ! git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    warn "Current directory is not inside a git repo. Project-scope install will proceed but the .claude/ folder won't be tracked."
  fi
fi

# -------- helpers --------
safe_copy_file() {
  # safe_copy_file <src> <dst>
  local src="$1" dst="$2"
  if [[ -f "$dst" && "$FORCE" != "1" ]]; then
    warn "Exists, skipping: $dst (use --force to overwrite)"
    return
  fi
  run "mkdir -p \"$(dirname "$dst")\""
  run "cp \"$src\" \"$dst\""
  log "Wrote:    $dst"
}

write_or_sidecar_settings() {
  # write_or_sidecar_settings <src> <dst> [substitutions...]
  # If $dst doesn't exist: write. If it does: write to $dst.agent-workflow-training instead.
  local src="$1" dst="$2"
  shift 2
  local tmp="$(mktemp)"
  cp "$src" "$tmp"

  # Apply substitutions (e.g., USER_HOOKS=/abs/path)
  for kv in "$@"; do
    local key="${kv%%=*}" val="${kv#*=}"
    # Escape forward slashes in val for sed
    local val_esc
    val_esc=$(printf '%s' "$val" | sed 's/[\/&]/\\&/g')
    sed -i.bak "s/{{${key}}}/${val_esc}/g" "$tmp" && rm -f "$tmp.bak"
  done

  if [[ -f "$dst" && "$FORCE" != "1" ]]; then
    local sidecar="${dst}.agent-workflow-training"
    run "mkdir -p \"$(dirname "$dst")\""
    run "cp \"$tmp\" \"$sidecar\""
    log "Existing settings.json detected — wrote sidecar: $sidecar"
    log "  Merge manually: open both files, copy the permissions.deny entries"
    log "  and hooks.PreToolUse entries from the sidecar into your settings.json."
  else
    run "mkdir -p \"$(dirname "$dst")\""
    run "cp \"$tmp\" \"$dst\""
    log "Wrote:    $dst"
  fi
  rm -f "$tmp"
}

# -------- user scope --------
if [[ $DO_USER == 1 ]]; then
  hdr "User scope (${USER_CLAUDE})"

  USER_HOOKS_DIR="${USER_CLAUDE}/hooks"
  for h in deny-env-access.js deny-supabase-writes.js orient-session.js guard-security-configs.js; do
    safe_copy_file "${SCRIPT_DIR}/hooks/${h}" "${USER_HOOKS_DIR}/${h}"
  done

  # Reference doc that orient-session.js banner points to
  safe_copy_file "${SCRIPT_DIR}/WHY-DENIED.md" "${USER_CLAUDE}/WHY-DENIED.md"

  # User-scope skills: everything under skills/user/
  if [[ -d "${SCRIPT_DIR}/skills/user" ]]; then
    for skill_dir in "${SCRIPT_DIR}/skills/user"/*/; do
      [[ -d "$skill_dir" ]] || continue
      skill_name=$(basename "$skill_dir")
      safe_copy_file "${skill_dir}SKILL.md" "${USER_CLAUDE}/skills/${skill_name}/SKILL.md"
    done
  fi

  write_or_sidecar_settings \
    "${SCRIPT_DIR}/settings/user.json" \
    "${USER_CLAUDE}/settings.json" \
    "USER_HOOKS=${USER_HOOKS_DIR}"
fi

# -------- project scope --------
if [[ $DO_PROJECT == 1 ]]; then
  hdr "Project scope (${PROJECT_CLAUDE})"

  PROJ_HOOKS_DIR="${PROJECT_CLAUDE}/hooks"
  for h in deny-env-access.js deny-supabase-writes.js guard-security-configs.js; do
    safe_copy_file "${SCRIPT_DIR}/hooks/${h}" "${PROJ_HOOKS_DIR}/${h}"
  done

  # Project-scope skills: everything under skills/project/ (installed by default)
  if [[ -d "${SCRIPT_DIR}/skills/project" ]]; then
    for skill_dir in "${SCRIPT_DIR}/skills/project"/*/; do
      [[ -d "$skill_dir" ]] || continue
      skill_name=$(basename "$skill_dir")
      safe_copy_file "${skill_dir}SKILL.md" "${PROJECT_CLAUDE}/skills/${skill_name}/SKILL.md"
    done
  fi

  write_or_sidecar_settings \
    "${SCRIPT_DIR}/settings/project.json" \
    "${PROJECT_CLAUDE}/settings.json"

  log ""
  log "NEXT: add this line to your project's CLAUDE.md so every session reads the workflow:"
  log "      > **Required reading:** the \`ai-workflow\` skill (installed at \`~/.claude/skills/ai-workflow/SKILL.md\`)."
  log "      Project-scope skills (e.g. supabase-migration-merge) live at \`<project>/.claude/skills/\`."
fi

# -------- done --------
hdr "Done"
log "Verify by starting a Claude Code session and trying:"
log "  1. Read on a fake .env file — should be denied."
log "  2. Supabase MCP execute_sql with 'INSERT' — should be denied (if Supabase MCP is wired)."
log "  3. Read .env.example — should succeed."
log ""
log "Troubleshooting: see ${SCRIPT_DIR}/docs/troubleshooting.md (TBD)."
