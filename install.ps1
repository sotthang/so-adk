# SO-ADK Installer for Windows (PowerShell 7+)
# Usage:
#   Global install:
#     irm https://raw.githubusercontent.com/sotthang/so-adk/main/install.ps1 | iex
#
#   Local install:
#     iex "& { $(irm https://raw.githubusercontent.com/sotthang/so-adk/main/install.ps1) } --local"

param([string]$Mode = "global")

$REPO = "https://raw.githubusercontent.com/sotthang/so-adk/main"

Write-Host ""
Write-Host "╔══════════════════════════════════╗"
Write-Host "║         SO-ADK Installer         ║"
Write-Host "╚══════════════════════════════════╝"
Write-Host ""

# Determine target directories
if ($Mode -eq "local") {
    $SkillsDir = ".\.claude\skills"
    $AgentsDir = ".\.claude\agents"
    $ClaudeMdTarget = ".\CLAUDE.md"
    Write-Host "📁 Mode: Local install (current project)"
} else {
    $SkillsDir = "$HOME\.claude\skills"
    $AgentsDir = "$HOME\.claude\agents"
    $ClaudeMdTarget = $null
    Write-Host "📁 Mode: Global install (~/.claude/)"
}

Write-Host ""

# Create directories
New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null
New-Item -ItemType Directory -Force -Path $AgentsDir | Out-Null

# Download skill files
Write-Host "⬇️  Downloading skills..."
$Skills = @("dev", "plan", "simplify", "pr")
foreach ($skill in $Skills) {
    Invoke-WebRequest -Uri "$REPO/.claude/skills/$skill.md" -OutFile "$SkillsDir\$skill.md" -UseBasicParsing
    Write-Host "   ✓ /$skill"
}

# Download agent files
Write-Host "⬇️  Downloading agents..."
$Agents = @("planner", "reviewer", "architect", "tester", "developer", "quality", "docs")
foreach ($agent in $Agents) {
    Invoke-WebRequest -Uri "$REPO/.claude/agents/$agent.md" -OutFile "$AgentsDir\$agent.md" -UseBasicParsing
    Write-Host "   ✓ $agent"
}

# Handle CLAUDE.md for local installs
if ($Mode -eq "local") {
    if (Test-Path ".\CLAUDE.md") {
        Write-Host ""
        Write-Host "⚠️  CLAUDE.md already exists in this project."
        $confirm = Read-Host "   Overwrite? (y/N)"
        if ($confirm -eq "y" -or $confirm -eq "Y") {
            Invoke-WebRequest -Uri "$REPO/CLAUDE.md" -OutFile ".\CLAUDE.md" -UseBasicParsing
            Write-Host "   ✓ CLAUDE.md updated"
        } else {
            Write-Host "   ↩ Skipped CLAUDE.md"
        }
    } else {
        Invoke-WebRequest -Uri "$REPO/CLAUDE.md" -OutFile ".\CLAUDE.md" -UseBasicParsing
        Write-Host "   ✓ CLAUDE.md created"
    }
}

Write-Host ""
Write-Host "✅ SO-ADK installed successfully!"
Write-Host ""
if ($Mode -eq "global") {
    Write-Host "Skills are now available in all Claude Code projects."
    Write-Host "To also add CLAUDE.md to a project: run with -Mode local inside that project."
} else {
    Write-Host "Skills and CLAUDE.md are ready in this project."
}
Write-Host ""
Write-Host "Available slash commands:"
Write-Host '  /dev "feature description"  — full pipeline (Plan → Build → Test → Docs)'
Write-Host '  /plan "feature description" — generate SPEC only'
Write-Host "  /simplify                   — review and refactor code"
Write-Host "  /pr                         — create a pull request"
Write-Host ""
