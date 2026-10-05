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

The viewer requires the standalone `luau-lsp` executable as an external CLI
prerequisite; no plugin package is missing. Obtain it from the
[official latest releases](https://github.com/JohnnyMorganz/luau-lsp/releases/latest)
and follow the project's [standalone installation instructions](https://github.com/JohnnyMorganz/luau-lsp/blob/1.70.1/README.md#standalone).
Select the release matching the host operating system, install the executable,
and put it on the `PATH` inherited by the Tern host process. Verify it there
with `luau-lsp --help`. A successful shell check may not reflect the smaller
`PATH` available to a GUI-launched Tern app; after changing the environment,
restart Tern (and its daemon) so the host process inherits the updated `PATH`.

For files on a remote host, install the plugin there as well as in the
window's local Tern instance, and install `luau-lsp` on the remote host with
its executable on the `PATH` of that host's Tern process. See Tern's
[remote host installation guide](https://docs.stencil.so/tern/guides/distribution.md#remote-hosts).

Tern plugin packaging does not automatically install native dependencies,
select a platform-specific binary, or launch a bundled executable: this
plugin's `tern.process.run` invocation resolves `luau-lsp` through the host
process `PATH` and runs the one-shot `analyze` command, rather than connecting
to a persistent LSP server. See Tern's documentation on
[process execution and `PATH`](https://docs.stencil.so/tern/guides/io.md#processes-ternprocessrun)
and [environment and logging](https://docs.stencil.so/tern/guides/io.md#environment-and-logging).
Bundling an executable would require intentional per-platform distribution,
launch, and update handling; it is not an automatic plugin feature documented
by Tern.

If `luau-lsp` is missing or the analyzer fails, the viewer reports that state
and still shows the source. Ensure the Tern host process can find the
executable to enable diagnostics.
