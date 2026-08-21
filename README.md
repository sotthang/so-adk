# SO-ADK

**Agentic Development Kit for Claude Code** — markdown-only orchestration framework.

[한국어](README.ko.md)

---

## What is SO-ADK?

SO-ADK makes Claude Code act as a **strategic orchestrator** that autonomously selects and invokes specialized agents based on your natural language — no slash commands needed.

Just say *"build me a login feature"* and SO-ADK automatically runs the full pipeline:

```text
[Greenfield — New Feature]
[1] Planner    → analyzes requirements, writes SPEC → saved to specs/
[2] Reviewer   → reviews the SPEC → pauses for your confirmation ✋ (loops with Planner on changes)
[3] Architect  → designs file structure and interfaces → saves specs/*.arch.md
[3.5] Scaffold → generates stub file skeleton (for new projects)
[4] Tester     → writes failing tests first (TDD RED)
[5] Developer  → implements until tests pass (TDD GREEN)
     ↑ loops until all tests pass (max 5 loops)
[6] Quality    → refactors and cleans up (TDD REFACTOR)
[7] Docs       → updates documentation + marks SPEC as Done

[Brownfield — Existing Code]
     Debugger / Developer → Tester → Quality (no SPEC needed)

[Pre-PR Gate]
     Preflight + Security (parallel) → PR (automatic)
```

**No binaries. No dependencies. Pure markdown.**

---

## Installation

Run this inside the project you want to use SO-ADK in:

```bash
# macOS / Linux / WSL
curl -fsSL https://raw.githubusercontent.com/sotthang/so-adk/main/install.sh | bash

# Windows PowerShell 7+
irm https://raw.githubusercontent.com/sotthang/so-adk/main/install.ps1 | iex
```

That's it. Everything is installed into the current project's `.claude/` folder.

Commit `.claude/` to share the setup with your team.

---

## Usage

### Just talk to Claude

SO-ADK detects intent from natural language and routes automatically:

| You say | What happens |
| ------- | ------------ |
| "로그인 기능 만들어줘" | Full 7-agent pipeline runs automatically |
| "이 버그 고쳐줘" | Debugger → Developer → Tester |
| "이 코드 설명해줘" | Explainer agent reads and explains |
| "이 코드 리팩토링해줘" | Quality agent reviews and refactors |
| "보안 검토해줘" | Security agent runs OWASP review |
| "PR 만들어줘" | Preflight + Security → PR draft |
| "도움말" | Shows available actions inline |

### Optional slash commands (shortcuts)

| Command | Description |
| ------- | ----------- |
| `/dev "feature"` | Full pipeline: Plan → Review → Design → Test → Build → Quality → Docs |
| `/plan "feature"` | Generate a SPEC document only |
| `/refactor` | Review and refactor existing code (Quality agent) |
| `/pr` | Create a pull request with a structured description |

---

## How it works

SO-ADK has three layers:

1. **`CLAUDE.md`** — imports the orchestrator. Detects intent, routes to agents, manages the SPEC lifecycle, handles checkpoints and session resume
2. **`.claude/agents/`** — 15 specialized sub-agents (including Designer, Performance, and Auditor), each a proper Claude Code agent with `model`, `maxTurns`, and `skills`
3. **`.claude/skills/`** — shared building blocks preloaded into agents via the `skills:` field (foundation principles, TDD workflow, SPEC format rules). Each skill is a `<name>/SKILL.md` directory

### Greenfield vs Brownfield

SO-ADK automatically detects which mode to use:

- **Greenfield** (new feature) → full 7-step pipeline with SPEC
- **Brownfield** (existing code change) → skips SPEC, goes directly to the relevant agent

### Session resume

If a pipeline is interrupted mid-way, SO-ADK detects the in-progress SPEC on the next session and offers to resume from where it left off.

### Agent model assignment

| Agent | Model | Reason |
| ----- | ----- | ------ |
| Planner | fable | SPEC quality determines everything downstream |
| Reviewer | opus | Deep reasoning needed to catch risks |
| Architect | fable | Design decisions affect the entire implementation |
| Designer | opus | UI/frontend contract specifications (optional) |
| Scaffold | sonnet | Stub file generation, repetitive task |
| Tester | sonnet | Pattern-based test writing, acceptance-to-unit pyramid |
| Developer | sonnet | Iterative implementation loop, auto-lint on edit |
| Quality | sonnet | Code review and refactoring |
| Docs | haiku | Documentation writing, cost-efficient |
| Debugger | sonnet | Root cause analysis and test writing |
| Explainer | sonnet | Code reading and explanation |
| Auditor | sonnet | Dead code, stale deps, drift detection (stateless) |
| Preflight | sonnet | Test/lint runner and diff review |
| Performance | sonnet | Bottleneck/N+1 analysis, read-only report |
| Security | opus | Deep security analysis requires strong reasoning |

---

## File Structure

```text
your-project/
├── CLAUDE.md                          # @.claude/so-orchestrator.md
├── specs/                             # SPEC files saved here automatically
│   └── archive/                       # Done SPECs moved here
├── tests/
│   └── run-checks.sh                  # Smoke test validation (optional)
└── .claude/
    ├── so-orchestrator.md             # Orchestrator brain
    ├── settings.json                  # SessionStart + PostToolUse hooks configuration
    ├── hooks/
    │   ├── post-edit-check.sh         # Auto lint/typecheck on edit (exit 2 → feeds errors back)
    │   └── session-start-resume.sh    # Injects in-progress SPECs at session start
    ├── agents/
    │   ├── so-planner.md              # Requirements → SPEC (fable)
    │   ├── so-reviewer.md             # SPEC review + checkpoint (opus)
    │   ├── so-architect.md            # File structure + interfaces (fable)
    │   ├── so-designer.md             # UI design contract (opus, optional)
    │   ├── so-scaffold.md             # Generate stub file skeleton (sonnet)
    │   ├── so-tester.md               # Write failing tests — TDD RED (sonnet)
    │   ├── so-developer.md            # Implement to pass tests — TDD GREEN (sonnet)
    │   ├── so-quality.md              # Refactor — TDD REFACTOR (sonnet)
    │   ├── so-docs.md                 # Update documentation (haiku)
    │   ├── so-debugger.md             # Root cause analysis + reproducing test (sonnet)
    │   ├── so-explainer.md            # Code explanation, read-only (sonnet)
    │   ├── so-auditor.md              # Drift detection (sonnet, optional)
    │   ├── so-preflight.md            # Pre-PR safety check (sonnet)
    │   ├── so-performance.md          # Bottleneck analysis, read-only (sonnet)
    │   └── so-security.md             # OWASP security review (opus)
    └── skills/                        # each skill is a directory with SKILL.md
        ├── so-foundation/SKILL.md     # Core principles for all agents (preloaded)
        ├── so-tdd-workflow/SKILL.md   # TDD RED/GREEN/REFACTOR rules (preloaded)
        ├── so-spec-format/SKILL.md    # SPEC file format and status lifecycle (preloaded)
        ├── so-context/SKILL.md        # Codebase context mapper (preloaded)
        ├── dev/SKILL.md               # /dev — optional shortcut
        ├── plan/SKILL.md              # /plan — optional shortcut
        ├── refactor/SKILL.md          # /refactor — optional shortcut
        └── pr/SKILL.md                # /pr — optional shortcut
```

---

## Key Features

- **PostToolUse hooks** — Automatically runs lint/typecheck after Developer edits and feeds failures back to the agent (exit 2)
- **SessionStart hook** — Deterministically surfaces in-progress SPECs on session start so resume never depends on the model remembering to scan
- **Outside-In testing** — Acceptance → E2E → unit test pyramid (reverse testing approach)
- **UI Design specs** — Designer agent creates UI contracts when SPEC includes frontend (optional)
- **Parallel review mode** — Complex SPECs run Reviewer + Architect simultaneously for faster feedback
- **Continuous drift detection** — Auditor scans for dead code, stale deps, missed archives (optional)

## Philosophy

> The engineer's role shifts from writing code to designing the harness: specs, quality gates, and feedback loops.

- **Autonomous routing** — Claude detects intent and invokes agents without slash commands
- **SPEC First** — never implement without a clear spec, always saved to `specs/`
- **TDD by default** — tests before implementation, every time
- **Human checkpoints** — pipeline pauses after Reviewer for your approval
- **Greenfield/Brownfield aware** — full pipeline for new features, direct routing for existing code
- **Security gate** — every PR runs preflight + security in parallel before creation
- **Feedback loops** — PostToolUse hooks give feedback immediately; Auditor detects drift continuously

---

## License

MIT
