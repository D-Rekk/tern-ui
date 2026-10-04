# tern-ui

Rendering-only Luau components for Tern plugin blocks. Components return SDK
`Node` values; the application owns state, event handling, keyboard editing,
focus, and persistence. No package manager, runtime dependencies, or stylesheet
is required beyond Tern itself.

## Install the example directly

From the SDK root:

```sh
tern plugin install ./examples/todo
```

The checked-in example already contains the library. There is no shell
packaging step for users; `--force` updates an existing installed copy.
Installation copies the complete plugin directory into Tern's plugins folder.

## Consume or maintain the library

Dependency modules must exist inside each consuming plugin. Import its
plugin-local copy:

```luau
local UI = require("./vendor/tern-ui")
```

`tern-ui/init.luau` is the canonical source; plugin installation is not a
dependency resolver and does not discover this sibling directory. For another
plugin, include that file as `vendor/tern-ui/init.luau` in its package.

Maintainers can refresh a consumer with `sh tern-ui/vendor.sh PLUGIN_DIR`.
The helper copies only `init.luau`, requires a destination `plugin.toml`, and
preserves unrelated vendor files. Run it after changing canonical source and
commit the consumer copy; edit the canonical file rather than generated copies.
The helper can be invoked by absolute path from outside the SDK root.

## Components

All constructors take one named props table and return one `Node`. Type aliases
are exported from the module (for example, `UI.CheckboxProps`).

| Constructor | Required props | Optional props |
| --- | --- | --- |
| `ActionButton` | `label: string`, `action: string` | `key`, `tone`, `aria` |
| `Checkbox` | `label: string`, `checked: boolean`, `name: string`, `value: string`, `action: string` | `key`, `aria` |
| `TextInput` | `text: string`, `cursor: number`, `key: string` | `placeholder`, `aria` |
| `TaskRow` | `key: string`, `label: string`, `completed: boolean`, `name: string`, `value: string`, `toggleAction: string`, `deleteAction: string` | none |
| `EmptyState` | `message: string` | `key` |

Optional props are strings. `TextInput.cursor` is a UTF-16 code-unit offset,
not a Luau byte offset. Supply stable keys for repeated or interactive nodes.
Tern requires keys to be unique among siblings. Do not use positions as task
keys when rows can be deleted or reordered.

```luau
local ui = tern.ui
local UI = require("./vendor/tern-ui")

local function view(state)
    return {
        main = ui.col({
            UI.TaskRow({
                key = "42", label = "Ship the change", completed = state.done,
                name = "task", value = "42",
                toggleAction = "toggle=42", deleteAction = "delete=42",
            }),
        }),
        dock = ui.col({
            UI.TextInput({
                key = "draft", text = state.draft, cursor = state.cursor16,
                placeholder = "What needs doing?", aria = "New task",
            }),
            UI.ActionButton({ label = "Add task", action = "add" }),
        }),
    }
end
```

Wrap components in `tern.ui.col` or another region container. Tern renders a
region root's children, not the root itself.

`ActionButton` is a native badge with a click action, not a native HTML button.
`Checkbox` displays a label and a checked control when `tern.ui.el` is available;
its compatible rendering displays Done/Undo and the same label instead.
`TaskRow` combines Checkbox and a Delete action; completion dims and strikes
through its label. `EmptyState` displays muted explanatory text.

## Events belong to the app

`ActionButton` and TaskRow's Delete emit SDK `action` events. Tern splits an
action at its first `=`: `delete=42` becomes `act = "delete", value = "42"`.

Checkbox intentionally has two event shapes:

| Rendering | Event | Consumer responsibility |
| --- | --- | --- |
| Native checkbox | `{ ev = "change", name, value, checked }` | Set state to `checked`; do not toggle it again |
| Compatible Done/Undo action | `{ ev = "action", act, value? }` from `action` | Toggle the target in current app state |

For TaskRow, native events use its `name` and `value`; compatible events use
its `toggleAction`. Its native checkbox does not also emit that action.
Choose names/actions that identify the same logical operation and handle both:

```luau
if ev.ev == "change" and ev.name == "task" then
    -- Locate by ev.value and assign ev.checked == true.
elseif ev.ev == "action" and ev.act == "toggle" then
    -- Locate by ev.value and invert the current completion state.
end
```

`examples/todo/host.luau` supplies the complete integration, including deletion,
storage, and both event paths. There is no event adapter in this library.

TextInput is a picture of app-owned text. Handle keys and paste in the block's
`key` handler and update `text` and `cursor`. Focus it after rendering with
`cx:frame({ { "focus", "dock.draft" } })`, and answer its `focus` event.
Components do not provide selection, clipboard shortcuts, undo, submit behavior,
or automatic focus. The example preserves its existing Unicode-aware editing.

## Compatibility and limitations

The interface targets the documented Tern SDK. At module load, Checkbox checks
whether `tern.ui.el` is a function. If absent, it uses the explicit Done/Undo
workaround; other API errors are not caught or silently suppressed. This check
is not a renderer capability negotiation. If a runtime exposes `el` but cannot
render its documented checkbox nodes, that runtime remains unsupported.

Verified against the installed daemon/window combination using the Tern 0.4.5
CLI: the host VM lacks `tern.ui.el`, so native Checkbox rendering and native
`change` delivery could not be exercised. The compatible task rows, text entry,
action events, deletion, and persistence after a plugin reload were exercised
in Tern. The native path follows the SDK documentation, but remains unverified
in a runtime exposing that API. Regenerate plugin type definitions when updating
Tern; definitions alone do not prove the runtime supports an API.

| Component | Installed runtime behavior | Documented functionality not exercised |
| --- | --- | --- |
| ActionButton | Native clickable badge | None; it deliberately does not use HTML buttons |
| Checkbox | Done/Undo action plus label | Native checkbox appearance, local flip, `change` event |
| TextInput | Native single-line field; app handles keys | No additional editing features are promised |
| TaskRow | Compatible Checkbox plus Delete | Native checkbox interaction |
| EmptyState | Muted text | None |

Only plugin blocks are supported initially. Canvases reject text input nodes;
lens checkbox controls do not have block-style interaction. Do not treat this
library as a canvas or lens adapter.

## Check the consumer

From the SDK root:

```sh
luau-lsp analyze --platform=standard --definitions=@tern=tern.d.luau \
  tern-ui/init.luau examples/todo/host.luau
```

Sources: [HTML elements](https://docs.stencil.so/tern/elements/el.html),
[Inputs](https://docs.stencil.so/tern/elements/input.html), and
[Package imports](https://docs.stencil.so/tern/concepts/packages.html).
