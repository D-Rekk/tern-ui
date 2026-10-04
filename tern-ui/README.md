# tern-ui

Rendering-only Luau components for Tern plugin blocks. Components return SDK
`Node` values; the application owns state, event handling, keyboard editing,
focus, and persistence. There is no package manager or runtime dependency
beyond Tern. `Flex` also has a CSS file that consuming plugins must load.

## Install the example directly

From the SDK root:

```sh
tern plugin install ./examples/todo
```

The checked-in example already contains the library module and stylesheet.
There is no shell packaging step for users; `--force` updates an existing
installed copy. Installation copies the complete plugin directory into Tern's
plugins folder.

## Consume or maintain the library

Dependency modules must exist inside each consuming plugin. Import its
plugin-local copy:

```luau
local UI = require("./vendor/tern-ui")
```

`tern-ui/init.luau` and `tern-ui/tern-ui.css` are the canonical sources;
plugin installation is not a dependency resolver and does not discover this
sibling directory. For another plugin, include them as
`vendor/tern-ui/init.luau` and `vendor/tern-ui/tern-ui.css`, then load the
stylesheet from that plugin's manifest:

```toml
styles = ["vendor/tern-ui/tern-ui.css"]
```

Maintainers can refresh a consumer with `sh tern-ui/vendor.sh PLUGIN_DIR`.
The helper copies both canonical files, requires a destination `plugin.toml`,
and preserves unrelated vendor files. Run it after changing canonical source
and commit the consumer copies; edit the canonical files rather than generated
copies. The helper can be invoked by absolute path from outside the SDK root.

## Components

All constructors take one named props table and return one `Node`. Type aliases
are exported from the module (for example, `UI.CheckboxProps`).

| Constructor | Required props | Optional props |
| --- | --- | --- |
| `ActionButton` | `label: string`, `action: string` | `key`, `tone`, `aria` |
| `Flex` | `children: { Node }` | `direction: "row" \| "column"`, `gap: "none" \| "xs" \| "sm" \| "md" \| "lg"`, `wrap: boolean`, `class: string`, `key: string` |
| `Checkbox` | `label: string`, `checked: boolean`, `name: string`, `value: string`, `action: string` | `key`, `aria` |
| `TextInput` | `text: string`, `cursor: number`, `key: string` | `placeholder`, `aria` |
| `TaskRow` | `key: string`, `label: string`, `completed: boolean`, `name: string`, `value: string`, `toggleAction: string`, `deleteAction: string` | none |
| `EmptyState` | `message: string` | `key` |

`Flex` has the exported type `UI.FlexProps` and the signature
`UI.Flex(props: UI.FlexProps): Node`. It defaults to `direction = "row"`,
`gap = "sm"`, and `wrap = false`. `TextInput.cursor` is a UTF-16 code-unit
offset, not a Luau byte offset.

Supply stable keys for repeated or interactive nodes. Tern requires keys to
be unique among siblings. Do not use positions as task keys when rows can be
deleted or reordered.

```luau
local ui = tern.ui
local UI = require("./vendor/tern-ui")

type State = { done: boolean, draft: string, cursor16: number }

local function view(state: State)
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
            UI.Flex({
                children = {
                    UI.ActionButton({ label = "Add task", action = "add" }),
                    ui.text("Enter to add"),
                },
            }),
        }),
    }
end
```

Wrap components in `tern.ui.col` or another region container. Tern renders a
region root's children, not the root itself.

When `tern.ui.el` is available, `Flex` creates a `div` with these deterministic
classes:

- `tern-ui-flex`
- `tern-ui-flex--row` or `tern-ui-flex--column`
- `tern-ui-flex--gap-none`, `--gap-xs`, `--gap-sm`, `--gap-md`, or `--gap-lg`
  (each with the full `tern-ui-flex` prefix)
- `tern-ui-flex--wrap` or `tern-ui-flex--nowrap`
- the caller's `class`, when supplied

The stylesheet scopes its rules to plugin surfaces and targets only the
`tern-ui-flex*` classes. Its gap scale is `0`, `2px`, `6px`, `10px`, and `16px`,
respectively. If `tern.ui.el` is unavailable, `Flex` returns `ui.node("row")`
or `ui.node("col")` with the selected supported `gap` and `key`. Built-in
row/column nodes cannot apply an HTML class or CSS wrapping, so `wrap` and
`class` require the native `el` path and are ignored by the fallback.

For raw HTML-like nodes, scoped CSS recipes, and control limitations, see
[Tern `el` examples](../docs/tern-ui/examples/el.md).

`ActionButton` is a native badge with a click action, not a native HTML button.
`Checkbox` displays a label and a checked control when `tern.ui.el` is
available; its compatible rendering displays Done/Undo and the same label
instead. `TaskRow` combines Checkbox and a Delete action. Its label remains
struck through when complete; completed rows carry the stable `mark="done"`
prop so consumers can dim the whole row with a scoped `[data-mark="done"]`
rule. `EmptyState` displays muted explanatory text.

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

The interface targets the documented Tern SDK. At module load, Checkbox and
Flex check whether `tern.ui.el` is a function. If absent, Checkbox uses the
explicit Done/Undo workaround and Flex uses a built-in row/column; other API
errors are not caught or silently suppressed. This check is not a renderer
capability negotiation. If a runtime exposes `el` but cannot render its
documented nodes, that runtime remains unsupported.

An earlier exercise against the already-running daemon found `tern.ui.el`
absent. For this change, a fresh isolated daemon launched from `tern 0.4.5
(1d14241)` exposed it: the todo plugin loaded its stylesheet (10 rules), and
`Flex` rendered a native `div` row with the expected classes and a measured
6px child gap. The existing daemon was left untouched, so it may still use
the no-`el` fallback. This smoke did not exercise Checkbox's native change
event, Flex's nondefault options, or Flex's fallback. Regenerate plugin type
definitions when updating Tern; definitions alone do not prove runtime support.

| Component | Verified behavior | Not exercised in this change |
| --- | --- | --- |
| ActionButton | Native badge renders; action flow was exercised earlier | None; it deliberately does not use HTML buttons |
| Checkbox | Done/Undo compatibility path was exercised earlier | Native checkbox appearance, local flip, `change` event |
| Flex | Native row, CSS classes, and 6px gap rendered in an isolated daemon | Column, wrapping, custom classes, no-`el` fallback |
| TextInput | Unicode editing and persistence were exercised earlier | No additional editing features are promised |
| TaskRow | Compatible checkbox plus Delete were exercised earlier | Native checkbox interaction |
| EmptyState | Muted text rendered | None |

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
[UI builders](https://docs.stencil.so/tern/reference/ui.html),
[Styling views](https://docs.stencil.so/tern/styles/index.html),
[Inputs](https://docs.stencil.so/tern/elements/input.html), and
[Package imports](https://docs.stencil.so/tern/concepts/packages.html).
