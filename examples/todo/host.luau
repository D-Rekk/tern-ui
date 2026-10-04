--!strict
local ui = tern.ui
local UI = require("./vendor/tern-ui")

type Task = { id: number, text: string, done: boolean }
type Store = { next_id: number, tasks: { Task } }
-- Cursor is a byte offset internally; the renderer uses UTF-16 offsets.
type State = { draft: string, cursor: number }

local function load(): Store
	return tern.kv.get("tasks") or { next_id = 1, tasks = {} }
end


local function utf16(text: string): number
	local units = 0
	for _, code in utf8.codes(text) do
		units += if code > 0xFFFF then 2 else 1
	end
	return units
end

local function add(state: State)
	local text = string.match(state.draft, "^%s*(.-)%s*$") or ""
	if text == "" then
		return
	end
	local store = load()
	table.insert(store.tasks, { id = store.next_id, text = text, done = false })
	store.next_id += 1
	tern.kv.set("tasks", store)
	state.draft, state.cursor = "", 0
end

local function focus(cx: BlockCx)
	cx:frame({ { "focus", "dock.draft" } })
end

local function insert(state: State, text: string)
	-- A pasted multi-line note becomes one task, not multiple hidden lines.
	text = string.gsub(text, "[%c]", " ")
	state.draft = string.sub(state.draft, 1, state.cursor) .. text .. string.sub(state.draft, state.cursor + 1)
	state.cursor += #text
end

local def: BlockDef<State> = {
	init = function(_cx, _args, _saved)
		return { draft = "", cursor = 0 }
	end,
	title = function(_state)
		return "To-do list"
	end,

	view = function(state, _cx)
		local store = load()
		local remaining = 0
		local rows: { Node } = {}
		for _, task in store.tasks do
			if not task.done then
				remaining += 1
			end
			table.insert(rows, UI.TaskRow({
				key = tostring(task.id), label = task.text, completed = task.done,
				name = "task", value = tostring(task.id),
				toggleAction = "toggle=" .. tostring(task.id),
				deleteAction = "delete=" .. tostring(task.id),
			}))
		end
		if #rows == 0 then
			table.insert(rows, UI.EmptyState({ message = "Nothing to do. Add your first task below." }))
		end
		return {
			main = ui.col({
				ui.text({ ui.span("To-do", "strong"), ui.span(string.format("  %d remaining · %d total", remaining, #store.tasks), "muted") }),
				ui.col(rows),
			}),
			dock = ui.col({
				UI.TextInput({
					key = "draft", text = state.draft,
					cursor = utf16(string.sub(state.draft, 1, state.cursor)),
					placeholder = "What needs doing?", aria = "New task",
				}),
				UI.Flex({
					children = {
						UI.ActionButton({ label = "Add task", action = "add" }),
						ui.text({ ui.span("Enter to add · toggle completion · Delete to remove", "muted") }),
					},
				}),
			}),
		}
	end,

	key = function(state, key, cx)
		if key.name == "enter" then
			add(state)
		elseif key.name == "escape" then
			state.draft, state.cursor = "", 0
		elseif key.name == "backspace" and state.cursor > 0 then
			local start = utf8.offset(state.draft, -1, state.cursor + 1) :: number
			state.draft = string.sub(state.draft, 1, start - 1) .. string.sub(state.draft, state.cursor + 1)
			state.cursor = start - 1
		elseif key.name == "delete" and state.cursor < #state.draft then
			local after = utf8.offset(state.draft, 2, state.cursor + 1) or (#state.draft + 1)
			state.draft = string.sub(state.draft, 1, state.cursor) .. string.sub(state.draft, after)
		elseif key.name == "left" and state.cursor > 0 then
			state.cursor = (utf8.offset(state.draft, -1, state.cursor + 1) :: number) - 1
		elseif key.name == "right" and state.cursor < #state.draft then
			state.cursor = (utf8.offset(state.draft, 2, state.cursor + 1) or (#state.draft + 1)) - 1
		elseif key.name == "home" then
			state.cursor = 0
		elseif key.name == "end" then
			state.cursor = #state.draft
		elseif key.text and not (key.ctrl or key.meta) then
			insert(state, key.text)
		else
			return false
		end
		focus(cx)
		return true
	end,

	event = function(state, ev, cx)
		if ev.ev == "focus" then
			focus(cx)
		elseif ev.ev == "action" and ev.act == "add" then
			add(state)
			focus(cx)
		elseif (ev.ev == "change" and ev.name == "task")
			or (ev.ev == "action" and (ev.act == "toggle" or ev.act == "delete")) then
			local id = tonumber(ev.value)
			local store = load()
			for i, task in store.tasks do
				if task.id == id then
					if ev.ev == "change" then
						task.done = ev.checked == true
					elseif ev.act == "toggle" then
						task.done = not task.done
					else
						table.remove(store.tasks, i)
					end
					tern.kv.set("tasks", store)
					break
				end
			end
		end
	end,
}

tern.block.define("list", def)
