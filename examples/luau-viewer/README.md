# Luau Viewer

Luau Viewer opens `.luau` files in Tern's native highlighted code view with
line numbers. The source is read-only. It also runs `luau-lsp analyze`
asynchronously and displays its analyzer diagnostics in the viewer. This is
analyzer-backed diagnostics, not an interactive LSP editor: completion and
hover are not provided.

## Open behavior

Plain `.luau` opens from Tern's Files pane or palette use Luau Viewer. Opens
with an explicit placement or target line, CLI opens, links and drops keep
Tern's normal behavior. **Open with › Luau Viewer** remains available from a
`.luau` file's menu for explicit use.

## Install

From the root of the tern-sdk checkout:

```sh
tern plugin install ./examples/luau-viewer
```

To load the checkout directly and reload it when files change:

```sh
tern plugin link ./examples/luau-viewer
```

The host running the opened file needs `luau-lsp` available on the `PATH`
visible to Tern. `luau-lsp analyze` is started with the file path directly,
without a shell. For files on a remote host, install the plugin there as well
as in the window's local Tern instance, and make `luau-lsp` available on that
host. See Tern's plugin distribution guide for [remote host installation](https://docs.stencil.so/tern/guides/distribution.md#remote-hosts).

If `luau-lsp` is missing or the analyzer fails, the viewer reports that state
and still shows the source. Install `luau-lsp` and ensure the Tern host process
can find it to enable diagnostics.
