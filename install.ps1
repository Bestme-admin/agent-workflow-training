# agent-workflow-training :: installer for Windows (PowerShell 7+)
#
# Usage:
#   .\install.ps1                  # user-scope only (~/.claude/...)
#   .\install.ps1 -Project         # also install project-scope into $PWD
#   .\install.ps1 -ProjectOnly     # skip user scope, install only into $PWD
#   .\install.ps1 -Force           # overwrite without prompts
#   .\install.ps1 -DryRun          # show what would happen, change nothing
#
# Safe by default: never overwrites an existing settings.json — writes a sibling
# .agent-workflow-training file and prints merge instructions instead.

[CmdletBinding()]
param(
    [switch]$Project,
    [switch]$ProjectOnly,
    [switch]$UserOnly,
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# -------- resolve flags --------
$doUser    = -not $ProjectOnly
$doProject = $Project.IsPresent -or $ProjectOnly.IsPresent
if ($UserOnly) { $doProject = $false }

# -------- locate self --------
$scriptDir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$userHome      = $env:USERPROFILE
$userClaude    = Join-Path $userHome '.claude'
$projectDir    = (Get-Location).Path
$projectClaude = Join-Path $projectDir '.claude'

# -------- helpers --------
function Log($msg)  { Write-Host "  $msg" }
function Hdr($msg)  { Write-Host "`n== $msg ==" }
function Warn($msg) { Write-Host "  ! $msg" -ForegroundColor Yellow }
function Die($msg)  { Write-Host "`nERROR: $msg" -ForegroundColor Red; exit 1 }
function Run($scriptblock, $description) {
    if ($DryRun) {
        Log "[dry] $description"
    } else {
        & $scriptblock | Out-Null
    }
}

Hdr 'agent-workflow-training :: installer'
Log "Source:   $scriptDir"
Log "User:     $userClaude    (install: $(if ($doUser) {'yes'} else {'no'}))"
Log "Project:  $projectClaude (install: $(if ($doProject) {'yes'} else {'no'}))"
if ($DryRun) { Log 'Mode:     DRY RUN — no changes will be written' }

# Node check
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd) {
    Die 'Node.js is required for the hook scripts but was not found on PATH. Install Node 18+ (https://nodejs.org) and retry.'
}
$nodeV = (& node --version).Trim()
Log "Node:     $nodeV"

# Project must be a git repo (warn only)
if ($doProject) {
    $gitDir = & git -C $projectDir rev-parse --git-dir 2>$null
    if (-not $gitDir) {
        Warn "Current directory is not inside a git repo. Project-scope install will proceed but the .claude/ folder won't be tracked."
    }
}

# -------- copy + settings helpers --------
function Copy-SafeFile {
    param([string]$Src, [string]$Dst)
    if ((Test-Path $Dst) -and -not $Force) {
        Warn "Exists, skipping: $Dst (use -Force to overwrite)"
        return
    }
    Run { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Dst) } "mkdir $(Split-Path -Parent $Dst)"
    Run { Copy-Item -Force $Src $Dst } "copy $Src -> $Dst"
    Log "Wrote:    $Dst"
}

function Write-OrSidecarSettings {
    param([string]$Src, [string]$Dst, [hashtable]$Subs)

    $content = Get-Content -Raw -LiteralPath $Src
    foreach ($k in $Subs.Keys) {
        $content = $content.Replace("{{$k}}", $Subs[$k])
    }

    if ((Test-Path $Dst) -and -not $Force) {
        $sidecar = "$Dst.agent-workflow-training"
        Run { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Dst) } "mkdir parent"
        if ($DryRun) {
            Log "[dry] write sidecar: $sidecar"
        } else {
            Set-Content -LiteralPath $sidecar -Value $content -Encoding UTF8
        }
        Log "Existing settings.json detected — wrote sidecar: $sidecar"
        Log '  Merge manually: open both files, copy the permissions.deny entries'
        Log '  and hooks.PreToolUse entries from the sidecar into your settings.json.'
    } else {
        Run { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Dst) } "mkdir parent"
        if ($DryRun) {
            Log "[dry] write: $Dst"
        } else {
            Set-Content -LiteralPath $Dst -Value $content -Encoding UTF8
        }
        Log "Wrote:    $Dst"
    }
}

# -------- user scope --------
if ($doUser) {
    Hdr "User scope ($userClaude)"

    $userHooksDir = Join-Path $userClaude 'hooks'
    foreach ($h in @('deny-env-access.js', 'deny-supabase-writes.js', 'orient-session.js', 'guard-security-configs.js')) {
        Copy-SafeFile -Src (Join-Path $scriptDir "hooks\$h") -Dst (Join-Path $userHooksDir $h)
    }

    # Reference doc that orient-session.js banner points to
    Copy-SafeFile `
        -Src (Join-Path $scriptDir 'WHY-DENIED.md') `
        -Dst (Join-Path $userClaude 'WHY-DENIED.md')

    # User-scope skills: everything under skills\user\
    $userSkillsRoot = Join-Path $scriptDir 'skills\user'
    if (Test-Path $userSkillsRoot) {
        foreach ($skillDir in Get-ChildItem -Directory -Path $userSkillsRoot) {
            $skillName = $skillDir.Name
            Copy-SafeFile `
                -Src (Join-Path $skillDir.FullName 'SKILL.md') `
                -Dst (Join-Path $userClaude "skills\$skillName\SKILL.md")
        }
    }

    # Forward-slash path in JSON for cross-shell consistency
    $userHooksForJson = $userHooksDir.Replace('\', '/')
    Write-OrSidecarSettings `
        -Src (Join-Path $scriptDir 'settings\user.json') `
        -Dst (Join-Path $userClaude 'settings.json') `
        -Subs @{ 'USER_HOOKS' = $userHooksForJson }
}

# -------- project scope --------
if ($doProject) {
    Hdr "Project scope ($projectClaude)"

    $projHooksDir = Join-Path $projectClaude 'hooks'
    foreach ($h in @('deny-env-access.js', 'deny-supabase-writes.js', 'guard-security-configs.js')) {
        Copy-SafeFile -Src (Join-Path $scriptDir "hooks\$h") -Dst (Join-Path $projHooksDir $h)
    }

    # Project-scope skills: everything under skills\project\ (installed by default)
    $projSkillsRoot = Join-Path $scriptDir 'skills\project'
    if (Test-Path $projSkillsRoot) {
        foreach ($skillDir in Get-ChildItem -Directory -Path $projSkillsRoot) {
            $skillName = $skillDir.Name
            Copy-SafeFile `
                -Src (Join-Path $skillDir.FullName 'SKILL.md') `
                -Dst (Join-Path $projectClaude "skills\$skillName\SKILL.md")
        }
    }

    Write-OrSidecarSettings `
        -Src (Join-Path $scriptDir 'settings\project.json') `
        -Dst (Join-Path $projectClaude 'settings.json') `
        -Subs @{}

    Log ''
    Log "NEXT: add this line to your project's CLAUDE.md so every session reads the workflow:"
    Log '      > **Required reading:** the `ai-workflow` skill (installed at `~/.claude/skills/ai-workflow/SKILL.md`).'
    Log '      Project-scope skills (e.g. supabase-migration-merge) live at <project>/.claude/skills/.'
}

# -------- done --------
Hdr 'Done'
Log 'Verify by starting a Claude Code session and trying:'
Log '  1. Read on a fake .env file — should be denied.'
Log "  2. Supabase MCP execute_sql with 'INSERT' — should be denied (if Supabase MCP is wired)."
Log '  3. Read .env.example — should succeed.'
Log ''
Log "Troubleshooting: see $scriptDir\docs\troubleshooting.md (TBD)."
