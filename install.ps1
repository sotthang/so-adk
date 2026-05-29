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
New-Item -ItemType Directory -Force -Path ".\.claude\skills" | Out-Null
New-Item -ItemType Directory -Force -Path ".\.claude\hooks" | Out-Null

# Clean up legacy SO-ADK files from older installs (flat skill files +
# renamed /simplify). Remove only SO-ADK-owned paths — never user skills.
Write-Host "🧹 Cleaning up legacy SO-ADK files..."
$LegacyFlatSkills = @("dev", "plan", "simplify", "pr", "so-foundation", "so-spec-format", "so-tdd-workflow", "so-context")
foreach ($s in $LegacyFlatSkills) {
    Remove-Item -Force -ErrorAction SilentlyContinue ".\.claude\skills\$s.md"
    Remove-Item -Force -ErrorAction SilentlyContinue ".\.claude\skills\internal\$s.md"
}
if ((Test-Path ".\.claude\skills\internal") -and -not (Get-ChildItem ".\.claude\skills\internal" -Force)) {
    Remove-Item -Force ".\.claude\skills\internal"
}
# Old /simplify skill dir (renamed to refactor) — only the SO-ADK one.
if ((Test-Path ".\.claude\skills\simplify\SKILL.md") -and `
    (Select-String -Path ".\.claude\skills\simplify\SKILL.md" -Pattern "so-quality" -Quiet)) {
    Remove-Item -Recurse -Force ".\.claude\skills\simplify"
}

# Skills are directory-based: .claude/skills/<name>/SKILL.md
# (flat .md files under .claude/skills/ are NOT recognized by Claude Code).
Write-Host "⬇️  Downloading skills..."
$Skills = @("dev", "plan", "refactor", "pr")
foreach ($skill in $Skills) {
    New-Item -ItemType Directory -Force -Path ".\.claude\skills\$skill" | Out-Null
    Invoke-WebRequest -Uri "$REPO/.claude/skills/$skill/SKILL.md" -OutFile ".\.claude\skills\$skill\SKILL.md" -UseBasicParsing
    Write-Host "   ✓ /$skill"
}

# Internal knowledge skills (preloaded into agents via the `skills:` field)
Write-Host "⬇️  Downloading internal skills..."
$InternalSkills = @("so-foundation", "so-spec-format", "so-tdd-workflow", "so-context")
foreach ($skill in $InternalSkills) {
    New-Item -ItemType Directory -Force -Path ".\.claude\skills\$skill" | Out-Null
    Invoke-WebRequest -Uri "$REPO/.claude/skills/$skill/SKILL.md" -OutFile ".\.claude\skills\$skill\SKILL.md" -UseBasicParsing
    Write-Host "   ✓ $skill"
}

# Download agent files
Write-Host "⬇️  Downloading agents..."
$Agents = @("so-planner", "so-reviewer", "so-architect", "so-designer", "so-scaffold", "so-tester", "so-developer", "so-quality", "so-docs", "so-debugger", "so-explainer", "so-auditor", "so-preflight", "so-security", "so-performance")
foreach ($agent in $Agents) {
    Invoke-WebRequest -Uri "$REPO/.claude/agents/$agent.md" -OutFile ".\.claude\agents\$agent.md" -UseBasicParsing
    Write-Host "   ✓ $agent"
}

# Download hooks
Write-Host "⬇️  Downloading hooks..."
$Hooks = @("post-edit-check.sh", "session-start-resume.sh")
foreach ($hook in $Hooks) {
    Invoke-WebRequest -Uri "$REPO/.claude/hooks/$hook" -OutFile ".\.claude\hooks\$hook" -UseBasicParsing
    Write-Host "   ✓ $hook"
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

# Create / merge settings.json (SessionStart + PostToolUse hooks)
$SettingsPath = ".\.claude\settings.json"
$SettingsTemplate = @'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": ".claude/hooks/session-start-resume.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/post-edit-check.sh" }
        ]
      }
    ]
  }
}
'@
if (-not (Test-Path $SettingsPath)) {
    Set-Content -Path $SettingsPath -Value $SettingsTemplate
    Write-Host "   ✓ settings.json created from template"
} else {
    Write-Host "   ⚠ settings.json already exists — please ensure it registers the SessionStart and PostToolUse hooks above" -ForegroundColor Yellow
}

# Create specs directory
New-Item -ItemType Directory -Force -Path ".\specs\archive" | Out-Null
if (-not (Test-Path ".\specs\.gitkeep")) {
    New-Item -ItemType File -Path ".\specs\.gitkeep" | Out-Null
}
if (-not (Test-Path ".\specs\archive\.gitkeep")) {
    New-Item -ItemType File -Path ".\specs\archive\.gitkeep" | Out-Null
}

Write-Host ""
Write-Host "✅ SO-ADK installed successfully!"
Write-Host ""
Write-Host "그냥 말하면 됩니다:"
Write-Host '  "로그인 기능 만들어줘"  → 전체 파이프라인 자동 실행'
Write-Host '  "이 버그 고쳐줘"        → 디버거 → 개발자 직접 연결'
Write-Host '  "PR 만들어줘"           → Preflight + Security → PR 생성'
Write-Host ""
