--!strict
-- Read-only source view with asynchronous, analyzer-backed diagnostics.

local ui = tern.ui
local ANALYZE_TIMEOUT_MS = 30 * 1000

type Diagnostic = {
	severity: "error" | "warning",
	code: string,
	message: string,
	line: number,
	col: number,
}

type State = {
	cx: BlockCx,
	path: string?,
	name: string,
	cwd: string?,
	source: string?,
	read_error: string?,
	status: string,
	detail: string?,
	diagnostics: { Diagnostic },
}

-- A pane may be restarted while a process is still running. Keep the run
-- identity so an old callback cannot replace the new block's view.
local running: { [number]: State } = {}

local function basename(path: string): string
	return string.match(path, "[^/\\]+$") or path
end

local function first_lines(text: string, limit: number): string?
	local lines: { string } = {}
	for line in string.gmatch(text, "[^\r\n]+") do
		table.insert(lines, line)
		if #lines == limit then
			table.insert(lines, "…")
			break
		end
	end
	return if #lines > 0 then table.concat(lines, "\n") else nil
end

local function parse_output(path: string, output: string): ({ Diagnostic }, string?)
	local diagnostics: { Diagnostic } = {}
	local other: { string } = {}
	for line in string.gmatch(output, "[^\r\n]+") do
		local _, line_text, col_text, kind, message = string.match(
			line,
			"^(.*)%((%d+),(%d+)%)%s*:%s*([%w_]+):%s*(.*)$"
		)
		local line_number = if line_text then tonumber(line_text) else nil
		local column = if col_text then tonumber(col_text) else nil
		if kind and message and line_number and column then
			table.insert(diagnostics, {
				severity = if kind == "TypeError" or kind == "SyntaxError" then "error" else "warning",
				code = kind,
				message = message,
				line = line_number,
				col = column,
			})
		else
			table.insert(other, line)
		end
	end
	return diagnostics, first_lines(table.concat(other, "\n"), 8)
end

local function alive(state: State): boolean
	if running[state.cx.pane] ~= state then
		return false
	end
	for _, pane in tern.pane.list() do
		if pane.pane == state.cx.pane then
			return true
		end
	end
	running[state.cx.pane] = nil
	return false
end

local function finish_analysis(state: State, result: ProcessResult)
	if not alive(state) then
		return
	end
	running[state.cx.pane] = nil

	local output = result.stderr
	if result.stdout ~= "" then
		output = if output == "" then result.stdout else output .. "\n" .. result.stdout
	end
	local path = state.path :: string
	local diagnostics, detail = parse_output(path, output)
	state.diagnostics = diagnostics
	state.detail = detail

	if result.timed_out then
		state.status = "luau-lsp analyze timed out after 30 seconds."
	elseif #diagnostics > 0 then
		state.status = tostring(#diagnostics) .. " diagnostic" .. (if #diagnostics == 1 then "" else "s") .. "."
	elseif result.status == 0 and output == "" then
		state.status = "No diagnostics."
	elseif result.status == 0 then
		state.status = "Analyzer completed, but its output could not be classified."
	else
		state.status = "luau-lsp analyze failed (exit status " .. result.status .. ")."
	end
	state.cx:render()
end

local function analyze(state: State)
	local path = state.path
	if path == nil then
		return
	end
	state.status = "Analyzing with luau-lsp…"
	running[state.cx.pane] = state
	local ok, err = pcall(function()
		tern.process.run(
			{ "luau-lsp", "analyze", "--formatter=default", "--platform=standard", path },
			{ cwd = state.cwd, timeout_ms = ANALYZE_TIMEOUT_MS },
			function(result: ProcessResult, _cx)
				finish_analysis(state, result)
			end
		)
	end)
	if not ok then
		if running[state.cx.pane] == state then
			running[state.cx.pane] = nil
		end
		local message = tostring(err)
		if string.find(message, "luau-lsp", 1, true) then
			state.status = "Could not start luau-lsp. Install it and make it available on the Tern host's PATH."
		else
			state.status = "Could not start the Luau analyzer."
		end
		state.detail = first_lines(message, 8)
	end
end

local function diagnostic_view(state: State): { Node }
	local nodes: { Node } = {}
	for _, diagnostic in state.diagnostics do
		local path = state.path
		if path then
			table.insert(nodes, ui.diagnostic({
				severity = diagnostic.severity,
				code = diagnostic.code,
				message = diagnostic.message,
				path = path,
				line = diagnostic.line,
				col = diagnostic.col,
			}, state.cwd))
		end
	end
	return nodes
end

tern.block.define("viewer", {
	init = function(cx: BlockCx, args: { string }, _saved: any): State
		local path: string? = args[1]
		local absolute = if path
			then string.match(path, "^[/\\]")
				or string.match(path, "^%a:[/\\]")
			else false
		if path and not absolute and cx.cwd then
			path = cx.cwd .. "/" .. path
		end
		local state: State = {
			cx = cx,
			path = path,
			name = if path then basename(path) else "Luau Viewer",
			cwd = cx.cwd,
			source = nil,
			read_error = nil,
			status = if path then "Reading source…" else "Open a `.luau` file with Luau Viewer.",
			detail = nil,
			diagnostics = {},
		}
		if path then
			local ok, source = pcall(tern.fs.read, path)
			if ok then
				state.source = source :: string
				analyze(state)
			else
				state.read_error = tostring(source)
				state.status = "Could not read the source file."
			end
		end
		return state
	end,

	title = function(state: State): string
		return state.name
	end,

	view = function(state: State, _cx: BlockCx): BlockView
		local children: { Node } = {
			ui.text({ ui.span(state.status, if state.read_error then "error" else "muted") }),
		}
		if state.path then
			table.insert(children, ui.text({ ui.span(state.path, "path") }))
		end
		if state.detail then
			table.insert(children, ui.code(state.detail, "text"))
		end
		if #state.diagnostics > 0 then
			table.insert(children, ui.section("Diagnostics", diagnostic_view(state)))
		end
		if state.read_error then
			table.insert(children, ui.text({ ui.span(state.read_error, "error") }))
		elseif state.source then
			local source = ui.code(state.source, "lua", 1)
			if source.p then
				source.p.path = state.path
			end
			table.insert(children, source)
		end
		return { main = ui.col(children) }
	end,
})
