# To-do

A native Tern block for a persistent checklist, built with [tern-ui](../../tern-ui/README.md). No external dependencies.

## Run

From the SDK root, install the checked-in plugin directly:

```sh
tern plugin install ./examples/todo
```

Its `vendor/tern-ui` module is already included. No shell packaging step or
package manager is needed to run it. Open the command palette and select
**New To-do list block**.

To update an already-installed copy:

```sh
tern plugin install ./examples/todo --force
```

For live development, use `tern plugin link ./examples/todo` instead of install;
linked plugins reload on save. Tern requires resolving an existing installed
copy before linking the same id.

Only maintainers changing the canonical library need to refresh the checked-in
copy with `sh tern-ui/vendor.sh examples/todo` before testing or committing it.

## Use

- Type a task and press **Enter**, or click **Add task**.
- Click a task's checkbox to complete or reopen it. On runtimes without `tern.ui.el`, click **Done** or **Undo** instead.
- Click **Delete** to remove a task permanently.
- **Left/Right**, **Home/End**, **Backspace/Delete** edit the draft by Unicode code point.
- **Escape** clears the draft. Blank tasks are ignored; pasted line breaks become spaces.

Tasks are stored with `tern.kv` in the plugin's `kv.json` and survive closing
blocks and plugin reloads. The list is shared by this plugin's blocks on the
same host; each view and action reads the current store. Another open block
shows changes on its next render. Unsubmitted drafts are not persisted.

The app uses a host-side block because Tern canvases do not support text
inputs. Its view uses tern-ui's TaskRow, EmptyState, TextInput, and ActionButton;
TaskRow also uses Checkbox. The app still owns editing, storage, and events.
Both native checkbox `change` events and compatible `action` events are handled.
The installed host VM lacks `tern.ui.el`; tern-ui supplies Done/Undo actions
without changing the stored tasks. See the library's compatibility notes for
unverified native behavior.

## Type checking

From the SDK root, with luau-lsp installed:

```sh
luau-lsp analyze --platform=standard --definitions=@tern=tern.d.luau examples/todo/host.luau
```
