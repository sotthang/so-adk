# SO-ADK Installer for Windows (PowerShell 7+)
# Usage:
#   irm https://raw.githubusercontent.com/sotthang/so-adk/main/install.ps1 | iex

$REPO = "https://raw.githubusercontent.com/sotthang/so-adk/main"

Write-Host ""
Write-Host "╔══════════════════════════════════╗"
Write-Host "║         SO-ADK Installer         ║"
Write-Host "╚══════════════════════════════════╝"
Write-Host ""
Write-Host "📁 Installing into current project: $(Get-Location)"
Write-Host ""

# Create directories
New-Item -ItemType Directory -Force -Path ".\.claude\agents" | Out-Null
New-Item -ItemType Directory -Force -Path ".\.claude\skills\internal" | Out-Null

# Download user-facing skill files
Write-Host "⬇️  Downloading skills..."
$Skills = @("dev", "plan", "simplify", "pr")
foreach ($skill in $Skills) {
    Invoke-WebRequest -Uri "$REPO/.claude/skills/$skill.md" -OutFile ".\.claude\skills\$skill.md" -UseBasicParsing
    Write-Host "   ✓ /$skill"
}

# Download internal skill files
Write-Host "⬇️  Downloading internal skills..."
$InternalSkills = @("so-foundation", "so-spec-format", "so-tdd-workflow", "so-context")
foreach ($skill in $InternalSkills) {
    Invoke-WebRequest -Uri "$REPO/.claude/skills/internal/$skill.md" -OutFile ".\.claude\skills\internal\$skill.md" -UseBasicParsing
    Write-Host "   ✓ $skill"
}

# Download agent files
Write-Host "⬇️  Downloading agents..."
$Agents = @("so-planner", "so-reviewer", "so-architect", "so-tester", "so-developer", "so-quality", "so-docs", "so-debugger", "so-explainer", "so-preflight", "so-security", "so-performance")
foreach ($agent in $Agents) {
    Invoke-WebRequest -Uri "$REPO/.claude/agents/$agent.md" -OutFile ".\.claude\agents\$agent.md" -UseBasicParsing
    Write-Host "   ✓ $agent"
}

# Always update the orchestrator file (SO-ADK owned, safe to overwrite)
Invoke-WebRequest -Uri "$REPO/.claude/so-orchestrator.md" -OutFile ".\.claude\so-orchestrator.md" -UseBasicParsing
Write-Host "   ✓ .claude/so-orchestrator.md"

# Add import line to CLAUDE.md
$ImportLine = "@.claude/so-orchestrator.md"

if (Test-Path ".\CLAUDE.md") {
    $content = Get-Content ".\CLAUDE.md" -Raw
    if ($content -match [regex]::Escape($ImportLine)) {
        Write-Host "   ↩ CLAUDE.md already imports so-orchestrator (skipped)"
    } else {
        Add-Content -Path ".\CLAUDE.md" -Value ""
        Add-Content -Path ".\CLAUDE.md" -Value $ImportLine
        Write-Host "   ✓ CLAUDE.md — appended import line"
    }
} else {
    Set-Content -Path ".\CLAUDE.md" -Value $ImportLine
    Write-Host "   ✓ CLAUDE.md created"
}

# Create specs directory
New-Item -ItemType Directory -Force -Path ".\specs" | Out-Null
if (-not (Test-Path ".\specs\.gitkeep")) {
    New-Item -ItemType File -Path ".\specs\.gitkeep" | Out-Null
}

Write-Host ""
Write-Host "✅ SO-ADK installed successfully!"
Write-Host ""
Write-Host "그냥 말하면 됩니다:"
Write-Host '  "로그인 기능 만들어줘"  → 전체 파이프라인 자동 실행'
Write-Host '  "이 버그 고쳐줘"        → 디버거 → 개발자 직접 연결'
Write-Host '  "PR 만들어줘"           → Preflight + Security → PR 생성'
Write-Host ""
