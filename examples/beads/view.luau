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
local function button(text: string, action: string, key: string, active: boolean?, class: string?): Node
	local classes = "beads-button"
	if class and class ~= "" then classes ..= " " .. class end
	if active then classes ..= " beads-button-active" end
	local props: { [string]: any } = {
		key = key, text = text, actions = { click = action }, aria = text,
	}
	if active ~= nil then props.attrs = { ["aria-pressed"] = active } end
	return el("button", classes, props, nil)
end
local function icon_button(name: string, title: string, action: string, key: string, class: string): Node
	return el("button", "beads-icon-button " .. class, {
		key = key, actions = { click = action }, aria = title, title = title,
	}, { ui.node("icon", { name = name }) })
end
local function message(title: string, text: string): Node
	return el("section", "beads-message", { aria = title }, {
		el("h3", "beads-message-title", { text = title }, nil),
		el("p", "beads-muted", { text = text }, nil),
	})
end
local function is_wip(status: string): boolean
	return status == "in_progress" or status == "test"
end
local function status_mark(status: string, populated: boolean): Node
	return el("span", "beads-status-mark" .. (if is_wip(status) and populated then " beads-status-mark-wip" else ""), {
		attrs = { ["aria-hidden"] = true },
	}, nil)
end
local function priority_text(issue: Issue): string
	return if issue.priority ~= nil then "P" .. tostring(issue.priority) else "P?"
end
local function issue_card(issue: Issue, lane: Lane, cursor: string?): Node
	local meta: { Node } = {
		label(if issue.kind ~= "" then issue.kind else "issue", "beads-kind"),
	}
	if issue.assignee ~= "" then table.insert(meta, label("@" .. issue.assignee, "beads-assignee")) end
	local kids: { Node } = {
		el("div", "beads-card-topline", nil, {
			el("div", "beads-card-id", nil, {
				label(issue.id, "beads-id"),
				icon_button("copy", "Copy Bead ID " .. issue.id, "copy-issue=" .. issue.id, "copy", "beads-copy-button"),
			}),
			label(priority_text(issue), "beads-priority" .. (if issue.priority == 0 then " beads-critical" else "")),
		}),
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
	table.insert(kids, el("button", "beads-button beads-open-button", {
		key = "open", text = "Open", actions = { click = "issue=" .. issue.id },
		aria = "Open Bead " .. issue.id, title = "Open Bead " .. issue.id,
	}, nil))
	return el("article", "beads-card beads-tone-" .. lane.tone .. (if cursor == issue.id then " beads-card-focused" else ""), {
		key = issue.id, aria = issue.id .. ": " .. issue.title,
	}, kids)
end
local function lane_view(lane: Lane, cursor: string?, tabs: boolean, key_prefix: string): Node
	local cards: { Node } = {}
	for _, issue in lane.issues do table.insert(cards, issue_card(issue, lane, cursor)) end
	if #cards == 0 then table.insert(cards, message("Lane clear", "No issues in " .. lane.title .. ".")) end
	return el("section", "beads-lane beads-tone-" .. lane.tone .. (if tabs then " beads-lane-tab" else ""), {
		key = key_prefix .. lane.status, aria = lane.title .. " issues",
	}, {
		el("header", "beads-lane-head", nil, {
			el("div", "beads-lane-name", nil, {
				status_mark(lane.status, #lane.issues > 0),
				label(lane.title, "beads-lane-title"),
			}),
			label(tostring(#lane.issues), "beads-count"),
		}),
		el("div", "beads-cards", nil, cards),
	})
end
local function lane_tab(lane: Lane, active: boolean): Node
	return el("button", "beads-tab beads-tone-" .. lane.tone .. (if active then " beads-tab-active" else ""), {
		key = "tab-" .. lane.status,
		actions = { click = "lane=" .. lane.status },
		aria = lane.title .. ", " .. tostring(#lane.issues) .. " issues" .. (if active then ", selected" else ""),
		attrs = { ["aria-pressed"] = active },
	}, {
		status_mark(lane.status, #lane.issues > 0),
		label(lane.title, "beads-tab-title"),
		label(tostring(#lane.issues), "beads-tab-count"),
	})
end
local function board_layout(lanes: { Lane }, cursor: string?): Node
	local children: { Node } = {}
	for _, lane in lanes do table.insert(children, lane_view(lane, cursor, false, "board-lane-")) end
	return el("div", "beads-board-layout", { key = "board-layout" }, {
		el("div", "beads-board", { aria = "Kanban board" }, children),
	})
end
local function tabs_layout(lanes: { Lane }, active_status: string, cursor: string?): Node
	local tabs: { Node } = {}
	local active: Lane? = lanes[1]
	for _, lane in lanes do
		local selected = lane.status == active_status
		table.insert(tabs, lane_tab(lane, selected))
		if selected then active = lane end
	end
	local children: { Node } = {
		el("nav", "beads-tabs", { key = "tab-list", aria = "Issue status lanes" }, tabs),
	}
	if active then
		table.insert(children, lane_view(active, cursor, true, "tabs-lane-"))
	else
		table.insert(children, message("No status lanes", "Refresh after adding issues with bd."))
	end
	return el("div", "beads-tabs-layout", { key = "tabs-layout" }, children)
end
local function detail_badge(text: string, class: string): Node
	return el("span", "beads-detail-badge " .. class, { text = text }, nil)
end
local function fact(term: string, value: string, key: string): Node
	return el("div", "beads-fact", { key = key }, {
		el("dt", "beads-fact-label", { text = term }, nil),
		el("dd", "beads-fact-value", { text = value }, nil),
	})
end
local function markdown(text: string, key: string): Node
	local node = ui.md(text)
	local props: { [string]: any } = node.p or {}
	props.key = key
	props.role = "beads.issue-content"
	node.p = props
	return node
end
local function detail(issue: Issue, lanes: { Lane }): Node
	local tone, status_title = "custom", issue.status
	for _, lane in lanes do
		if lane.status == issue.status then tone, status_title = lane.tone, lane.title end
	end
	local priority_names = { [0] = "Critical", [1] = "High", [2] = "Medium", [3] = "Low", [4] = "Backlog" }
	local badges: { Node } = {
		el("span", "beads-detail-badge beads-status-badge beads-tone-" .. tone, nil, {
			status_mark(issue.status, true), label(status_title, "beads-badge-text"),
		}),
		detail_badge(
			if issue.priority ~= nil then "P" .. issue.priority .. " · " .. (priority_names[issue.priority] or "Custom") else "Priority not set",
			"beads-priority-badge" .. (if issue.priority == 0 then " beads-critical" else "")
		),
		detail_badge(if issue.kind ~= "" then issue.kind else "Type not set", "beads-type-badge"),
	}
	local facts: { Node } = {
		fact("Assignee", if issue.assignee ~= "" then issue.assignee else "Unassigned", "assignee"),
	}
	if issue.created ~= "" then table.insert(facts, fact("Created", issue.created, "created")) end
	if issue.updated ~= "" then table.insert(facts, fact("Updated", issue.updated, "updated")) end
	if issue.closed ~= "" then table.insert(facts, fact("Closed", issue.closed, "closed")) end
	local kids: { Node } = {
		el("header", "beads-detail-head", nil, {
			el("div", "beads-detail-kicker", nil, {
				label(issue.id, "beads-id beads-detail-id"),
				label("Issue detail", "beads-detail-eyebrow"),
			}),
			el("h2", "beads-detail-title", { text = issue.title }, nil),
			el("div", "beads-detail-badges", nil, badges),
		}),
	}
	if #issue.labels > 0 then
		local labels: { Node } = { label("Labels", "beads-detail-label-heading") }
		for i, name in issue.labels do
			table.insert(labels, el("span", "beads-label beads-detail-label", { key = tostring(i), text = name }, nil))
		end
		table.insert(kids, el("div", "beads-detail-labels", nil, labels))
	end
	table.insert(kids, el("section", "beads-detail-metadata", { aria = "Issue metadata" }, {
		el("h3", "beads-section-title", { text = "Metadata" }, nil),
		el("dl", "beads-facts", nil, facts),
	}))
	local sections = {
		{ key = "description", title = "Description", text = issue.description },
		{ key = "design", title = "Design", text = issue.design },
		{ key = "acceptance", title = "Acceptance criteria", text = issue.acceptance },
		{ key = "notes", title = "Notes", text = issue.notes },
	}
	local has_text = false
	for _, section in sections do
		if section.text ~= "" then
			has_text = true
			table.insert(kids, el("section", "beads-detail-section", { key = section.key, aria = section.title }, {
				el("h3", "beads-section-title", { text = section.title }, nil),
				el("div", "beads-detail-copy", nil, { markdown(section.text, "markdown") }),
			}))
		end
	end
	if not has_text then
		table.insert(kids, message("No additional details", "This issue has no description, design, acceptance criteria, or notes."))
	end
	return el("article", "beads-detail beads-tone-" .. tone, {
		key = issue.id, aria = issue.id .. ": " .. issue.title,
	}, kids)
end
local function shortcut(key: string, text: string, id: string): Node
	return el("div", "beads-shortcut", { key = id }, {
		ui.node("kbd", { key = "keycap", keys = { key } }),
		label(text, "beads-shortcut-label"),
	})
end

function View.render(state: State, _cx: BlockCx): BlockView
	local leading: { Node } = {}
	if state.selected then
		table.insert(leading, icon_button("arrow-left", "Back to board", "back", "back", "beads-back-button"))
	end
	table.insert(leading, el("div", "beads-heading", nil, {
		el("h2", "beads-title", { text = "Beads" }, nil),
	}))
	local refresh_title = if state.loading then "Refreshing issues…" else "Refresh issues"
	local toolbar: { Node } = {
		el("div", "beads-toolbar-leading", nil, leading),
		el("div", "beads-actions", nil, {
			el("button", "beads-icon-button beads-refresh", {
				key = "refresh", mark = if state.loading then "loading" else nil,
				actions = { click = "refresh" }, aria = refresh_title, title = refresh_title,
				attrs = { ["aria-busy"] = state.loading },
			}, { ui.node("icon", { name = "fetch" }) }),
			el("div", "beads-layout-switch", { aria = "Board layout", attrs = { role = "group" } }, {
				button("Auto", "layout=auto", "auto-mode", state.mode == "auto"),
				button("Board", "layout=board", "board-mode", state.mode == "board"),
				button("Tabs", "layout=tabs", "tabs-mode", state.mode == "tabs"),
			}),
		}),
	}
	local freshness = if state.loading then "Refreshing…"
		elseif state.problem then (if state.issues then "Stale data" else "Not loaded")
		elseif state.fetched then "Updated " .. os.date("%H:%M:%S", state.fetched) else "Not loaded"
	local issue_count = if state.issues then tostring(#state.issues) .. (if #state.issues == 1 then " issue" else " issues") else "Waiting for issues"
	local children: { Node } = {
		el("header", "beads-toolbar", { key = "toolbar" }, toolbar),
	}
	if state.problem then
		local problem = state.problem
		local warning: { Node } = {
			el("h3", "beads-section-title", { text = problem.title }, nil),
			el("p", "beads-muted", { text = problem.text }, nil),
		}
		if state.issues then table.insert(warning, label("Stale data · showing the last successful refresh.", "beads-stale")) end
		if problem.detail and problem.detail ~= "" then table.insert(warning, ui.code(problem.detail)) end
		table.insert(children, el("section", "beads-problem", { key = "problem", aria = problem.title }, warning))
	end
	local selected = Model.find(state.issues, state.selected)
	if selected then
		table.insert(children, detail(selected, state.lanes))
	elseif state.issues then
		if state.selected then
			table.insert(children, message("Issue no longer in this project", "The issue was absent from the latest successful refresh. Go back to the board."))
		elseif #state.issues == 0 then
			table.insert(children, message("Your board is clear", "No Beads issues were found in this project. Refresh after adding issues with bd."))
		elseif state.mode == "auto" then
			table.insert(children, board_layout(state.lanes, state.cursor))
			table.insert(children, tabs_layout(state.lanes, state.lane, state.cursor))
		elseif state.mode == "tabs" then
			table.insert(children, tabs_layout(state.lanes, state.lane, state.cursor))
		else
			table.insert(children, board_layout(state.lanes, state.cursor))
		end
	elseif not state.problem then
		table.insert(children, el("section", "beads-loading", { aria = "Loading Beads issues" }, {
			ui.progress(nil, "Loading all Beads issues…"),
		}))
	end
	local shortcuts: { Node } = {
		shortcut("r", "Refresh", "refresh"),
		shortcut("t", "Layout", "layout"),
	}
	if state.selected then table.insert(shortcuts, shortcut("esc", "Back", "back")) end
	table.insert(children, el("footer", "beads-footer", { key = "footer", aria = "Project and keyboard shortcuts" }, {
		el("p", "beads-project", { text = state.project, title = state.project }, nil),
		el("span", "beads-sync", {
			text = issue_count .. " · " .. freshness,
			attrs = { role = "status", ["aria-live"] = "polite", ["aria-atomic"] = true },
		}, nil),
		el("div", "beads-shortcuts", nil, shortcuts),
	}))
	return {
		main = ui.col({ el("div", "beads-root beads-mode-" .. state.mode, { key = "beads" }, children) }),
	}
end
return View
