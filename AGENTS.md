# Repository Guidelines

## Project Overview

This repository contains `tern-ui`, a rendering-only Luau component library for
Tern plugin blocks, plus SDK definitions and example plugins. Components return
native UI nodes; consuming plugins own application behavior and persistence.

## Architecture & Data Flow

- `tern-ui/init.luau` is the canonical library. Constructors accept named props
  and return SDK `Node` trees (`k`, `p`, `c`); they register no plugins and own no
  state, event dispatch, focus, or storage.
- Each `examples/*/plugin.toml` declares an independent plugin's entry points,
  blocks/lenses, and optional styles. Host entries run in the daemon and define
  blocks, hooks, and lenses. Window entries run in separate VMs and manage
  commands, routes, canvases, and window chrome. Shared imports do not share VM
  memory; use explicit SDK storage or communication.
- A host block follows `init → view → key/event → updated view`, with optional
  `save` for restart state. Views return `main`, `dock`, and `layer` regions.
  Wrap region content in a container: Tern renders a region root's children.
- `examples/todo/host.luau` demonstrates the consumer seam: tasks are authoritative
  in `tern.kv`; draft/cursor are transient block state. Views and mutations read
  current storage. Key handling edits bytes and converts the cursor to UTF-16
  code units for TextInput.
- Checkbox uses documented `tern.ui.el` when available, otherwise Done/Undo
  actions. Native `change` assigns `ev.checked`; compatible `action` toggles
  current state. Read `tern-ui/README.md` before changing this contract.

## Key Directories

- `tern-ui/`: canonical library, vendoring command, interface/compatibility docs.
- `examples/`: independent runtime integrations; read the affected example's
  README and manifest before editing it.
- `examples/todo/vendor/tern-ui/`: generated consumer copy. Change canonical
  source, then re-vendor; keep this copy committed for standalone plugin use.

## Development Commands

Run from the repository root:

```sh
# User workflow: install the checked-in plugin directly; no preparation script.
tern plugin install ./examples/todo

# Development alternative: link for reload-on-save instead of installing.
tern plugin link ./examples/todo
tern plugin list
tern plugin reload

# Update an already-installed copy deliberately, rather than a linked plugin.
tern plugin install ./examples/todo --force

# Maintainers only: refresh the consumer after canonical library changes.
sh tern-ui/vendor.sh examples/todo

# Static analysis of the library and its consumer.
luau-lsp analyze --platform=standard --definitions=@tern=tern.d.luau \
  tern-ui/init.luau examples/todo/host.luau

# Shell syntax check.
sh -n tern-ui/vendor.sh
```

Open **New To-do list block** in Tern's command palette to run the consumer.
There is no repository-wide compile, test, lint, or formatter command.
Checked-in examples are directly installable; re-vendoring is a maintainer step.
Do not infer build commands from `examples/workspaces/.tern/workspace.json`.

## Code Conventions & Common Patterns

- Follow existing Luau formatting: `--!strict`, tab indentation, PascalCase type
  aliases and component constructors, local helpers, and explicit prop types.
- Use the global `tern` supplied by the runtime. `tern.d.luau` is ambient type
  information, not an executable dependency. Relative `require` paths must stay
  inside the consuming plugin; Tern does not resolve `.luaurc` aliases.
- Keep components deterministic and rendering-only. Pass labels, state, stable
  sibling keys, and action names through props; retain editing/storage in apps.
- Custom actions split at the first `=` (`delete=42` becomes `act = "delete"`,
  `value = "42"`). Handle native checkbox and compatible action events explicitly.
- Return `false` from a block key handler for an unhandled key; other returns
  trigger render/save. Call `cx:render()` after asynchronous state changes.
- Async work uses SDK callbacks or `Awaitable:next`, with stale/disposed callback
  guards and canceled timers where needed. Window contexts are callback-scoped;
  use the fresh context supplied to a callback rather than retaining WindowCx.
- Surface expected I/O/process failures as problem state or toasts. Existing
  examples use `pcall` around fallible synchronous operations. Compatibility
  detection is explicit; unexpected errors are not silently swallowed.

## Important Files

- `tern-ui/init.luau`: public constructors and exported props types.
- `tern-ui/README.md`: component/event contracts, support boundaries, workarounds.
- `tern-ui/vendor.sh`: copies only `init.luau`, preserving unrelated vendor files.
- `tern.d.luau`: SDK definitions; `tern plugin types DIR` regenerates them.
- `.zed/settings.json`: standard Luau LSP, Tern definitions, Roblox/Rojo disabled.
- `examples/todo/host.luau`: complete component/state/event integration.
- `examples/review-queue/host.luau`: asynchronous process and lifecycle patterns.
- `examples/longrun/window.luau`: window-local event/timer reconciliation.

Treat manifests and source as authoritative when documentation disagrees:
`examples/wip-example/README.md` currently describes the canvas example instead
of its own plugin. For `.tern-env` changes, read `examples/dirvars/README.md` for
the exact-byte approval and shell-start security model.

## Runtime/Tooling Preferences

Tern is the runtime; standalone Lua, LÖVE, or Roblox cannot execute these plugins
unchanged. Use `luau-lsp` for development and a POSIX shell for vendoring. No
Node/Bun runtime, package manager, lockfile, or dependency-install step is defined.
External tools are example-specific: review-queue requires authenticated `gh` on
the pane host; command lenses and longrun require Tern shell integration.

Regenerate definitions after Tern upgrades, then verify the actual runtime.
Definitions alone do not prove API availability. The documented installed-daemon
limitation is missing `tern.ui.el`; the library's native-checkbox path remains
unverified there. Plugin blocks are the library's supported surface; canvases
reject text inputs and lenses have different control semantics.

## Testing & QA

No automated test framework, CI checks, coverage configuration, or coverage
threshold is currently defined. Use static analysis plus a runtime smoke run;
editor diagnostics alone are insufficient.

For component changes, re-vendor and exercise the to-do app: add by Enter and
button, edit Unicode text, complete/reopen, delete the last task, verify empty and
blank-input behavior, and confirm persistence after reload. Use isolated fixture
data or uniquely named smoke tasks; preserve existing user tasks. Verify both
checkbox event paths when the runtime supports them and name any unverified path.

For vendoring changes, check shell syntax, source/copy equality, repeatability,
missing-manifest rejection, and preservation of unrelated vendor files. Runtime
control/screenshot commands are documented by `tern help dev`; distinguish
real-plugin checks from headless fixture runs. Update the affected README when
behavior or compatibility changes.

## Agent skills

### Issue tracker

Use this project's local Beads (`bd`) workspace for issues and specs. Before
tracker operations and actionable repository work, read
`docs/agents/issue-tracker.md` and follow its Bead gate and
Implementer/Committer/Tester lifecycle. Create and link a Bead before
non-trivial work; genuine no-ops and Q&A need none. Only typos/trivial files
and bounded low-risk single-file changes with no public API, persistence, or
cross-component impact may omit a ticket; those exceptions do not waive the
role, verification, or commit workflow.

For each issue whose implementation changes a Tern plugin package, increment
the patch version in that affected package's `plugin.toml` manifest by 0.0.1
once, in the same implementation commit. Do not bump versions for issue
bookkeeping or repository-level documentation-only changes.

### Triage labels

Use the five confirmed canonical labels; see `docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `GLOSSARY.md` and `docs/adr/`. Before exploration, follow
`docs/agents/domain.md`.

### Tern SDK

For plugin or SDK UI work, read the global `tern` skill and its
`tern-sdk/SKILL.md` sub-skill, grounded in the official SDK book.

When deriving Tern UI nodes with `tern.ui.el`, read
`docs/tern-ui/examples/el.md` for composition and CSS patterns.
