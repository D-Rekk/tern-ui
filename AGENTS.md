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
tern plugin install ./extensions/beads
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

## Code Conventions & Common Patterns

- Follow existing Luau formatting: `--!strict`, tab indentation, PascalCase type
  aliases, local helpers, and explicit prop types.
- Use global `tern` supplied by the runtime. Relative `require` paths must stay
  inside the consuming package; Tern does not resolve `.luaurc` aliases.
- Surface expected I/O/process failures as problem state or toasts. Use `pcall`
  for fallible synchronous operations without swallowing unexpected errors.
- Read `extensions/beads/README.md` for the plugin's behavior and runtime
  compatibility evidence before changing its contract.


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

Run from the root; use returned IDs. Follow the issue lifecycle, claim/lease,
status lane, and operation guidance here: create a Bead before non-trivial
work, claim before implementation, use a task-scoped Committer, commit before
testing, then use a read-only Tester. Tester failures return the issue to
issue to `in_progress`; a passing Tester records evidence and moves it to
`review`. Human review closes issues; do not close them on test pass alone.
Preserve existing issue data and serialize local tracker writes. Claims expire;
heartbeat during long work.

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
