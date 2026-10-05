# tern-ui Overview

A standalone Tern plugin that presents the current `tern-ui` components in one host-side block. It has no external dependencies; the vendored module and stylesheet are included.

## Install and run

From the SDK root:

```sh
tern plugin install ./examples/overview
```

Open the command palette and choose **Overview**. To update an installed copy, run `tern plugin install ./examples/overview --force`. For live checkout development, use `tern plugin link ./examples/overview` instead. The checked-in `vendor/tern-ui` files are ready to use; maintainers changing the canonical library should refresh them with `sh tern-ui/vendor.sh examples/overview`.

## Explore

The block displays ActionButton, Flex, Checkbox, TextInput, TaskRow, and EmptyState sections together. Click the action button to update its status, switch Flex between row and column, and toggle the Checkbox. Native checkbox `change` events copy `checked` into transient state; runtimes using the compatible Done/Undo action path toggle current state instead. Complete/reopen or delete the sample TaskRow, then restore it. TextInput accepts Unicode-aware typing and cursor movement in transient block state only; its text is never written to `tern.kv` or another persistent store. EmptyState is shown as a representative muted message.

For complete constructor props, event contracts, and compatibility notes, see [`tern-ui/README.md`](../../tern-ui/README.md).

## Type checking

From the SDK root, with `luau-lsp` installed:

```sh
luau-lsp analyze --platform=standard --definitions=@tern=tern.d.luau \
  tern-ui/init.luau examples/overview/host.luau
```
