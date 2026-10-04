--!strict
-- Rendering only: consumers own state, events, keyboard editing, and storage.
local ui = tern.ui
local nativeElement = type(ui.el) == "function"

export type ActionButtonProps = {
	label: string,
	action: string,
	key: string?,
	tone: string?,
	aria: string?,
}

export type CheckboxProps = {
	label: string,
	checked: boolean,
	name: string,
	value: string,
	action: string,
	key: string?,
	aria: string?,
}

export type TextInputProps = {
	text: string,
	-- Renderer offsets are UTF-16 code units, not Luau bytes.
	cursor: number,
	key: string,
	placeholder: string?,
	aria: string?,
}

export type TaskRowProps = {
	key: string,
	label: string,
	completed: boolean,
	-- Native checkboxes emit change(name, value, checked).
	name: string,
	value: string,
	-- Compatible checkboxes emit this action instead.
	toggleAction: string,
	deleteAction: string,
}

export type EmptyStateProps = {
	message: string,
	key: string?,
}

export type FlexProps = {
	children: { Node },
	direction: ("row" | "column")?,
	gap: ("none" | "xs" | "sm" | "md" | "lg")?,
	wrap: boolean?,
	class: string?,
	key: string?,
}

local UI = {}

function UI.Flex(props: FlexProps): Node
	local direction = props.direction or "row"
	local gap = props.gap or "sm"
	if nativeElement then
		local classes = {
			"tern-ui-flex",
			"tern-ui-flex--" .. direction,
			"tern-ui-flex--gap-" .. gap,
			"tern-ui-flex--" .. (if props.wrap then "wrap" else "nowrap"),
		}
		if props.class and props.class ~= "" then
			table.insert(classes, props.class)
		end
		return ui.el("div", {
			key = props.key,
			class = table.concat(classes, " "),
		}, props.children)
	end
	-- Built-in layouts preserve direction and gap without el. CSS classes and
	-- wrapping have no equivalent on row/col nodes.
	return ui.node(if direction == "column" then "col" else "row", {
		key = props.key,
		gap = gap,
	}, props.children)
end

function UI.ActionButton(props: ActionButtonProps): Node
	-- Badge actions are documented native controls and need no stylesheet.
	return ui.node("badge", {
		key = props.key,
		text = props.label,
		tone = props.tone or "accent",
		aria = props.aria or props.label,
		actions = { click = props.action },
	})
end

function UI.Checkbox(props: CheckboxProps): Node
	local label = ui.text({ ui.span(props.label, if props.checked then "muted del" else "") })
	if nativeElement then
		return ui.el("label", { key = props.key }, {
			ui.el("input", {
				key = "control", type = "checkbox", name = props.name, value = props.value,
				checked = props.checked, aria = props.aria or props.label,
			}),
			label,
		})
	end
	-- Missing tern.ui.el: preserve the operation, not checkbox appearance or
	-- change-event semantics. Consumers handle this action explicitly.
	return ui.node("row", { key = props.key }, {
		UI.ActionButton({
			key = "control", label = if props.checked then "Undo" else "Done",
			action = props.action,
			aria = (if props.checked then "Reopen " else "Complete ") .. (props.aria or props.label),
		}),
		label,
	})
end

function UI.TextInput(props: TextInputProps): Node
	return ui.node("input", {
		key = props.key, text = props.text, cursor = props.cursor,
		placeholder = props.placeholder, aria = props.aria or "Text input",
	})
end

function UI.TaskRow(props: TaskRowProps): Node
	local checkbox = UI.Checkbox({
		key = "task", label = props.label, checked = props.completed,
		name = props.name, value = props.value, action = props.toggleAction,
	})
	local checkboxProps: { [string]: any } = checkbox.p or {}
	checkboxProps.grow = 1
	checkbox.p = checkboxProps
	return ui.node("row", {
		key = props.key,
		mark = if props.completed then "done" else nil,
	}, {
		checkbox,
		UI.ActionButton({
			key = "delete", label = "Delete", action = props.deleteAction,
			aria = "Delete " .. props.label,
		}),
	})
end

function UI.EmptyState(props: EmptyStateProps): Node
	local node = ui.text({ ui.span(props.message, "muted") })
	local nodeProps: { [string]: any } = node.p or {}
	nodeProps.key = props.key
	node.p = nodeProps
	return node
end

return UI
