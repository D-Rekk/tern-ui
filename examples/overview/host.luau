--!strict
local ui = tern.ui
local UI = require("./vendor/tern-ui")

type State = {
	buttonStatus: string,
	checked: boolean,
	direction: "row" | "column",
	taskCompleted: boolean,
	taskPresent: boolean,
	draft: string,
	cursor: number,
	inputFocused: boolean,
}

local function utf16(text: string): number
	local units = 0
	for _, code in utf8.codes(text) do
		units += if code > 0xFFFF then 2 else 1
	end
	return units
end

local function focus(cx: BlockCx)
	cx:frame({ { "focus", "main.draft" } })
end

local function insert(state: State, text: string)
	state.draft = string.sub(state.draft, 1, state.cursor) .. text .. string.sub(state.draft, state.cursor + 1)
	state.cursor += #text
end

local function removeBefore(state: State)
	if state.cursor > 0 then
		local start = utf8.offset(state.draft, -1, state.cursor + 1) :: number
		state.draft = string.sub(state.draft, 1, start - 1) .. string.sub(state.draft, state.cursor + 1)
		state.cursor = start - 1
	end
end

local function removeAfter(state: State)
	if state.cursor < #state.draft then
		local after = utf8.offset(state.draft, 2, state.cursor + 1) or (#state.draft + 1)
		state.draft = string.sub(state.draft, 1, state.cursor) .. string.sub(state.draft, after)
	end
end

local function view(state: State)
	local toggle = UI.Checkbox({
		key = "checkbox", label = "Transient sample option", checked = state.checked,
		name = "overview", value = "checkbox", action = "checkbox",
	})
	local task: Node
	if state.taskPresent then
		task = UI.TaskRow({
			key = "task", label = "Review the component gallery", completed = state.taskCompleted,
			name = "overview-task", value = "sample",
			toggleAction = "task-toggle", deleteAction = "task-delete",
		})
	else
		task = UI.Flex({
			key = "restore-row", direction = "row", gap = "sm",
			children = {
				UI.EmptyState({ key = "deleted-message", message = "Sample row deleted." }),
				UI.ActionButton({ key = "restore", label = "Restore sample", action = "task-restore", tone = "accent" }),
			},
		})
	end
	local inputCursor = utf16(string.sub(state.draft, 1, state.cursor))
	local flexDirection = state.direction
	return {
		main = ui.col({
			ui.text({ ui.span("tern-ui component gallery", "strong"), ui.span(" · all examples live together", "muted") }),
			ui.col({
				ui.text({ ui.span("ActionButton", "strong"), ui.span(" — a native badge action with app-owned feedback.", "muted") }),
				UI.Flex({ key = "action-demo", direction = "row", children = {
					UI.ActionButton({ key = "click", label = "Click me", action = "button-click" }),
					ui.text({ ui.span(state.buttonStatus, "muted") }),
				} }),
			}),
			ui.col({
				ui.text({ ui.span("Flex", "strong"), ui.span(" — CSS-backed layout with a selectable direction.", "muted") }),
				UI.Flex({ key = "flex-demo", direction = flexDirection, gap = "sm", children = {
					UI.ActionButton({ key = "switch", label = "Switch to " .. (if flexDirection == "row" then "column" else "row"), action = "flex-switch" }),
					ui.text({ ui.span("First item") }),
					ui.text({ ui.span("Second item") }),
				} }),
			}),
			ui.col({
				ui.text({ ui.span("Checkbox", "strong"), ui.span(" — native change mirrors checked; fallback action toggles current state.", "muted") }),
				toggle,
			}),
			ui.col({
				ui.text({ ui.span("TextInput", "strong"), ui.span(" — transient Unicode-aware editing; no storage.", "muted") }),
				UI.TextInput({ key = "draft", text = state.draft, cursor = inputCursor, placeholder = "Type Unicode here…", aria = "Overview text input" }),
				ui.text({ ui.span("Left/Right · Home/End · Backspace/Delete · Escape clears", "muted") }),
			}),
			ui.col({
				ui.text({ ui.span("TaskRow", "strong"), ui.span(" — complete/reopen or delete, then restore the sample.", "muted") }),
				task,
			}),
			ui.col({
				ui.text({ ui.span("EmptyState", "strong"), ui.span(" — representative muted empty-state text.", "muted") }),
				UI.EmptyState({ key = "empty-example", message = "Nothing here yet. This is an EmptyState." }),
			}),
		}),
	}
end
local def: BlockDef<State> = {
	init = function(_cx, _args, _saved)
		return { buttonStatus = "Ready to click.", checked = false, direction = "row", taskCompleted = false, taskPresent = true, draft = "", cursor = 0, inputFocused = true }
	end,
	title = function(_state)
		return "Overview"
	end,
	view = function(state, _cx)
		return view(state)
	end,
	key = function(state, key, cx)
		if not state.inputFocused then
			return false
		end
		if key.name == "left" and state.cursor > 0 then
			state.cursor = (utf8.offset(state.draft, -1, state.cursor + 1) :: number) - 1
		elseif key.name == "right" and state.cursor < #state.draft then
			state.cursor = (utf8.offset(state.draft, 2, state.cursor + 1) or (#state.draft + 1)) - 1
		elseif key.name == "home" then
			state.cursor = 0
		elseif key.name == "end" then
			state.cursor = #state.draft
		elseif key.name == "backspace" then
			removeBefore(state)
		elseif key.name == "delete" then
			removeAfter(state)
		elseif key.name == "escape" then
			state.draft, state.cursor = "", 0
		elseif key.text and not (key.ctrl or key.meta) then
			insert(state, string.gsub(key.text, "[%c]", " "))
		else
			return false
		end
		focus(cx)
		return true
	end,
	event = function(state, ev, cx)
		if ev.ev == "focus" then
			state.inputFocused = true
			focus(cx)
		elseif ev.ev == "blur" then
			state.inputFocused = false
		elseif ev.ev == "change" and ev.name == "overview-task" and ev.value == "sample" and state.taskPresent then
			state.taskCompleted = ev.checked == true
		elseif ev.ev == "change" and ev.name == "overview" and ev.value == "checkbox" then
			state.checked = ev.checked == true
		elseif ev.ev == "action" then
			if ev.act == "button-click" then
				state.buttonStatus = "ActionButton clicked."
			elseif ev.act == "checkbox" then
				state.checked = not state.checked
			elseif ev.act == "flex-switch" then
				state.direction = if state.direction == "row" then "column" else "row"
			elseif ev.act == "task-toggle" and state.taskPresent then
				state.taskCompleted = not state.taskCompleted
			elseif ev.act == "task-delete" then
				state.taskPresent = false
			elseif ev.act == "task-restore" then
				state.taskPresent, state.taskCompleted = true, false
			end
		end
	end,
}
tern.block.define("overview", def)
