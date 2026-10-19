# Beads runtime and compatibility notes

[Back to the current Beads package README](../README.md)

This page preserves the verified runtime and compatibility evidence for the
Beads package. Historical observations are version-specific; they do not imply
that untested Tern versions have the same behavior. The current README describes
installation, interaction, loading failures, and the read-only/security contract.

## Runtime requirements and history

The viewer uses native plugin blocks, `tern.ui.node("el", ...)`, native
`list`/`item`, `icon`/`kbd` nodes, manifest styles, asynchronous
`tern.process.run`, and window session inspection. Auto Picture-in-Picture
selection uses Tern 0.4.5's native `.tn-pane.pip` owner class, an implementation
hook rather than a stable SDK contract. The online SDK is unversioned.

The original package's native loading and interactions were exercised on Tern
0.4.5 (`1d14241`). Beads 1.0.1 loading and interactions were exercised on macOS
Tern 0.6.0 (`0e39682`); these runs do not establish older-runtime compatibility
for the 1.0.2 native list renderer. The Beads CLI (`bd`) must be available on the
machine running the panes. Beads 1.3.0 provides the required
`list --all --limit 0 --json --readonly` flags and full issue text; older
versions must support the same flags and fields. For remote sessions, install
this package and `bd` on the pane host, and install the package on the local
window machine to provide **Open Beads board**. iOS cannot run the CLI locally;
a remote desktop host must supply the block.

## Interaction acceptance evidence

Native Beads 1.0.1 acceptance on macOS Tern 0.6.0 (`0e39682`) exercised Board
and Tabs mouse controls, native keyboard Enter/Space activation, exact-ID
clipboard contents without navigation, and inert card bodies. Long
board/tab/detail scrolling, opaque sticky chrome, back controls, delayed refresh
success/failure, loading accessibility, reduced motion, and populated status
dots were covered. Empty status dots retain prior native 0.6.0 coverage and were
not newly rerun. Wrapping was verified on first load and reload, at
560/1280/1600-pixel window widths, with a 20px terminal font, during pending
refresh, and through native PiP/dock switches. The read-only argv and
single-flight guard were inspected in source rather than process-instrumented;
pane-closure lifetime stress was not rerun. Dynamic footer opacity and CSS Grid
are not claimed.

## Native layout and CSS probes

Native compatibility probes on Tern 0.6.0 (`0e39682`) rejected both
`repeat(auto-fill, minmax(300px, 1fr))` and
`repeat(auto-fit, minmax(300px, 1fr))`. The former Tabs card layout used
responsive Flex instead of CSS Grid and followed actual surface width when
control-viewport dimensions and daemon pane columns temporarily disagreed.
Version 1.0.2 replaces those cards with native `list`/`item` rows, so the
card-wrapping rule no longer applies.

Some older Tern surfaces expose `--sf-lh` and `--sf-fs` values that collapse
native list text and rows. The scoped Beads stylesheet sets its surface and
native `.sf-item` rows to the larger of the surface line-height and 1.3 times
the surface font size (`--sf-lh` defaults to 1.3 times the font size and
`--sf-fs` defaults to `12px` when missing). This preserves a larger valid Tern
line-height while ensuring rows have at least enough height for readable text in
Board and Tabs. The fallback only affects `plugin.beads.board`; it does not
change issue loading or storage. Successful main-region scrolling left its
classes unchanged. The official [native CSS subset](https://docs.stencil.so/tern/styles/css.md)
documents no scroll-state selector or scroll-driven animation timeline;
browser CSS is not a compatibility fallback.

Tern owns the main, dock and layer region elements. Beads' `BlockView` returns
only `main`; omitting `dock` supplies no dock content but does not delete Tern's
native dock wrapper. The SDK has no documented `BlockView` control for deleting
that wrapper. The Beads stylesheet uses `:empty { display: none; }` on its dock
to remove the empty region from layout, **not** from the native element tree.

The [public region styling hooks](https://docs.stencil.so/tern/styles/index.md)
are `.sf-main` / `.sf-dock` with `data-surface` on the region itself. The
`sf-chat-reader` class identifies Tern's Chat style setting; these rules do not
depend on that mode or target another plugin's regions. The [native CSS
contract](https://docs.stencil.so/tern/styles/css.md) supports `:empty`,
`display: none`, and the four-sided `padding` shorthand.

An isolated actual macOS Tern 0.6.2 (`4b3ed42`) GUI probe observed an empty
native dock consuming 24 CSS pixels even with `dock` omitted. The scoped hiding
rule collapsed it to an invisible zero-size rectangle while the element
remained, and increased main-region height by 24 pixels. Plain `padding: 0` did
not override the native main inset. `padding: 0 !important` removed the six-pixel
top and bottom inset: the Beads root then exactly filled the main rectangle
(`1248 × 734` at `16, 50`), with the toolbar at its top and footer at its bottom.
A diagnostic `11px 13px 17px 19px !important` padding changed the root on all
four sides, confirming their editability; the shipped value is zero throughout.
These observations establish the region override on 0.6.2, not a rerun of the
historical 0.6.0 interaction acceptance above.
