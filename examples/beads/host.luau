--!strict
local Model = require("./model")
local View = require("./view")
type State = View.State
type Problem = View.Problem
local TIMEOUT_MS = 30000
local running: { [number]: State } = {}

local function retire(state: State)
	if running[state.cx.pane] == state then running[state.cx.pane] = nil end
	state.request += 1
	state.loading = false
	state.issues, state.lanes = nil, {}
end
local function alive(state: State): boolean
	if running[state.cx.pane] ~= state then return false end
	for _, pane in tern.pane.list() do
		if pane.pane == state.cx.pane then return true end
	end
	retire(state)
	return false
end
local function diagnostic(text: string): string
	-- Bound diagnostic rendering, not the successfully loaded issue content.
	return string.sub(text, 1, 2000)
end
local function failure(result: ProcessResult): Problem
	if result.timed_out then
		return { title = "Beads request timed out", text = "bd did not finish within 30 seconds. Check the project's database and refresh to try again." }
	end
	local err = if result.stderr ~= "" then result.stderr else result.stdout
	local lower = string.lower(err)
	if string.find(lower, "no beads", 1, true) or string.find(lower, "not initialized", 1, true)
		or string.find(lower, "no database", 1, true) or string.find(lower, "database not found", 1, true) then
		return {
			title = "No Beads database found",
			text = "Open the board from a Beads project directory. If this is a new project, initialize it yourself with bd init in a shell, then refresh. The viewer never initializes databases.",
			detail = diagnostic(err),
		}
	end
	return {
		title = "Could not read Beads issues",
		text = "bd exited with status " .. result.status .. ". Check bd list --all --limit 0 --json --readonly in this project on the pane host, then refresh.",
		detail = diagnostic(err),
	}
end
local function reconcile(state: State)
	local active = state.lanes[1]
	for _, lane in state.lanes do if lane.status == state.lane then active = lane end end
	state.lane = active.status
	local cursor = Model.find(state.issues, state.cursor)
	if not cursor or cursor.status ~= state.lane then
		state.cursor = if active.issues[1] then active.issues[1].id else nil
	end
end
local function candidates(state: State): { string }
	if state.executable then return { state.executable } end
	local paths = { "bd" }
	local home = tern.getenv("HOME")
	if home and home ~= "" then table.insert(paths, home .. "/.local/bin/bd") end
	table.insert(paths, "/opt/homebrew/bin/bd")
	table.insert(paths, "/usr/local/bin/bd")
	return paths
end
local function refresh(state: State)
	if not alive(state) or state.loading then return end
	if state.project == "" then
		state.problem = {
			title = "Choose a project directory",
			text = "Open Beads board from a shell whose current directory is known, or launch beads.board with an explicit absolute project directory argument.",
		}
		return
	end
	state.loading = true
	state.request += 1
	local request = state.request
	local last_error = "bd is not installed on the pane host."
	for _, executable in candidates(state) do
		local ok, err = pcall(function()
			tern.process.run({ executable, "list", "--all", "--limit", "0", "--json", "--readonly" }, {
				cwd = state.project, timeout_ms = TIMEOUT_MS,
				env = { NO_COLOR = "1", BEADS_DIR = "", BEADS_DB = "", BD_DB = "", BEADS_MAX_ROWS = "" },
			}, function(result: ProcessResult, _)
				if not alive(state) or state.request ~= request then return end
				state.loading = false
				if result.status ~= 0 or result.timed_out then
					state.problem = failure(result)
				else
					local issues, problem = Model.parse(result.stdout)
					if issues then
						state.issues = issues
						state.lanes = Model.lanes(issues)
						state.problem, state.fetched = nil, os.time()
						reconcile(state)
					else
						state.problem = {
							title = "Unexpected Beads JSON",
							text = (problem or "Cannot read the issue list.") .. " Check your bd version, then refresh.",
							detail = diagnostic(result.stdout),
						}
					end
				end
				state.cx:render()
			end)
		end)
		if ok then return end
		last_error = tostring(err)
	end
	state.loading = false
	state.problem = {
		title = "Could not start the Beads CLI",
		text = "Install bd on the machine running this pane, and ensure the project directory exists. The viewer tries PATH, ~/.local/bin, /opt/homebrew/bin, and /usr/local/bin. An explicit bd executable can be supplied as the second launch argument. Refresh after fixing the problem.",
		detail = diagnostic(last_error),
	}
end
local function set_lane(state: State, status: string)
	for _, lane in state.lanes do
		if lane.status == status then state.lane = status; reconcile(state); return end
	end
end
local function move_lane(state: State, delta: number)
	for i, lane in state.lanes do
		if lane.status == state.lane then
			set_lane(state, state.lanes[math.clamp(i + delta, 1, #state.lanes)].status)
			return
		end
	end
end
local function move_card(state: State, delta: number)
	for _, lane in state.lanes do
		if lane.status == state.lane then
			local index = 0
			for i, issue in lane.issues do if issue.id == state.cursor then index = i end end
			local issue = lane.issues[math.clamp(index + delta, 1, math.max(1, #lane.issues))]
			if issue then state.cursor = issue.id end
			return
		end
	end
end
local function open_issue(state: State, id: string?)
	local issue = Model.find(state.issues, id)
	if issue then state.selected, state.cursor, state.lane = issue.id, issue.id, issue.status end
end

local function cycle_layout(state: State)
	state.mode = if state.mode == "auto" then "board" elseif state.mode == "board" then "tabs" else "auto"
end

tern.block.define("board", {
	init = function(cx: BlockCx, args: { string }, saved: any): State
		local previous = running[cx.pane]
		if previous then retire(previous) end
		local prefs = if type(saved) == "table" then saved else {}
		local project = args[1] or (if type(prefs.project) == "string" then prefs.project else cx.cwd) or ""
		local state: State = {
			cx = cx, project = project,
			executable = args[2] or (if type(prefs.executable) == "string" then prefs.executable else nil),
			issues = nil, lanes = {}, lane = if type(prefs.lane) == "string" then prefs.lane else "open",
			cursor = if type(prefs.cursor) == "string" then prefs.cursor else nil,
			selected = if type(prefs.selected) == "string" then prefs.selected else nil,
			mode = if prefs.mode == "board" or prefs.mode == "tabs" then prefs.mode else "auto",
			loading = false, fetched = nil, problem = nil, request = 0,
		}
		running[cx.pane] = state
		if #args > 2 then
			state.problem = { title = "Unexpected launch arguments", text = "Pass only an absolute project directory and an optional bd executable path." }
		else
			refresh(state)
		end
		return state
	end,
	title = function(state: State): string
		local name = string.match(state.project, "([^/\\]+)[/\\]*$") or "project"
		return "Beads · " .. name
	end,
	view = View.render,
	key = function(state: State, key: Key, _cx: BlockCx): boolean?
		if key.ctrl or key.alt or key.meta then return false end
		local k = key.text or key.name
		if k == "r" then refresh(state)
		elseif key.name == "escape" or key.name == "backspace" then state.selected = nil
		elseif k == "t" then cycle_layout(state)
		elseif state.selected then return false
		elseif key.name == "left" or k == "h" then move_lane(state, -1)
		elseif key.name == "right" or k == "l" then move_lane(state, 1)
		elseif key.name == "up" or k == "k" then move_card(state, -1)
		elseif key.name == "down" or k == "j" then move_card(state, 1)
		elseif key.name == "home" then move_card(state, -math.huge)
		elseif key.name == "end" then move_card(state, math.huge)
		elseif key.name == "enter" or k == "o" then open_issue(state, state.cursor)
		else return false end
		return true
	end,
	event = function(state: State, ev: UiEvent, cx: BlockCx)
		if ev.ev ~= "action" then return end
		if ev.act == "refresh" then refresh(state)
		elseif ev.act == "back" then state.selected = nil
		elseif ev.act == "layout" and (ev.value == "auto" or ev.value == "board" or ev.value == "tabs") then state.mode = ev.value
		elseif ev.act == "lane" and ev.value then set_lane(state, ev.value)
		elseif ev.act == "issue" then open_issue(state, ev.value)
		elseif ev.act == "Copy Bead ID" then
			local issue = Model.find(state.issues, ev.value)
			if issue then cx:copy(issue.id) end
		end
	end,
	save = function(state: State): any
		return {
			project = state.project, executable = state.executable, lane = state.lane,
			cursor = state.cursor, selected = state.selected, mode = state.mode,
		}
	end,
})
