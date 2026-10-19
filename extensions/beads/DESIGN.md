# Beads package design

The package separates Tern's two execution contexts. `host.luau` owns the board
block lifecycle, read-only `bd` process requests, UI state, and event handling.
`lib/model.luau` normalizes issue records and groups them into lanes;
`lib/view.luau` renders SDK node trees. `window.luau` provides the cwd-aware
command-palette entry and opens the host block. `beads.css` scopes presentation
to the Beads board.

Issue data is fetched on demand and is not persisted by the plugin. Tern's block
save state retains only project and display preferences. The package does not
initialize or mutate Beads databases; see [README](README.md) for process,
compatibility, and security details.
