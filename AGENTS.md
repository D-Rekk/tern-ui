# Repository Guidelines

This repository contains the Beads Tern plugin package under `extensions/beads/`
and root SDK definitions. The plugin is a read-only native issue viewer; its
host owns process requests and pane state, while its window entry opens a board
for the focused project.

## Architecture & Data Flow

- `extensions/beads/plugin.toml` declares the sole plugin package. Host entries
  run in the daemon and define blocks; window entries run in separate VMs and
  manage commands and window integration. Shared imports do not share VM memory.
- The Beads board follows `init → view → key/event → updated view`, with `save`
  for restart preferences. The package is read-only: `bd` supplies issue data;
  the plugin does not mutate Beads issues or initialize databases.
- Beads `host.luau` imports its local `lib/model.luau` and `lib/view.luau`.
  Relative requires stay within the package; generated type definitions are
  ambient declarations, not executable dependencies.

## Key Directories

- `extensions/beads/`: self-contained Beads plugin; read its README and manifest.
- `tern.d.luau`: root Tern SDK definitions.
- `extensions/beads/tern.d.luau`: package-local generated SDK definitions.

## Development Commands

Run from repository root:

```sh
tern plugin install github.com/D-Rekk/tern-ui/extensions/beads
tern plugin link ./extensions/beads
tern plugin list
tern plugin reload
./update-tern-definitions.sh
sh -n update-tern-definitions.sh
luau-lsp analyze --platform=standard --definitions=@tern=tern.d.luau \\
  extensions/beads/host.luau extensions/beads/lib/model.luau \\
  extensions/beads/lib/view.luau extensions/beads/window.luau
```

The definition script prints the installed Tern version, refreshes root SDK
definitions, and refreshes definitions for each extension package with a
`plugin.toml`. Installation is a deliberate user action; do not force-replace
an installed plugin unless specifically authorized. Do not infer build steps
from a workspace fixture. There is no repository-wide test framework.

## Code Conventions

- Follow existing Luau formatting: `--!strict`, tab indentation, PascalCase type
  aliases, local helpers, and explicit prop types.
- Use global `tern` supplied by the runtime. Relative `require` paths must stay
  inside the consuming package; Tern does not resolve `.luaurc` aliases.
- Surface expected I/O/process failures as problem state or toasts. Use `pcall`
  for fallible synchronous operations without swallowing unexpected errors.
- Read `extensions/beads/README.md` for the plugin's behavior and runtime
  compatibility evidence before changing its contract.

## Important Files

- `extensions/beads/host.luau`: lifecycle, asynchronous issue loading and input.
- `extensions/beads/lib/model.luau` and `lib/view.luau`: model and SDK views.
- `extensions/beads/window.luau`: cwd-aware command-palette integration.
- `tern.d.luau`: root SDK definitions; `tern plugin types DIR` regenerates them.
- `.vscode/settings.json` and `.zed/settings.json`: editor Luau settings.

Treat the Beads manifest and source as authoritative when documentation differs.

## Runtime/Tooling Preferences

Tern is the runtime; standalone Lua, LÖVE, or Roblox cannot execute these
plugins unchanged. Use `luau-lsp` and a POSIX shell. No root package manager or
dependency-install step is defined. The Beads package requires the `bd` CLI on
the pane host and reads issue data in read-only mode; consult its README for
external effects and compatibility limitations.

Regenerate definitions after Tern upgrades, then verify the actual runtime.
Definitions alone do not prove API availability.

## Testing & QA

No automated test framework, CI checks, coverage configuration, or coverage
threshold is defined. Use static analysis plus safe runtime smoke checks when
authorized; distinguish a package load from exercising its behavior. Preserve
existing user data and installed plugins.

## Agent skills

### Issue tracker

Use this repository's local Beads (`bd`) database under `.beads/`; run commands
from the repository root and use returned issue IDs. Before actionable,
non-trivial work create a Bead, claim it with `bd update ISSUE --claim`, and
implement only its agreed scope. Genuine Q&A/no-op needs no issue; bounded
trivial single-file changes may omit issue creation but still follow role,
verification and commit requirements.

For each completed implementation pass, spawn a task-scoped Committer to inspect
the final diff, author the commit message, and commit only that task's tracked
changes. Commit before testing. Move the issue to `test`, then spawn a read-only
Tester to inspect the code and exercise relevant edge cases. Tester failures
must be commented on the Bead and return it to `in_progress`; repair and commit,
then use a fresh Tester. A passing Tester records concise evidence and moves the
Bead to `review`. Human review closes issues; do not close on test pass alone.

The custom statuses are `test` and `review`. Kanban lanes map to Beads statuses:
Todo → `open`, In Progress → `in_progress`, Test → `test`, Review → `review`,
Done → `closed`. Triage labels are separate from execution status.

Initialize the local workspace only when `.beads/` is absent:

```sh
BEADS_DIR="$PWD/.beads" bd init --prefix tern-ui --non-interactive \\
  --skip-hooks --skip-agents --remote ""
bd where
bd info --json
```

For a new workspace, configure the custom lanes with
`bd config set status.custom "test,review"`. Verify that `bd where` and
`bd info --json` identify this repository's local database. Do not reinitialize
an existing workspace.

Canonical issue operations:

```sh
bd create "Title" --type task --priority 2 --labels needs-triage \\
  --description "Problem, scope, acceptance criteria"
bd list --status open
bd ready
bd show ISSUE_ID
bd comments ISSUE_ID
bd comment ISSUE_ID "Progress, decision, or handoff"
bd label add ISSUE_ID ready-for-agent
bd label remove ISSUE_ID needs-triage
bd close ISSUE_ID --reason "Completed and verified"
```

Only close after acceptance and verification; human review closes completed
implementation issues.


```sh
bd show ISSUE_ID
bd comments ISSUE_ID
bd update ISSUE_ID --claim
bd heartbeat ISSUE_ID
bd comment ISSUE_ID "Progress, decision, or handoff"
bd label add ISSUE_ID ready-for-agent
bd label remove ISSUE_ID needs-triage
bd update ISSUE_ID --status test
bd update ISSUE_ID --status review
```

Claims are leased; heartbeat before expiry during long work, and stop if
ownership is lost. Preserve existing issue data, avoid reinitialization,
force-close, or deletion as routine workflow, and serialize local embedded
database writes when agents are active.

For each issue whose implementation changes a Tern plugin package, increment
the patch version in that package's `plugin.toml` by 0.0.1 once in the
implementation commit. Do not bump versions for bookkeeping or documentation-only
repository changes.

### Triage labels

Use canonical labels: `needs-triage` (maintainer evaluation), `needs-info`
(awaiting reporter), `ready-for-agent` (specified and agent-ready),
`ready-for-human` (human implementation), and `wontfix` (will not be actioned).
Labels express triage/readiness, not execution status.

### Domain guidance

Root `GLOSSARY.md` is the canonical domain vocabulary. Read it before exploring;
use its terms in issues and docs, avoid rejected synonyms, and surface genuine
gaps or conflicts rather than inventing competing vocabulary. No ADR directory
is maintained; do not create unrelated domain documentation.

### Tern SDK

For plugin or SDK UI work, read the global `tern` skill and its `tern-sdk`
sub-skill, grounded in the official SDK book. Treat installed runtime behavior
as authoritative over declarations and live documentation.
