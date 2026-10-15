# Beads

A native, read-only Beads issue viewer for Tern, with a horizontal Kanban board
and compact status tabs. **Auto** switches to tabs in native Picture-in-Picture
without waiting for host resize notifications. Explicit **Board** and **Tabs**
controls preserve the user's chosen layout. The viewer uses the official SDK
directly, with no `tern-ui`, vendoring, build step, or additional dependencies.

See the [light and dark screenshot gallery](docs/README.md) for Board, Tabs,
expanded issue details, and compact native Picture-in-Picture views.

## Prerequisites and installation

- Desktop Tern with native plugin blocks, `tern.ui.node("el", ...)`, native
  `list`/`item` nodes (used by Beads 1.0.2 issue rows), `icon`/`kbd` nodes,
  manifest styles, asynchronous `tern.process.run`, and window session
  inspection. The Auto PiP selector uses Tern 0.4.5's native `.tn-pane.pip`
  owner class, an implementation hook rather than a stable SDK contract. The
  original package's native loading and interactions were exercised on Tern
  0.4.5 (1d14241). Beads 1.0.1 loading and interactions were exercised on macOS
  Tern 0.6.0 (0e39682); those runs do not establish older-runtime compatibility
  for the 1.0.2 native list renderer. The online SDK is unversioned.
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
- Native list rows show the issue ID, title, type, assignee, labels, and priority;
  P0 is highlighted in the error tone. Clicking a row opens its full description,
  design, acceptance criteria, and notes. The context menu's **Copy Bead ID**
  action copies only the exact ID; Tern's built-in **Copy** remains available for
  row text. Use the icon-only **Back to board** arrow, press Escape, or press
  Backspace to return. Details place status/priority badges beneath the title,
  group metadata into an issue overview, and separate each full Markdown section.
  An issue absent after a successful refresh is reported explicitly.
- The block owns keyboard selection: `↑`/`↓` (or `k`/`j`) move within the active
  lane; Home/End select the first/last issue, Enter or `o` opens it, and `←`/`→`
  (or `h`/`l`) change lanes. Native selection tint follows the same cursor.
  Pointer scrolling remains available for long boards and details.
- The icon-only **Refresh issues** control or `r` reads the database again.
  Its native `fetch` icon rotates in its normal theme color only while a real
  request is pending, and stops on success or failure. Reduced-motion settings
  disable rotation and status-dot pulsing without hiding loading semantics.
  There is no automatic polling. Repeated refresh requests while one is running
  are ignored; they do not launch concurrent processes.
- **Auto** (the default) uses Board while docked and compact Tabs in native
  Picture-in-Picture. Both layout trees stay mounted so float/dock switches
  immediately without a host update; docking restores Board. **Board** forces
  Kanban; **Tabs** forces the compact status view. `t` cycles Auto → Board → Tabs.
  Lane tabs wrap to keep every status reachable; Board columns scroll
  horizontally. Tabs shows one native issue list for the active lane.
- Auto is a dock/PiP policy, not a general pane-width detector. For a narrow
  docked split, choose **Tabs** explicitly. Tern 0.4.5 can leave host dimensions
  unchanged on float/dock, so the viewer uses the native PiP owner class in CSS,
  not `cx.cols`, timers, or cross-VM messages. A future Tern build that changes
  this private class will require a selector update; explicit modes remain
  independent.
- The toolbar stays at the top of the main scroll region. One compact footer
  inside that same region combines project path, issue count and freshness
  (**Refreshing…**, update time, **Stale data**, or **Not loaded**) with native
  Tern keycaps for **R** refresh and **T** layout, plus **ESC** back while details
  are open. Other navigation keys remain supported without crowding the bar.
  The footer stays opaque in the theme's card color so content scrolling
  beneath it remains readable. Dynamic translucence was investigated but no
  supported CSS-only scroll-state route was found in Tern 0.6.0; an opaque
  footer was selected instead.
- Beads removes the unused native dock from layout only while it is empty, and
  sets the native main region's padding to zero on all four sides. Toolbar,
  footer and lane padding remain unchanged. Both overrides match only
  `plugin.beads.board`; a populated dock does not match the hiding rule.

Colors, surfaces, borders, and status accents use Tern theme variables rather
than a hard-coded dark palette. Rows use stable issue IDs, and lane identities
use stored statuses. Project, layout, selected lane/row, and detail selection
survive plugin reload or pane restart; the issue dataset is **not persisted**
and is freshly read on each restart.

## Loading and failures

The first request shows loading progress. Empty databases and empty lanes have
explicit empty states. Refreshes keep existing rows/details visible. A failed
refresh retains the last successful dataset with a visible **Stale data**
warning and the actual diagnostic; it does not masquerade as a successful empty
board. Successful refresh clears the error and updates the footer timestamp.

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

The copy control uses the official [host `cx:copy(text)` effect](https://docs.stencil.so/tern/reference/api-host.md#effect-cx),
which copies the supplied ID to the clipboard of the window showing the pane.
Native Beads 1.0.1 acceptance on macOS Tern 0.6.0 (0e39682) exercised Board and
Tabs mouse controls, native keyboard Enter/Space activation, exact-ID clipboard
contents without navigation, and inert card bodies. Long board/tab/detail
scrolling, opaque sticky chrome, back controls, delayed refresh success/failure,
loading accessibility, reduced motion, and populated status dots were covered.
Empty status dots retain prior native 0.6.0 coverage and were not newly rerun.
Wrapping was verified on first load and reload, at 560/1280/1600-pixel
window widths, with a 20px terminal font, during pending refresh, and through
native PiP/dock switches. The read-only argv and single-flight guard were
inspected in source rather than process-instrumented; pane-closure lifetime
stress was not rerun. Dynamic footer opacity and CSS Grid are not claimed.

Native compatibility probes on Tern 0.6.0 (0e39682) rejected both
`repeat(auto-fill, minmax(300px, 1fr))` and `repeat(auto-fit, minmax(300px, 1fr))`.
The former Tabs card layout used responsive Flex instead of CSS Grid and
followed actual surface width when control-viewport dimensions and daemon pane
columns temporarily disagreed. Version 1.0.2 replaces those cards with native
`list`/`item` rows, so the card-wrapping rule no longer applies.

### Native list typography compatibility

Some older Tern surfaces expose `--sf-lh` and `--sf-fs` values that collapse
native list text and rows. The scoped Beads stylesheet sets its surface and
native `.sf-item` rows to the larger of the surface line-height and 1.3 times
the surface font size (`--sf-lh` defaults to 1.3 times the font size and
`--sf-fs` defaults to `12px` when missing). This preserves a larger valid Tern
line-height while ensuring rows have at least enough height for readable text
in Board and Tabs. The fallback only affects `plugin.beads.board`; it does not
change issue loading or storage.
Successful main-region scrolling left its classes unchanged. The official
[native CSS subset](https://docs.stencil.so/tern/styles/css.md) documents no
scroll-state selector or scroll-driven animation timeline; browser CSS is not
a compatibility fallback.

### Native region spacing

Tern owns the main, dock and layer region elements. Beads' `BlockView` returns
only `main`; omitting `dock` supplies no dock content but does not delete Tern's
native dock wrapper. The SDK has no documented `BlockView` control for deleting
that wrapper. The Beads stylesheet uses `:empty { display: none; }` on its dock
to remove the empty region from layout, **not** from the native element tree.

The [public region styling hooks](https://docs.stencil.so/tern/styles/index.md)
are `.sf-main` / `.sf-dock` with `data-surface` on the region itself. The
`sf-chat-reader` class identifies Tern's Chat style setting; these rules do not
depend on that mode or target another plugin's regions.
The [native CSS contract](https://docs.stencil.so/tern/styles/css.md) supports
`:empty`, `display: none`, and the four-sided `padding` shorthand.

An isolated actual macOS Tern 0.6.2 (4b3ed42) GUI probe observed an empty native
dock consuming 24 CSS pixels even with `dock` omitted. The scoped hiding rule
collapsed it to an invisible zero-size rectangle while the element remained,
and increased main-region height by 24 pixels. Plain `padding: 0` did not
override the native main inset. `padding: 0 !important` removed the six-pixel
top and bottom inset: the Beads root then exactly filled the main rectangle
(`1248 × 734` at `16, 50`), with the toolbar at its top and footer at its bottom.
A diagnostic `11px 13px 17px 19px !important` padding changed the root on all
four sides, confirming their editability; the shipped value is zero throughout.
These observations establish the region override on 0.6.2, not a rerun of the
historical 0.6.0 interaction acceptance above.

## Read-only and security boundaries

The only external process invocation is the asynchronous argument vector:

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

User-initiated ID copying sends only the exact Bead ID to the receiving
window's clipboard through `cx:copy`; it does not invoke another process,
navigate, or mutate Beads data.

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
