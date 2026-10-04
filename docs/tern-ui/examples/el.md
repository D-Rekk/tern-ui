# Tern `el`: practical layout examples

This is an internal reference for composing basic HTML-like view nodes in `tern-ui`. It summarizes the published Tern API; it is not a runtime compatibility promise. The official docs are live and unversioned (consulted 2026-10-04). Separately, the [library compatibility note](../../../tern-ui/README.md#compatibility-and-limitations) records that the installed Tern 0.4.5 host VM lacked `tern.ui.el`. Do not infer local availability from these docs; this page does not claim runtime verification.

Use a built-in kind (`list`, `table`, `kv`, `input`, etc.) when it already supplies the behavior you need. Use `el` for a small custom structure or layout that benefits from HTML semantics and your own CSS.

## Build an element

```luau
local ui = tern.ui

local viaBuilder = ui.el("section", { class = "build-summary", aria = "Build status" }, {
    ui.el("h3", { text = "Preview" }),
    ui.node("el", { tag = "div", class = "build-summary__row" }, {
        ui.el("span", { text = "API" }),
        ui.el("strong", { text = "passed" }),
    }),
})
```

`ui.el(tag, props?, children?)` and `ui.node("el", { tag = ..., ... }, children)` make the same kind of node. The generic form keeps `tag` in its props table. A node is `{ k, p?, c? }`; children are nodes drawn in order. `text` is one plain text node before the children—not HTML markup. Nest elements or put a `ui.text(...)` child where styled text runs are needed. `input` and `hr` ignore `text` and children.

### Tags and props

Tern accepts this fixed tag set; any other tag is drawn as a `div` and reported as an unknown tag:

- Flow and text: `div`, `span`, `p`, `section`, `header`, `footer`, `nav`, `aside`, `main`, `article`, `figure`, `blockquote`, `ul`, `ol`, `li`, `dl`, `dt`, `dd`, `h1`–`h4`, `pre`, `code`, `kbd`, `strong`, `b`, `em`, `i`, `del`, `mark`, `hr`.
- Tables: `table`, `thead`, `tbody`, `tr`, `th`, `td`.
- Controls and grouping: `label`, `button`, `form`, `input`.

`form` is rendered as a `div` that groups controls and supplies form `values`; `input` is rendered only as a checkbox or radio control when `type` is `"checkbox"` or `"radio"`. An unsupported tag or input type is not a browser element fallback you should rely on.

Element props:

| Props | Meaning |
| --- | --- |
| `tag`, `class`, `text` | Tag name (defaults to `div`), space-separated CSS classes, and plain text before child nodes. Tern adds `sf sf-el`; `sf` and `sf-*` class names are reserved. |
| `attrs` | Extra allowlisted attributes only: `data-*`, `aria-*`, `role`, `aria-labelledby`, `colspan`, `rowspan`. Values must be strings, numbers or booleans. |
| `type`, `name`, `value`, `checked`, `disabled` | `input` controls only. |
| Common node props | `key`, `role`, `tone`, `mark`, `href`, `title`, `aria`, `hidden`, `actions`, `grow`, `shrink`, `basis`, `min`, `max`. |

Important distinctions: common `role` becomes `data-role` for CSS; use `attrs.role` for the actual ARIA role. Common `aria` sets `aria-label`; use `attrs` for other allowed `aria-*` names. Tern owns attributes such as `data-id`, `data-role`, `aria-label`, and `aria-checked`. `attrs` does not set arbitrary HTML such as `id`, `style`, `onclick`, `href`, `src`, or `type`; use the dedicated props where one exists. `href` is Tern's common link behavior (`data-href`, opened with the documented gesture), not an HTML anchor attribute. There is no `a`, `img`, `textarea`, or `select` tag in `el`.

Give repeated or interactive siblings stable, unique `key`s. On `el`, `actions` can make any element a click, double-click, or menu target; a `button` has native button semantics but does nothing until given an action.

## Layout and a small CSS recipe

An `el` gets the tag's small user-agent default set, the region font, and Tern's default label/control look; other presentation comes from CSS. For example, `div` is block, `span` is inline, while headings and paragraphs retain their documented default margins. This is not a full browser DOM/CSS environment.

The block's `main` region is itself a flex column with a 16px gap; `ui.col` and `ui.row` are the SDK's vertical and horizontal layouts and their builders default to the `sm` gap. Top-level `el` nodes are flex items in the region, so inline tags can stretch and margins do not collapse as they would in normal block flow. Put a custom group inside a `div` (or use `UI.Flex` below) when it needs its own layout context.

```luau
local summary = ui.el("section", { class = "build-summary", aria = "Build status" }, {
    ui.el("header", { class = "build-summary__head" }, {
        ui.el("h3", { text = "Preview" }),
        ui.el("span", { text = "passed" }),
    }),
    ui.el("p", { class = "build-summary__hint", text = "Ready to ship." }),
})

-- In a block view, keep the component below a region container:
return { main = ui.col({ summary }) }
```

```css
/* Plugin sheets are global: always scope block-specific rules. */
.sf-main[data-surface='plugin.build.status'] .build-summary {
    display: flex;
    flex-direction: column;
    gap: 8px;
}

.sf-main[data-surface='plugin.build.status'] .build-summary__head {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: 6px;
}

.sf-main[data-surface='plugin.build.status'] .build-summary h3,
.sf-main[data-surface='plugin.build.status'] .build-summary__hint {
    margin: 0;
}
```

Plugin `styles` are loaded as a global window stylesheet from paths relative to the plugin package. Vendor the CSS beside the library module and list that packaged path, for example:

```toml
styles = ["vendor/tern-ui/tern-ui.css"]
```

Use the `tern-ui-*` namespace for reusable library selectors. Scope consumer-specific rules to the block region's `[data-surface='plugin.<plugin>.<block>']` (or a role under the plugin id); a bare class selector can affect matching elements elsewhere in the window. A block region root is not drawn as a node: `main = someNode` draws that node's children in the region. Wrap components in a node/container when their root element is needed. A lens view, unlike a block region, draws its returned node as-is.

## `UI.Flex` contract

`UI.Flex` is a `tern-ui` component contract, not a Tern SDK builder:

```luau
type FlexProps = {
    children: { Node },
    direction: ("row" | "column")?,
    gap: ("none" | "xs" | "sm" | "md" | "lg")?,
    wrap: boolean?,
    class: string?,
    key: string?,
}
-- UI.Flex(props: FlexProps): Node
```

Defaults: `direction = "row"`, `gap = "sm"`, `wrap = false`. The native `el` path uses a `div` with the `tern-ui-flex` class, deterministic direction/gap/wrap modifier classes, and the provided child nodes. `class` adds consumer styling; `key` is the node identity. Apply additional styles to that class rather than depending on private modifier spellings:

```luau
local ui = tern.ui
local UI = require("./vendor/tern-ui")

local toolbar = UI.Flex({
    key = "toolbar",
    class = "todo-toolbar",
    direction = "row",
    gap = "sm",
    children = {
        ui.el("strong", { text = "Tasks" }),
        ui.el("button", { text = "Add", actions = { click = "add" } }),
    },
})
return { main = ui.col({ toolbar }) }
```

```css
.sf-main[data-surface='plugin.todo.list'] .todo-toolbar {
    align-items: center;
    justify-content: space-between;
}
```

If `tern.ui.el` is unavailable, `Flex` falls back to `ui.node("row"/"col", { gap = ... }, children)` so direction and supported gap remain. That fallback cannot provide wrapping or CSS classes: `wrap` and custom `class` require native `el`. This compatibility path is distinct from the documented native path.

## Accessibility, events, and text entry

- Choose semantic tags and give unnamed regions/controls accessible names with `aria`. A `label` names its enclosed checkbox/radio automatically unless the control has its own `aria`. Other ARIA attributes (for example, `aria-describedby`) go through `attrs`.
- Checkbox and radio `input`s are pointer-only: they do not take focus or handle keys. A click flips local control state before Tern sends `change`; mirror `ev.checked` (or the form's `ev.values`) into app state and render it back as `checked` rather than toggling a second time. Handle keyboard selection in the block's `key` handler and set `checked` yourself. Use stable keys for stateful controls.
- An `actions` event identifies the action name; inside a `form`, events also carry the enabled named controls' current `values`. `form` is a grouping construct, not a native browser submission flow. Lens controls do not flip; use actions for lens interaction.
- `el("input", { type = "text" })` is **not** a text field. It is unsupported and draws as an empty fallback with an unknown-tag report. Tern has no native text input through `el`; use the SDK `ui.node("input", ...)` or `ui.node("editor", ...)` kinds instead. In plugin blocks those are app-owned text/caret views: the app handles key input, cursor/text updates, and focus; offsets are UTF-16 code units.

## Official references

- [HTML Elements (`el`): tags, props, controls, accessibility, and recipes](https://docs.stencil.so/tern/elements/el.md)
- [UI Builders: `el`, `node`, row/column defaults and node props](https://docs.stencil.so/tern/reference/ui.md)
- [Building Views: block/lens roots, events and styles](https://docs.stencil.so/tern/guides/views.md)
- [Styling Views: plugin stylesheet scope and DOM hooks](https://docs.stencil.so/tern/styles/index.md)
- [Supported CSS: layout properties and CSS subset](https://docs.stencil.so/tern/styles/css.md)
- [Plugin Manifest: `styles` paths and loading](https://docs.stencil.so/tern/reference/manifest.md#styles)
- [Inputs: SDK text `input` and `editor` kinds](https://docs.stencil.so/tern/elements/input.md)
