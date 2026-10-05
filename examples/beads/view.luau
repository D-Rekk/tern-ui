--!strict
local Model = require("./model")
type Issue = Model.Issue
type Lane = Model.Lane
export type Problem = { title: string, text: string, detail: string? }
export type State = {
	cx: BlockCx, project: string, executable: string?, issues: { Issue }?, lanes: { Lane },
	lane: string, cursor: string?, selected: string?, mode: string,
	loading: boolean, fetched: number?, problem: Problem?, request: number,
}
local ui = tern.ui
local View = {}

local function el(tag: string, class: string, props: { [string]: any }?, children: { Node }?): Node
	local p = props or {}
	p.tag, p.class = tag, class
	return ui.node("el", p, children)
end
local function label(text: string, class: string): Node
	return el("span", class, { text = text }, nil)
end
local function button(text: string, action: string, key: string, active: boolean?): Node
	return el("button", "beads-button" .. (if active then " beads-button-active" else ""), {
		key = key, text = text, actions = { click = action }, aria = text,
	}, nil)
end
local function message(title: string, text: string): Node
	return el("section", "beads-message", nil, {
		el("h3", "beads-message-title", { text = title }, nil),
		el("p", "beads-muted", { text = text }, nil),
	})
end
local function issue_card(issue: Issue, lane: Lane, cursor: string?): Node
	local meta: { Node } = {
		label(if issue.priority then "P" .. issue.priority else "P?", "beads-priority" .. (if issue.priority == 0 then " beads-critical" else "")),
		label(if issue.kind ~= "" then issue.kind else "issue", "beads-kind"),
	}
	if issue.assignee ~= "" then table.insert(meta, label("@" .. issue.assignee, "beads-assignee")) end
	local kids: { Node } = {
		label(issue.id, "beads-id"),
		el("h3", "beads-card-title", { text = issue.title }, nil),
		el("div", "beads-meta", nil, meta),
	}
	if #issue.labels > 0 then
		local labels: { Node } = {}
		for i, name in issue.labels do
			table.insert(labels, el("span", "beads-label", { key = tostring(i), text = name }, nil))
		end
		table.insert(kids, el("div", "beads-labels", nil, labels))
	end
	return el("article", "beads-card beads-tone-" .. lane.tone .. (if cursor == issue.id then " beads-card-focused" else ""), {
		key = issue.id, actions = { click = "issue=" .. issue.id },
		aria = issue.id .. ": " .. issue.title .. ". Open issue details.", attrs = { role = "button" },
	}, kids)
end
local function lane_view(lane: Lane, cursor: string?, tabs: boolean): Node
	local cards: { Node } = {}
	for _, issue in lane.issues do table.insert(cards, issue_card(issue, lane, cursor)) end
	if #cards == 0 then table.insert(cards, message("No issues", "This lane is clear.")) end
	return el("section", "beads-lane beads-tone-" .. lane.tone .. (if tabs then " beads-lane-tab" else ""), {
		key = lane.status, aria = lane.title .. " issues",
	}, {
		el("header", "beads-lane-head", nil, {
			el("div", "beads-lane-name", nil, { label("●", "beads-dot"), label(lane.title, "beads-lane-title") }),
			label(tostring(#lane.issues), "beads-count"),
		}),
		el("div", "beads-cards", nil, cards),
	})
end
local function detail(issue: Issue, lanes: { Lane }): Node
	local tone = "custom"
	for _, lane in lanes do if lane.status == issue.status then tone = lane.tone end end
	local priority_names = { [0] = "Critical", [1] = "High", [2] = "Medium", [3] = "Low", [4] = "Backlog" }
	local metadata: { { Spans } } = {
		{ "Status", issue.status },
		{ "Priority", if issue.priority then "P" .. issue.priority .. " · " .. (priority_names[issue.priority] or "Custom") else "Not set" },
		{ "Type", if issue.kind ~= "" then issue.kind else "Not set" },
		{ "Assignee", if issue.assignee ~= "" then issue.assignee else "Unassigned" },
	}
	if #issue.labels > 0 then table.insert(metadata, { "Labels", table.concat(issue.labels, ", ") }) end
	if issue.created ~= "" then table.insert(metadata, { "Created", issue.created }) end
	if issue.updated ~= "" then table.insert(metadata, { "Updated", issue.updated }) end
	if issue.closed ~= "" then table.insert(metadata, { "Closed", issue.closed }) end
	local kids: { Node } = {
		el("header", "beads-detail-head", nil, {
			label(issue.id, "beads-id"),
			el("h2", "beads-detail-title", { text = issue.title }, nil),
		}),
		ui.kv(metadata),
	}
	local sections = {
		{ "Description", issue.description }, { "Design", issue.design },
		{ "Acceptance criteria", issue.acceptance }, { "Notes", issue.notes },
	}
	local has_text = false
	for _, section in sections do
		if section[2] ~= "" then
			has_text = true
			table.insert(kids, el("section", "beads-detail-section", { key = section[1] }, {
				el("h3", "beads-section-title", { text = section[1] }, nil), ui.md(section[2]),
			}))
		end
	end
	if not has_text then table.insert(kids, message("No additional details", "This issue has no description, design, acceptance criteria, or notes.")) end
	return el("article", "beads-detail beads-tone-" .. tone, { key = issue.id }, kids)
end

function View.render(state: State, cx: BlockCx): BlockView
	local narrow = cx.cols < 110
	local tabs = narrow or state.mode == "tabs"
	local toolbar: { Node } = {}
	if state.selected then table.insert(toolbar, button("← Board", "back", "back")) end
	table.insert(toolbar, el("div", "beads-heading", nil, {
		el("h2", "beads-title", { text = "Beads" }, nil), label("READ ONLY", "beads-readonly"),
	}))
	table.insert(toolbar, el("div", "beads-actions", nil, {
		button(if state.loading then "Refreshing…" else "Refresh", "refresh", "refresh"),
		button(if state.mode == "tabs" then "Board" else "Tabs", "mode", "mode", state.mode == "tabs"),
	}))
	local children: { Node } = {
		el("header", "beads-toolbar", { key = "toolbar" }, toolbar),
		el("p", "beads-project", { key = "project", text = state.project, title = state.project }, nil),
	}
	if state.problem then
		local problem = state.problem
		local warning: { Node } = {
			el("h3", "beads-section-title", { text = problem.title }, nil),
			el("p", "beads-muted", { text = problem.text }, nil),
		}
		if state.issues then table.insert(warning, label("Stale data · showing the last successful refresh.", "beads-stale")) end
		if problem.detail and problem.detail ~= "" then table.insert(warning, ui.code(problem.detail)) end
		table.insert(children, el("section", "beads-problem", { key = "problem" }, warning))
	end
	local selected = Model.find(state.issues, state.selected)
	if selected then
		table.insert(children, detail(selected, state.lanes))
	elseif state.issues then
		if state.selected then table.insert(children, message("Issue no longer in this project", "The issue was absent from the latest successful refresh. Go back to the board.")) end
		if #state.issues == 0 then table.insert(children, message("Your board is clear", "No Beads issues were found in this project. Refresh after adding issues with bd.")) end
		if tabs then
			local buttons: { Node } = {}
			local active = state.lanes[1]
			for _, lane in state.lanes do
				table.insert(buttons, button(lane.title .. " " .. #lane.issues, "lane=" .. lane.status, lane.status, lane.status == state.lane))
				if lane.status == state.lane then active = lane end
			end
			table.insert(children, el("nav", "beads-tabs", { key = "tabs", aria = "Issue status lanes" }, buttons))
			table.insert(children, lane_view(active, state.cursor, true))
		else
			local lanes: { Node } = {}
			for _, lane in state.lanes do table.insert(lanes, lane_view(lane, state.cursor, false)) end
			table.insert(children, el("div", "beads-board", { key = "board", aria = "Kanban board" }, lanes))
		end
	elseif not state.problem then
		table.insert(children, ui.progress(nil, "Loading all Beads issues…"))
	end
	local freshness = if state.loading then "Loading…" elseif state.fetched then "Updated " .. os.date("%H:%M:%S", state.fetched) else "Not loaded"
	local count = if state.issues then tostring(#state.issues) .. " issues · " else ""
	local help = if state.selected then "Esc back · r refresh" else "←→ lanes · ↑↓ cards · Enter details · r refresh · t tabs"
	return {
		main = ui.col({ el("div", "beads-root", { key = "beads" }, children) }),
		dock = ui.col({ ui.text({ ui.span(count .. freshness .. "  ·  ", "muted"), ui.span(help, "dim") }) }),
	}
end
return View
