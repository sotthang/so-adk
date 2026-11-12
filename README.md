# SO-ADK

**Agentic Development Kit for Claude Code** — markdown-only orchestration framework, distributed as a Claude Code plugin.

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
[3.7] Spike    → measures unverified assumptions, validates facts (conditional)
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

SO-ADK ships as **two plugins** from one marketplace:

| Plugin | Contents | Required? |
| ------ | -------- | --------- |
| `so-adk-core` | 16 agents, 8 skills, 2 hooks | Yes |
| `so-adk-orchestrator` | Replaces the main-thread agent with the natural-language router | Optional (but this is what makes routing automatic) |

---

## Installation

> ⚠️ **Read the scope warnings below before installing.** Every example here passes an explicit
> `--scope` flag on purpose — the CLI default (`user` scope) is *not* what you want for SO-ADK.

```bash
# 1. Register the marketplace
claude plugin marketplace add sotthang/so-adk

# 2. Install the core plugin (agents + skills + hooks)
claude plugin install so-adk-core@so-adk --scope project

# 3. Install the orchestrator (optional — enables automatic natural-language routing)
claude plugin install so-adk-orchestrator@so-adk --scope project

# 4. Verify both are actually enabled
claude plugin list
```

Step 4 is not optional busywork: a malformed marketplace entry makes a plugin show up as
`✘ disabled` **with no error message at all**. Always confirm you see `✔ enabled` for both.

Use `--scope local` instead of `--scope project` if you want SO-ADK for yourself only, without
committing the activation to the repository.

### Scopes

| Scope | Written to | Who gets it | Use for SO-ADK? |
| ----- | ---------- | ----------- | --------------- |
| `--scope project` | `.claude/settings.json` (committed) | Everyone on the repo | ✅ Recommended |
| `--scope local` | `.claude/settings.local.json` (gitignored) | Just you, this repo | ✅ Fine for solo/experimental use |
| `--scope user` (CLI default) | `~/.claude/settings.json` | **Every project you open** | ⚠️ See warnings |

### ⚠️ Scope warnings

**`so-adk-orchestrator` is Project/Local only.** It replaces the main-thread agent. Installed at
user scope it would hijack the main thread in *every* project you open, including ones that have
nothing to do with SO-ADK. Never install it with `--scope user`.

**`so-adk-core` is also Project/Local recommended.** Its hooks fire globally at user scope:

- `PostToolUse` runs lint/typecheck after **every** `Edit`/`Write`/`MultiEdit` in **every** project,
  and blocks the edit with `exit 2` on failure.
- `SessionStart` scans `specs/` on **every** session start in **every** project.

This is not blocked technically — it is a documented caveat. Install at project or local scope.

**`so-adk-orchestrator` needs `so-adk-core`.** Plugin manifests have no dependency field, so nothing
enforces this. Installing the orchestrator alone gives you a router that dispatches to agents that
do not exist.

### Caveat: `--scope project` isolates activation, not installation traces

Even a `--scope project` install writes to your user-global plugin cache
(`~/.claude/plugins/known_marketplaces.json` and `installed_plugins.json`, the latter tagged with
`scope: "project"` and the project path). Your `~/.claude/settings.json` itself is untouched. Project
scope bounds *where the plugin is active*, not *where the install leaves a record*.

### Checking context cost

Open the `/plugin` panel and select a plugin to see its **Context cost** — how many tokens the
plugin's agents, skills, and settings add to your session.

---

## Updating

```bash
/plugin
```

Select **so-adk** in the marketplace panel and choose *Update* for each plugin. Or from the CLI:

```bash
claude plugin update so-adk-core@so-adk --scope project
claude plugin update so-adk-orchestrator@so-adk --scope project
```

**Pass the same `--scope` you installed with.** `plugin update` defaults to `--scope user`, so
without the flag it fails with *"Plugin is not installed at scope user"* for anyone who followed the
project/local install above. Use `--scope local` if that is how you installed.

The old `curl ... install.sh | bash` path no longer installs anything — see [Migrating from the curl installer](#migrating-from-the-curl-installer).

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

Plugin skills are namespaced by their plugin name:

| Command | Description |
| ------- | ----------- |
| `/so-adk-core:dev "feature"` | Full pipeline: Plan → Review → Design → Test → Build → Quality → Docs |
| `/so-adk-core:plan "feature"` | Generate a SPEC document only |
| `/so-adk-core:refactor` | Review and refactor existing code (Quality agent) |
| `/so-adk-core:pr` | Create a pull request with a structured description |

#### ⚠️ Breaking change — skill names were renamed

Moving to plugin distribution namespaces every skill. The old bare names no longer resolve:

| Old (curl install) | New (plugin) |
| ------------------ | ------------ |
| `/dev` | `/so-adk-core:dev` |
| `/plan` | `/so-adk-core:plan` |
| `/refactor` | `/so-adk-core:refactor` |
| `/pr` | `/so-adk-core:pr` |

Natural-language routing is unaffected — *"로그인 기능 만들어줘"* still works exactly as before.

---

## Migrating from the curl installer

If you previously installed SO-ADK with `curl ... install.sh | bash`, your project has SO-ADK files
sitting in `.claude/`. **These must be moved out of the way**: a local `.claude/agents/so-planner.md`
overrides the plugin's agent of the same name, so the plugin install would silently have no effect.

The same URL now serves a **migration wrapper** instead of an installer. It never deletes anything —
it moves SO-ADK-owned files into a timestamped backup directory.

```bash
# 1. Diagnose — no flags, changes nothing
curl -fsSL https://raw.githubusercontent.com/sotthang/so-adk/main/install.sh | bash

# 2. Preview the exact plan — changes nothing
curl -fsSL https://raw.githubusercontent.com/sotthang/so-adk/main/install.sh | bash -s -- --dry-run

# 3. Perform the migration
curl -fsSL https://raw.githubusercontent.com/sotthang/so-adk/main/install.sh | bash -s -- --migrate
```

Windows PowerShell 7+ users: download `install.ps1` and run it with the same flags. The PowerShell
wrapper is a **best-effort beta with no automated tests** — always run `--dry-run` first and verify
the result manually.

**What `--migrate` does:**

- Moves the 16 SO-ADK agents, 8 SO-ADK skill directories, 2 hooks and `.claude/so-orchestrator.md`
  into `.claude/.so-adk-backup-<timestamp>/`. Files you edited yourself are preserved as-is in that
  backup — nothing is deleted.
- Removes only the SO-ADK hook entries from `.claude/settings.json`; every other key is preserved.
- Removes only the `@.claude/so-orchestrator.md` line from `CLAUDE.md`. The rest of your `CLAUDE.md`
  is untouched, and the file is **never deleted** even if that line was its only content.
- Leaves your own files alone. Agents and skills are matched against a fixed list *and* a
  content marker, so a `.claude/agents/my-agent.md` of your own is never touched.

**Orphan-hook safety:** if the hook entries cannot be removed from `.claude/settings.json` — `jq` is
missing, or the file is not valid JSON — the wrapper moves **no files at all**, prints manual removal
instructions, and exits non-zero. Leaving hook entries pointing at moved scripts would make every
subsequent edit fail.

**Behavior change:** the wrapper does **not** create `specs/` or `specs/archive/`. The old installer
did. Create them yourself if you want them:

```bash
mkdir -p specs/archive && touch specs/.gitkeep specs/archive/.gitkeep
```

After migrating, follow [Installation](#installation).

**To roll back a migration:** move the contents of `.claude/.so-adk-backup-<timestamp>/` back to
their original locations and re-add the `@.claude/so-orchestrator.md` line to `CLAUDE.md`. Because
the wrapper moves rather than deletes, this is always possible.

**To uninstall the plugins:** `claude plugin uninstall so-adk-core@so-adk`. Note that a plugin
installed at `--scope project` refuses a plain uninstall (it is shared with the team) and tells you
to disable it with `--scope local` instead.

---

## How it works

SO-ADK has three layers:

1. **`so-adk-orchestrator`** — replaces the main-thread agent via the plugin's `settings.json`
   `"agent"` key. Detects intent, routes to agents, manages the SPEC lifecycle, handles checkpoints
   and session resume. **Your `CLAUDE.md` is never modified** — the orchestrator coexists with your
   own global and project instructions.
2. **`so-adk-core` agents** — 16 specialized sub-agents (including Designer, Performance, Spike, and
   Auditor), each a proper Claude Code agent with `model`, `maxTurns`, and `skills`. The orchestrator
   dispatches to them across the plugin boundary by plain name.
3. **`so-adk-core` skills** — shared building blocks preloaded into agents via the `skills:` field
   (foundation principles, TDD workflow, SPEC format rules). Each skill is a `<name>/SKILL.md`
   directory.

### Greenfield vs Brownfield

SO-ADK automatically detects which mode to use:

- **Greenfield** (new feature) → full 7-step pipeline with SPEC
- **Brownfield** (existing code change) → skips SPEC, goes directly to the relevant agent

### Session resume

If a pipeline is interrupted mid-way, SO-ADK detects the in-progress SPEC on the next session and
offers to resume from where it left off.

### Workflows

Two pipeline segments run as Workflow scripts instead of being sequenced by the orchestrator's prompt,
so their control flow is enforced by code, not model judgment:

| Workflow | What it fixes in code |
| -------- | --------------------- |
| `so-adk-core:tdd-cycle` | RED → Developer↔Tester loop capped at **5** → Quality → re-verify. Returns `green`, `exhausted`, `not-red`, `refactor-broke` or `error` |
| `so-adk-core:pr-gate` | `so-preflight` and `so-security` **in parallel**; a fixed table decides `proceed` / `ask` / `stop`. A missing result or HOLD (empty diff) never passes |

Human checkpoints (SPEC approval, "ask" decisions, loop exhaustion) stay in the orchestrator — the
workflows return a status and the orchestrator asks you. Each agent keeps its own model (the workflow
dispatches by `agentType`). If the Workflow tool is unavailable or you decline it, the orchestrator falls
back to the manual Agent sequence. Claude Code asks you to approve each workflow run; to skip that, add
`"Workflow"` to `permissions.allow` in `.claude/settings.local.json`.

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
| Spike | sonnet | Measure unverified assumptions, validate facts against repository reality |
| Security | opus | Deep security analysis requires strong reasoning |

**When the Fable limit runs out.** Fable has its own weekly cap and can be exhausted before your other
limits. Claude Code's `fallbackModel` does **not** fire on rate/usage limits, so the orchestrator
handles it: when a Fable agent (Planner, Architect) fails on a usage limit, it re-dispatches that agent
to `opus` without asking, tells you in one line, and keeps using `opus` for Fable agents for the rest of
the session. It never drops to `sonnet`. Without the orchestrator plugin, switch by hand:
`ANTHROPIC_DEFAULT_FABLE_MODEL=claude-opus-5-5 claude`.

Keep `so-security` off Fable: Fable reroutes cybersecurity-flagged requests, which fails inside a subagent.

---

## Repository structure

```text
so-adk/
├── .claude-plugin/
│   └── marketplace.json                   # marketplace manifest — both plugin entries
├── .claude/
│   └── settings.json                      # committed: marketplace registration + enabled record
├── plugins/
│   ├── so-adk-core/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── agents/                        # 16 agents
│   │   │   ├── so-planner.md              # Requirements → SPEC (fable)
│   │   │   ├── so-reviewer.md             # SPEC review + checkpoint (opus)
│   │   │   ├── so-architect.md            # File structure + interfaces (fable)
│   │   │   ├── so-designer.md             # UI design contract (opus, optional)
│   │   │   ├── so-scaffold.md             # Generate stub file skeleton (sonnet)
│   │   │   ├── so-tester.md               # Write failing tests — TDD RED (sonnet)
│   │   │   ├── so-developer.md            # Implement to pass tests — TDD GREEN (sonnet)
│   │   │   ├── so-quality.md              # Refactor — TDD REFACTOR (sonnet)
│   │   │   ├── so-docs.md                 # Update documentation (haiku)
│   │   │   ├── so-debugger.md             # Root cause analysis + reproducing test (sonnet)
│   │   │   ├── so-explainer.md            # Code explanation, read-only (sonnet)
│   │   │   ├── so-auditor.md              # Drift detection (sonnet, optional)
│   │   │   ├── so-preflight.md            # Pre-PR safety check (sonnet)
│   │   │   ├── so-performance.md          # Bottleneck analysis, read-only (sonnet)
│   │   │   ├── so-spike.md                # Verify unverified assumptions (sonnet)
│   │   │   └── so-security.md             # OWASP security review (opus)
│   │   ├── workflows/                     # deterministic pipeline segments (Workflow scripts)
│   │   │   ├── tdd-cycle.js               # RED → GREEN loop (max 5) → REFACTOR + verify
│   │   │   └── pr-gate.js                 # preflight + security in parallel, fail-closed verdict
│   │   ├── skills/                        # each skill is a directory with SKILL.md
│   │   │   ├── so-foundation/SKILL.md     # Core principles for all agents (preloaded)
│   │   │   ├── so-tdd-workflow/SKILL.md   # TDD RED/GREEN/REFACTOR rules (preloaded)
│   │   │   ├── so-spec-format/SKILL.md    # SPEC file format and status lifecycle (preloaded)
│   │   │   ├── so-context/SKILL.md        # Codebase context mapper (preloaded)
│   │   │   ├── dev/SKILL.md               # /so-adk-core:dev
│   │   │   ├── plan/SKILL.md              # /so-adk-core:plan
│   │   │   ├── refactor/SKILL.md          # /so-adk-core:refactor
│   │   │   └── pr/SKILL.md                # /so-adk-core:pr
│   │   └── hooks/
│   │       ├── hooks.json                 # SessionStart + PostToolUse registration
│   │       ├── post-edit-check.sh         # Auto lint/typecheck on edit (exit 2 → feeds errors back)
│   │       └── session-start-resume.sh    # Injects in-progress SPECs at session start
│   └── so-adk-orchestrator/
│       ├── .claude-plugin/plugin.json
│       ├── agents/so-orchestrator.md      # Orchestrator brain
│       └── settings.json                  # "agent": "so-orchestrator" — main-thread replacement
├── install.sh / install.ps1               # migration wrapper for legacy curl installs
├── tests/run-checks.sh                    # static contract checks
├── tests/run-evals.sh                     # routing regression evals (calls the model — costs money)
├── evals/                                 # claude plugin eval cases (route-*)
└── specs/                                 # SPEC files
```

---

## Development

*This section is for people working on SO-ADK itself. If you just want to use SO-ADK, stop at
[Installation](#installation).*

### If you edit `plugins/` — use `--plugin-dir`, not `plugin install`

```bash
claude --plugin-dir ./plugins/so-adk-core --plugin-dir ./plugins/so-adk-orchestrator
```

This is **not** a convenience shortcut, and it is not a temporary workaround. It is the correct
loading mode for anyone editing plugin sources, for a concrete reason:

> `claude plugin install` **copies the plugin into a cache** (`~/.claude/plugins/cache/...`) and
> loads it from there. This is true even for a directory source. Your edits to `plugins/` in the
> working tree are **not reflected in the installed copy** — and there is no error, no warning, and
> no visible symptom. You will simply be testing a stale snapshot while believing you tested your
> change.

The marketplace source committed in this repo is a **github** source, so `plugin install` fetches the
published copy from the default branch — a second reason local edits will not appear.

Rule of thumb: **consumers `plugin install`, plugin developers `--plugin-dir`.**

### Contributor onboarding (if you only consume SO-ADK in this repo)

The committed `.claude/settings.json` gets you **registration, not installation**:

- `extraKnownMarketplaces` — the `so-adk` marketplace is auto-registered in your session. ✅
- `enabledPlugins` — this is a **record** of the intended state. It does **not** activate anything.

Opening a session with only this file committed leaves the plugins **not loaded**. Each contributor
must run the install once:

```bash
claude plugin install so-adk-core@so-adk --scope project
claude plugin install so-adk-orchestrator@so-adk --scope project
claude plugin list   # confirm ✔ enabled for both — a bad entry disables silently
```

This install is idempotent: re-running it on an already-committed `.claude/settings.json` prints
`already installed` and leaves the file byte-identical.

### Keep personal settings out of `.claude/settings.json`

`.claude/settings.json` is committed and gated: `tests/run-checks.sh` fails if it contains anything
other than exactly `extraKnownMarketplaces` and `enabledPlugins`. Put `model`, `env`, `permissions`,
`apiKeyHelper` and anything else personal in **`.claude/settings.local.json`**, which stays
gitignored.

### ⚠️ Do not run `claude plugin marketplace remove so-adk`

It wipes the committed file. Running it clears **both** `extraKnownMarketplaces` and `enabledPlugins`
in this repo's tracked `.claude/settings.json`, resetting them to `{}`. You get a spurious `git diff`
and `tests/run-checks.sh` starts failing.

Recovery:

```bash
git checkout -- .claude/settings.json
```

Related gotcha: if you register a local directory source under the same marketplace name (e.g.
`claude plugin marketplace add /path/to/so-adk`), it lands in your **user** settings and **takes
precedence** over the repo's committed github source. `claude plugin marketplace list` will show
`Directory`. The committed project file is left unmodified — but you are no longer running what the
repo declares.

### Tests

```bash
bash tests/run-checks.sh
```

Static contract checks over the plugin layout: manifests, hook registration, frontmatter, skill
namespacing, orchestrator↔agent reference consistency (both directions), the committed
`settings.json` key boundary and marketplace source schema, and the migration wrapper's behavior.
`claude plugin validate` checks are included when the `claude` CLI is on `PATH`, and skipped
otherwise.

`run-checks.sh` also runs `node --test tests/workflows.test.mjs`: unit tests of the workflows' control
flow with a stubbed `agent()` (no model calls). Skipped when `node` is not on `PATH`.

```bash
bash tests/run-evals.sh            # routing regression evals, runs=1
bash tests/run-evals.sh --runs 3   # check for flakiness
```

Routing regression evals (`claude plugin eval`): each case in `evals/route-*` sends one user utterance
to the orchestrator and asserts which agent or skill it dispatched to. They call the real model
(about $0.2–0.3 per case run), so they are **not** part of `run-checks.sh` — run them when you change
the orchestrator's routing or an agent's `description`. `run-checks.sh` only checks that the required
cases exist and that graders reference real agents.

### Releasing

Bump the version in **both** places, then tag:

```bash
# 1. Bump version in plugins/<name>/.claude-plugin/plugin.json
#    and the matching entry in .claude-plugin/marketplace.json
# 2. Tag — this verifies the two versions agree and creates {name}--v{version}
claude plugin tag ./plugins/so-adk-core
claude plugin tag ./plugins/so-adk-orchestrator
# 3. Push
git push --follow-tags
```

`claude plugin tag` is the mechanical check that `plugin.json` and the marketplace entry did not
drift apart. It creates real git tags, so it is a release-time step and is deliberately **not** part
of `tests/run-checks.sh`.

### Rolling back the plugin migration

The commit immediately preceding the migration is tagged **`pre-plugin`**.

```bash
git tag --list pre-plugin              # confirm the anchor exists
git diff pre-plugin..HEAD --stat       # see everything the migration changed
```

- **Preferred (history-preserving):** `git revert -m 1 <merge-commit>`
- **Emergency:** return the working tree to the pre-migration layout with
  `git checkout pre-plugin -- .` — the legacy `.claude/agents`, `.claude/skills`, `.claude/hooks`
  and `.claude/so-orchestrator.md` are restored intact.

For a user-side rollback after running the migration wrapper, see
[Migrating from the curl installer](#migrating-from-the-curl-installer).

---

## Key Features

- **PostToolUse hooks** — Automatically runs lint/typecheck after Developer edits and feeds failures back to the agent (exit 2)
- **SessionStart hook** — Deterministically surfaces in-progress SPECs on session start so resume never depends on the model remembering to scan
- **Outside-In testing** — Acceptance → E2E → unit test pyramid (reverse testing approach)
- **UI Design specs** — Designer agent creates UI contracts when SPEC includes frontend (optional)
- **Parallel review mode** — Complex SPECs run Reviewer + Architect simultaneously for faster feedback
- **Continuous drift detection** — Auditor scans for dead code, stale deps, missed archives (optional)
- **Non-invasive install** — the orchestrator is a plugin agent, not an injected `CLAUDE.md` import

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
