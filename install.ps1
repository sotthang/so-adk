# SO-ADK Migration Wrapper (Windows / PowerShell 7+)
#
# SO-ADK is now distributed as a Claude Code plugin (marketplace + 2 plugins:
# so-adk-core, so-adk-orchestrator). This script no longer downloads or
# installs anything itself — it only helps existing curl/irm-based installs
# migrate their legacy .claude\ assets out of the way (backup, not delete)
# so that the plugin equivalents can take over without local files
# overriding them.
#
# This is a best-effort port of install.sh with NO automated test coverage.
# Always run --dry-run first and verify the result manually.
#
# Usage (download the file first — flags cannot be passed through `irm | iex`):
#   .\install.ps1              — diagnosis only, no changes (detects legacy assets)
#   .\install.ps1 --dry-run    — print the migration plan, no changes
#   .\install.ps1 --migrate    — perform the migration (backup + remove hook entries)
#   .\install.ps1 --help       — show this usage
#
# After migrating, install the plugins:
#   claude plugin marketplace add sotthang/so-adk
#   claude plugin install so-adk-core@so-adk --scope project
#   claude plugin install so-adk-orchestrator@so-adk --scope project   # optional

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Arguments
)

$ErrorActionPreference = 'Stop'

# -- Frozen legacy set --------------------------------------------------------
# These lists are a fixed snapshot of the assets the old curl/irm installer
# produced. They do not grow any more (post-migration agents and skills ship
# inside the plugin), so this enumeration is NOT an instance of the
# "install.sh listing omission" bug class it replaces.
$LegacyAgents = @(
    'so-planner', 'so-reviewer', 'so-architect', 'so-scaffold', 'so-tester',
    'so-developer', 'so-quality', 'so-docs', 'so-debugger', 'so-explainer',
    'so-preflight', 'so-security', 'so-performance', 'so-designer',
    'so-auditor', 'so-spike'
)
$LegacyInternalSkills = @('so-foundation', 'so-spec-format', 'so-tdd-workflow', 'so-context')
$LegacyGuardedSkills  = @('dev', 'plan', 'pr', 'refactor', 'simplify')   # simplify = refactor 이전 이름
$SkillMarker          = 'Claude normally triggers this automatically'
$LegacyHooks          = @('post-edit-check.sh', 'session-start-resume.sh')
$LegacyOrch           = '.claude\so-orchestrator.md'
$LegacyClaudeMdImport = '@.claude/so-orchestrator.md'
$SettingsPath         = '.claude\settings.json'

$PostEditCommand    = '.claude/hooks/post-edit-check.sh'
$SessionStartCommand = '.claude/hooks/session-start-resume.sh'

function Show-Usage {
    @'
SO-ADK Migration Wrapper (PowerShell — best-effort beta, no automated tests)

Usage:
  .\install.ps1              diagnosis only, no changes
  .\install.ps1 --dry-run     print migration plan, no changes
  .\install.ps1 --migrate     perform migration (backup legacy assets, remove hook entries)
  .\install.ps1 --help        show this help

After migrating, install the plugins:
  claude plugin marketplace add sotthang/so-adk
  claude plugin install so-adk-core@so-adk --scope project
  claude plugin install so-adk-orchestrator@so-adk --scope project   # optional
'@ | Write-Host
}

# -- Legacy detection (read-only) --------------------------------------------
$script:FoundAgents         = @()
$script:FoundInternalSkills = @()
$script:FoundGuardedSkills  = @()
$script:FoundHooks          = @()
$script:FoundOrch           = $false

function Test-Legacy {
    $script:FoundAgents         = @()
    $script:FoundInternalSkills = @()
    $script:FoundGuardedSkills  = @()
    $script:FoundHooks          = @()
    $script:FoundOrch           = $false

    foreach ($a in $LegacyAgents) {
        $p = ".claude\agents\$a.md"
        # Marker guard, symmetric with the skill guard below: never move a
        # same-named file the user wrote themselves.
        if ((Test-Path $p) -and (Select-String -Path $p -Pattern 'so-foundation' -Quiet -ErrorAction SilentlyContinue)) {
            $script:FoundAgents += $a
        }
    }
    # 구 배포는 스킬을 평탄 파일로 내보냈다(skills\<name>.md, 내부 스킬은
    # skills\internal\<name>.md). 현행 디렉터리 형식과 함께 3종을 모두 검사한다.
    # 배열에는 이름이 아니라 경로를 담아 원 레이아웃을 백업에서 재현할 수 있게 한다.
    foreach ($s in $LegacyInternalSkills) {
        if (Test-Path ".claude\skills\$s" -PathType Container) { $script:FoundInternalSkills += ".claude\skills\$s" }
        if (Test-Path ".claude\skills\$s.md" -PathType Leaf)   { $script:FoundInternalSkills += ".claude\skills\$s.md" }
        if (Test-Path ".claude\skills\internal\$s.md" -PathType Leaf) { $script:FoundInternalSkills += ".claude\skills\internal\$s.md" }
    }
    foreach ($s in $LegacyGuardedSkills) {
        foreach ($p in @(".claude\skills\$s\SKILL.md", ".claude\skills\$s.md", ".claude\skills\internal\$s.md")) {
            if ((Test-Path $p -PathType Leaf) -and
                (Select-String -Path $p -Pattern $SkillMarker -SimpleMatch -Quiet -ErrorAction SilentlyContinue)) {
                # 디렉터리 형식은 디렉터리째 이동한다
                if ($p -like '*\SKILL.md') { $script:FoundGuardedSkills += (Split-Path $p -Parent) }
                else                        { $script:FoundGuardedSkills += $p }
            }
        }
    }
    foreach ($h in $LegacyHooks) {
        if (Test-Path ".claude\hooks\$h") { $script:FoundHooks += $h }
    }
    if (Test-Path $LegacyOrch) { $script:FoundOrch = $true }

    $total = $script:FoundAgents.Count + $script:FoundInternalSkills.Count +
             $script:FoundGuardedSkills.Count + $script:FoundHooks.Count +
             [int]$script:FoundOrch
    return ($total -gt 0)
}

function Show-Detected {
    Write-Host 'Detected legacy SO-ADK assets:'
    foreach ($a in $script:FoundAgents)         { Write-Host "  agent: $a" }
    foreach ($s in $script:FoundInternalSkills) { Write-Host "  internal skill: $s" }
    foreach ($s in $script:FoundGuardedSkills)  { Write-Host "  skill: $s" }
    foreach ($h in $script:FoundHooks)          { Write-Host "  hook: $h" }
    if ($script:FoundOrch)                      { Write-Host "  orchestrator: $LegacyOrch" }
}

function Show-InstallGuidance {
    @'

Install SO-ADK as a plugin:
  claude plugin marketplace add sotthang/so-adk
  claude plugin install so-adk-core@so-adk --scope project
  claude plugin install so-adk-orchestrator@so-adk --scope project   # optional

Note: a plugin installed at --scope project cannot be removed with a plain
uninstall (it is shared with the team) — use --scope local to disable it
locally instead.
'@ | Write-Host
}

function Show-DryRunPlan {
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    Write-Host 'Migration plan (--dry-run, no changes will be made):'
    Write-Host ''
    Write-Host "Backup target: .claude\.so-adk-backup-$ts\"
    foreach ($a in $script:FoundAgents) {
        Write-Host "  move .claude\agents\$a.md -> .claude\.so-adk-backup-$ts\agents\$a.md"
    }
    foreach ($s in @($script:FoundInternalSkills) + @($script:FoundGuardedSkills)) {
        Write-Host "  move $s -> .claude\.so-adk-backup-$ts\$($s -replace '^\.claude\\', '')"
    }
    foreach ($h in $script:FoundHooks) {
        Write-Host "  move .claude\hooks\$h -> .claude\.so-adk-backup-$ts\hooks\$h"
    }
    if ($script:FoundOrch) {
        Write-Host "  move $LegacyOrch -> .claude\.so-adk-backup-$ts\so-orchestrator.md"
    }
    Write-Host ''
    if ((Test-Path 'CLAUDE.md') -and
        ((Get-Content 'CLAUDE.md') -contains $LegacyClaudeMdImport)) {
        Write-Host "CLAUDE.md: remove line '$LegacyClaudeMdImport' (file kept even if it becomes empty)"
    }
    if (Test-Path $SettingsPath) {
        Write-Host 'settings.json: remove SO-ADK PostToolUse/SessionStart hook entries (other keys preserved)'
    }
}

# -- Hook-entry removal gate (must precede any file move) ---------------------
function Show-ManualHookRemoval {
    @'
Could not automatically remove the SO-ADK hook entries from .claude\settings.json.
To avoid leaving orphaned hook references, no files were moved.

Please manually remove these entries from .claude\settings.json, then re-run
install.ps1 --migrate:
  - .hooks.PostToolUse entry whose command is ".claude/hooks/post-edit-check.sh"
  - .hooks.SessionStart entry whose command is ".claude/hooks/session-start-resume.sh"
'@ | Write-Host
}

function Remove-SoAdkEntries {
    param($Entries, [string] $Command)
    return @($Entries | Where-Object {
        $commands = @($_.hooks | ForEach-Object { $_.command })
        -not ($commands -contains $Command)
    })
}

# Returns $true when removal succeeded (or there was nothing to remove) —
# only then may files be moved. Returns $false to abort the migration.
function Remove-HookEntries {
    if (-not (Test-Path $SettingsPath)) { return $true }

    try {
        $json = Get-Content $SettingsPath -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Host '.claude\settings.json is not valid JSON.'
        Show-ManualHookRemoval
        return $false
    }

    if ($null -eq $json -or -not $json.PSObject.Properties['hooks']) { return $true }
    $hooks = $json.hooks

    try {
        if ($hooks.PSObject.Properties['PostToolUse']) {
            $kept = Remove-SoAdkEntries -Entries $hooks.PostToolUse -Command $PostEditCommand
            if ($kept.Count -eq 0) { $hooks.PSObject.Properties.Remove('PostToolUse') }
            else { $hooks.PostToolUse = $kept }
        }
        if ($hooks.PSObject.Properties['SessionStart']) {
            $kept = Remove-SoAdkEntries -Entries $hooks.SessionStart -Command $SessionStartCommand
            if ($kept.Count -eq 0) { $hooks.PSObject.Properties.Remove('SessionStart') }
            else { $hooks.SessionStart = $kept }
        }
        if ($hooks.PSObject.Properties.Name.Count -eq 0) {
            $json.PSObject.Properties.Remove('hooks')
        }
        $out = $json | ConvertTo-Json -Depth 100
        # Re-parse before committing the write — never leave a broken settings.json.
        $null = $out | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Host 'Failed to compute a valid new .claude\settings.json.'
        Show-ManualHookRemoval
        return $false
    }

    Set-Content -Path $SettingsPath -Value $out -Encoding utf8
    return $true
}

# -- Migration ----------------------------------------------------------------
function Invoke-Migrate {
    Write-Host ''
    Write-Host '[BETA] This PowerShell wrapper has no automated tests. Run --dry-run first to confirm the targets, then verify the result manually.' -ForegroundColor Yellow
    Write-Host ''

    if (-not (Test-Legacy)) {
        Write-Host 'No legacy SO-ADK assets detected - nothing to migrate.'
        Show-InstallGuidance
        return 0
    }

    Show-Detected
    Write-Host ''

    # Order invariant: hook entries must be gone BEFORE the scripts move.
    # The reverse order would, on a mid-failure, leave entries pointing at
    # missing scripts and every subsequent edit would be blocked.
    if (-not (Remove-HookEntries)) { return 1 }

    $backup = ".claude\.so-adk-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Force -Path $backup | Out-Null

    if ($script:FoundAgents.Count -gt 0) {
        New-Item -ItemType Directory -Force -Path "$backup\agents" | Out-Null
        foreach ($a in $script:FoundAgents) {
            Move-Item -Path ".claude\agents\$a.md" -Destination "$backup\agents\"
        }
    }
    foreach ($s in @($script:FoundInternalSkills) + @($script:FoundGuardedSkills)) {
        # 백업 안에서 원래 레이아웃을 그대로 재현한다
        $dest = Join-Path $backup ($s -replace '^\.claude\\', '')
        New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
        Move-Item -Path $s -Destination $dest
    }
    if ($script:FoundHooks.Count -gt 0) {
        New-Item -ItemType Directory -Force -Path "$backup\hooks" | Out-Null
        foreach ($h in $script:FoundHooks) {
            Move-Item -Path ".claude\hooks\$h" -Destination "$backup\hooks\"
        }
    }
    if ($script:FoundOrch) {
        Move-Item -Path $LegacyOrch -Destination "$backup\so-orchestrator.md"
    }

    # Remove the now-empty directories only if they really are empty.
    foreach ($d in @('.claude\agents', '.claude\skills\internal', '.claude\skills', '.claude\hooks')) {
        if ((Test-Path $d) -and -not (Get-ChildItem $d -Force)) {
            Remove-Item -Path $d -Force
        }
    }

    # Remove only the import line. Never delete CLAUDE.md, even if it ends up empty.
    if (Test-Path 'CLAUDE.md') {
        $kept = @(Get-Content 'CLAUDE.md' | Where-Object { $_ -ne $LegacyClaudeMdImport })
        Set-Content -Path 'CLAUDE.md' -Value $kept -Encoding utf8
    }

    Write-Host ''
    Write-Host 'Migration complete.'
    Write-Host "   Backup: $backup\"
    Show-InstallGuidance
    return 0
}

# -- Argument parsing ---------------------------------------------------------
$flag = ''
if ($Arguments -and $Arguments.Count -gt 0) { $flag = $Arguments[0] }

switch -Regex ($flag) {
    '^(--help|-h|-Help)$' {
        Show-Usage
        exit 0
    }
    '^(--dry-run|-DryRun)$' {
        if (-not (Test-Legacy)) {
            Write-Host 'No legacy SO-ADK assets detected - nothing to migrate.'
            Show-InstallGuidance
            exit 0
        }
        Show-Detected
        Write-Host ''
        Show-DryRunPlan
        exit 0
    }
    '^(--migrate|-Migrate)$' {
        exit (Invoke-Migrate)
    }
    '^$' {
        if (Test-Legacy) {
            Show-Detected
            Write-Host ''
            Write-Host "Run '.\install.ps1 --dry-run' to preview the migration plan,"
            Write-Host "or '.\install.ps1 --migrate' to perform it (SO-ADK assets are backed up, not deleted)."
        } else {
            Write-Host 'No legacy SO-ADK assets detected.'
        }
        Show-InstallGuidance
        exit 0
    }
    default {
        Write-Host "Unknown flag: $flag"
        Show-Usage
        exit 1
    }
}
