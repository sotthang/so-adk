# SO-ADK

**Agentic Development Kit for Claude Code** — markdown-only orchestration framework.

[한국어](README.ko.md)

---

## What is SO-ADK?

SO-ADK makes Claude Code act as a **strategic orchestrator** that autonomously selects and invokes specialized agents based on your natural language — no slash commands needed.

Just say *"build me a login feature"* and SO-ADK automatically runs the full pipeline:

```text
[1] Planner    → analyzes requirements, writes SPEC → saved to specs/
[2] Reviewer   → reviews the SPEC → pauses for your confirmation ✋
[3] Architect  → designs file structure and interfaces
[4] Tester     → writes failing tests first (TDD RED)
[5] Developer  → implements until tests pass (TDD GREEN)
     ↑ loops until all tests pass
[6] Quality    → refactors and cleans up (TDD REFACTOR)
[7] Docs       → updates documentation + marks SPEC as Done
```

**No binaries. No dependencies. Pure markdown.**

---

## Installation

### Global install (agents and skills available in all projects)

```bash
# macOS / Linux / WSL
curl -fsSL https://raw.githubusercontent.com/sotthang/so-adk/main/install.sh | bash

# Windows PowerShell 7+
irm https://raw.githubusercontent.com/sotthang/so-adk/main/install.ps1 | iex
```

### Local install (current project only, also adds CLAUDE.md)

```bash
curl -fsSL https://raw.githubusercontent.com/sotthang/so-adk/main/install.sh | bash -s -- --local
```

---

## Usage

### Just talk to Claude

SO-ADK detects intent from natural language and routes automatically:

| You say | What happens |
| ------- | ------------ |
| "로그인 기능 만들어줘" | Full 7-agent pipeline runs automatically |
| "결제 모듈 스펙 짜줘" | Planner agent writes a SPEC to `specs/` |
| "이 코드 리팩토링해줘" | Quality agent reviews and refactors |
| "PR 만들어줘" | PR draft created, asks for confirmation |
| "도움말" | Shows available actions inline |

### Optional slash commands (shortcuts)

Slash commands are available for explicit control, but not required:

| Command | Description |
| ------- | ----------- |
| `/dev "feature"` | Full pipeline: Plan → Review → Design → Test → Build → Quality → Docs |
| `/plan "feature"` | Generate a SPEC document only |
| `/simplify` | Review and refactor existing code |
| `/pr` | Create a pull request with a structured description |

---

## How it works

SO-ADK is three things:

1. **`CLAUDE.md`** — the orchestrator brain. Detects intent, autonomously invokes agents via the Agent tool, manages the SPEC lifecycle, and handles checkpoints
2. **`.claude/agents/`** — 7 specialized sub-agents, each a proper Claude Code agent definition with `model`, `maxTurns`, and `skills`
3. **`.claude/skills/internal/`** — shared building blocks loaded by agents at startup (foundation principles, TDD workflow, SPEC format rules)

### Agent model assignment

| Agent | Model | Reason |
| ----- | ----- | ------ |
| Planner | opus | SPEC quality determines everything downstream |
| Reviewer | opus | Deep reasoning needed to catch risks |
| Architect | opus | Design decisions affect the entire implementation |
| Tester | sonnet | Pattern-based test writing |
| Developer | sonnet | Iterative implementation loop |
| Quality | sonnet | Code review and refactoring |
| Docs | haiku | Documentation writing, cost-efficient |

---

## File Structure

```text
so-adk/
├── CLAUDE.md                        # Orchestrator brain (always active)
├── install.sh                       # macOS/Linux installer
├── install.ps1                      # Windows installer
├── specs/                           # SPEC files saved here automatically
└── .claude/
    ├── agents/
    │   ├── planner.md               # Requirements → SPEC (opus)
    │   ├── reviewer.md              # SPEC review + checkpoint (opus)
    │   ├── architect.md             # File structure + interfaces (opus)
    │   ├── tester.md                # Write failing tests — TDD RED (sonnet)
    │   ├── developer.md             # Implement to pass tests — TDD GREEN (sonnet)
    │   ├── quality.md               # Refactor — TDD REFACTOR (sonnet)
    │   └── docs.md                  # Update documentation (haiku)
    └── skills/
        ├── internal/
        │   ├── so-foundation.md     # Core principles for all agents
        │   ├── so-tdd-workflow.md   # TDD RED/GREEN/REFACTOR rules
        │   └── so-spec-format.md    # SPEC file format and naming
        ├── dev.md                   # /dev — optional shortcut
        ├── plan.md                  # /plan — optional shortcut
        ├── simplify.md              # /simplify — optional shortcut
        └── pr.md                    # /pr — optional shortcut
```

---

## Philosophy

> The engineer's role shifts from writing code to designing the harness: specs, quality gates, and feedback loops.

- **Autonomous routing** — Claude detects intent and invokes agents without slash commands
- **SPEC First** — never implement without a clear spec, always saved to `specs/`
- **TDD by default** — tests before implementation, every time
- **Human checkpoints** — pipeline pauses after Reviewer for your approval
- **Minimum code** — implement only what's required, simplify after

---

## License

MIT
