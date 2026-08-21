# SO-ADK — repository instructions

This repository **is** SO-ADK, and it dogfoods itself: the agents, skills, hooks and orchestrator
that used to live in `.claude/` now live in `plugins/` and are loaded as Claude Code plugins.

Nothing here imports the orchestrator into `CLAUDE.md` any more. The orchestrator is supplied by the
`so-adk-orchestrator` plugin, which replaces the main-thread agent through its own `settings.json`.

## If you are editing `plugins/`

Load the plugins from the working tree:

```bash
claude --plugin-dir ./plugins/so-adk-core --plugin-dir ./plugins/so-adk-orchestrator
```

Do **not** use `claude plugin install` for this. Install copies the plugin into a cache and loads the
copy, so your edits to `plugins/` are silently not reflected — no error, no warning.

## If you only consume SO-ADK here

The committed `.claude/settings.json` registers the marketplace but does **not** install anything.
Run this once per clone:

```bash
claude plugin install so-adk-core@so-adk --scope project
claude plugin install so-adk-orchestrator@so-adk --scope project
claude plugin list   # confirm ✔ enabled for both
```

## House rules

- Personal settings go in `.claude/settings.local.json` (gitignored). `.claude/settings.json` is
  gated to exactly `extraKnownMarketplaces` and `enabledPlugins` — `tests/run-checks.sh` fails
  otherwise.
- Never run `claude plugin marketplace remove so-adk` here: it empties the committed
  `.claude/settings.json`. Recover with `git checkout -- .claude/settings.json`.
- Run `bash tests/run-checks.sh` before committing.

Full details — installation, scope warnings, migration, release and rollback procedures — are in the
[Development section of the README](README.md#development).
