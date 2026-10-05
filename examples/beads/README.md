# Beads

A native, read-only Beads issue viewer for Tern, with a horizontal Kanban board
and compact status tabs. **Auto** follows the pane size reported by the host;
explicit **Board** and **Tabs** controls remain usable when sizing is delayed.
The viewer uses the official SDK directly, with no `tern-ui`, vendoring, build
step, or additional dependencies.

## Prerequisites and installation

- Desktop Tern with native plugin blocks, `tern.ui.node("el", ...)`, manifest
  styles, asynchronous `tern.process.run`, and window session inspection.
  Actual native loading and interactions were exercised on Tern 0.4.5
  (1d14241); the online SDK is unversioned.
- The Beads CLI (`bd`) on the **machine running the panes**, and an existing
  Beads project/database. Beads 1.3.0 provides the required `list --all --limit 0
  --json --readonly` flags and full issue text. Older versions must support those
  same flags and JSON fields.
- For remote sessions, install this package and `bd` on the pane host; install
  the package on the local window machine as well to get **Open Beads board**.
  iOS cannot run the CLI locally; a remote desktop host must supply the block.

From this repository's root:

```sh
tern plugin install ./examples/beads
```

To replace an installed copy after updating the source:

```sh
tern plugin install ./examples/beads --force
```

For live development instead of a copied installation:

```sh
tern plugin link ./examples/beads
```

An installed copy does not follow source edits. Do not install over a linked
package; use `tern plugin unlink beads` first. `tern plugin list` and Preferences
→ Plugins show package status; a successful installation alone does not prove
that the window entry loaded.

## Open a project

Focus a project shell, then choose **Open Beads board** in the command palette.
The command explicitly passes the focused pane's reported working directory,
not the tab's original directory. Shell integration must report directory
changes to Tern. Each command opens a new board, so separate projects can be
viewed side by side. The built-in **New Beads board block** also works when the
block's initial cwd is the desired project directory.

Automation and other window plugins can choose an explicit directory. For
example, in Carly's Lua tool (which provides `cx`):

```luau
return cx:new_block("beads.board", { "/absolute/path/to/project" }, "beside")
```

The optional second argument selects a specific executable, useful when a
GUI-launched daemon has a different `PATH` or for controlled runtime testing:

```luau
return cx:new_block("beads.board", {
    "/absolute/path/to/project",
    "/absolute/path/to/bd",
}, "beside")
```

Use absolute paths, without shell quoting inside the strings. Spaces and shell
metacharacters remain literal argument data. The default executable search is
`bd` on the host's `PATH`, then `~/.local/bin/bd`, `/opt/homebrew/bin/bd`, and
`/usr/local/bin/bd`. A bad executable or nonexistent project directory produces
an actionable error rather than opening another project's board.

## Interaction

- The five standard lanes are always present: **Todo** (`open`), **In Progress**
  (`in_progress`), **Test** (`test`), **Review** (`review`), **Done** (`closed`).
- Populated `blocked`, `deferred`, and unknown/custom statuses get additional
  lanes, sorted by their stored status. No status is silently discarded.
- Cards show ID, title, priority, issue type, and assignee/labels when supplied.
  P0 is critical. Issues are sorted by ascending priority, then ID.
- Click a card to read its full description, design, acceptance criteria and
  notes, plus issue metadata. Markdown text is rendered natively; nothing is
  shortened by the viewer. Click **← Board**, press Escape, or press Backspace
  to return. An issue absent after a successful refresh is reported explicitly.
- **Refresh** or `r` reads the database again. There is no automatic polling.
  Repeated refresh requests while one is running are ignored; they do not
  launch concurrent processes.
- **Auto** (the default) uses Kanban at 110 or more host-reported terminal
  columns and tabs below that threshold. **Board** forces Kanban regardless of
  the reported size; **Tabs** forces compact tabs. `t` cycles Auto → Board →
  Tabs. Lane tabs wrap to keep every status reachable; horizontal scrolling
  exposes extra Kanban columns.
- Tern 0.4.5 can initially report an 80×24 block size even when the client
  pane is wider, and native resize notifications can be delayed. If Auto does
  not match the pane you see, choose **Board** or **Tabs** explicitly. This is
  a runtime sizing limitation, not a claim of reliable automatic resizing on
  that build; both explicit modes work without a sizing notification.
- `←`/`→` (or `h`/`l`) choose a lane; `↑`/`↓` (or `k`/`j`) choose its card.
  Home/End choose its first/last card. Enter or `o` opens the chosen issue.
  The outlined card is the keyboard selection. Pointer scrolling remains
  available for long boards and details.

Colors, surfaces, borders, and status accents use Tern theme variables rather
than a hard-coded dark palette. Cards use stable issue IDs, and lane identities
use stored statuses. Project, layout, selected lane/card and detail selection
survive plugin reload or pane restart; the issue dataset is **not persisted**
and is freshly read on each restart.

## Loading and failures

The first request shows loading progress. Empty databases and empty lanes have
explicit empty states. Refreshes keep existing cards/details visible. A failed
refresh retains the last successful dataset with a visible **Stale data**
warning and the actual diagnostic; it does not masquerade as a successful empty
board. Successful refresh clears the error and updates the dock timestamp.

Missing `bd`, missing databases, invalid JSON or malformed issue rows,
non-zero exits and a 30-second timeout are shown in the pane. Fix the reported
problem on the pane host and refresh. If a project is not initialized, run
`bd init` yourself in the appropriate shell; the viewer never does it.
For an independent diagnostic, run this yourself in the same project:

```sh
bd list --all --limit 0 --json --readonly
```

The SDK captures at most 16 MiB of stdout per process. Extremely large lists
that exceed that SDK limit will normally be rejected as incomplete JSON rather
than silently showing partial data. Diagnostic excerpts are limited to 2,000
bytes; successful issue content is not intentionally truncated.

Restarted panes invalidate the prior run's callbacks, even when the pane ID is
reused. Closed panes retire state when an outstanding request completes; an
already-started process finishes or reaches its timeout, but cannot render
into a closed or replacement block. No polling timers remain behind.

## Read-only and security boundaries

The only external operation is the asynchronous argument-vector invocation:

```text
bd list --all --limit 0 --json --readonly
```

It runs with the chosen project's cwd and clears inherited `BEADS_DIR`,
`BEADS_DB`, and `BD_DB` overrides, so those host variables cannot silently
select another project. It also clears `BEADS_MAX_ROWS` so an inherited
row limit cannot defeat the full list, and adds `NO_COLOR=1`. Other CLI/project configuration remains Beads'
responsibility. The plugin does not initialize databases, update statuses,
edit issues, add comments, run a shell, provide drag-and-drop mutations, write
project files, contact servers itself, or use persistent `tern.kv` storage.
Tern saves only the UI/project preferences described above with the pane.

`--readonly` blocks Beads issue mutations, not every filesystem effect of an
external program: `bd` may still read configuration, acquire locks, or perform
its own database/runtime housekeeping. Database/backend configuration can
cause `bd` itself to contact its configured server. Native Markdown links can
be opened through Tern's normal link behavior at the user's request.

Like all Tern plugins, this code and the selected `bd` executable run with the
host user's rights; there is no permission sandbox. Review the manifest,
entries, imported modules and executable before installing. Read-only is this
plugin's application contract, not a security boundary against a modified
plugin, untrusted executable, or another process writing the database.

## Package layout

`host.luau` owns lifecycle, process requests and interaction; `model.luau`
normalizes issue data and groups statuses; `view.luau` returns SDK node trees;
`window.luau` supplies the cwd-aware palette command. `beads.css` is scoped to
`plugin.beads.board`. Generic `ui.node("el", ...)` avoids relying on the
`ui.el` convenience builder that was missing in the installed 0.4.5 host VM.
