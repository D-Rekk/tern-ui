--!strict

export type Issue = {
	id: string,
	title: string,
	status: string,
	priority: number?,
	kind: string,
	assignee: string,
	labels: { string },
	description: string,
	design: string,
	acceptance: string,
	notes: string,
	created: string,
	updated: string,
	closed: string,
}
export type Lane = { status: string, title: string, tone: string, issues: { Issue } }

local Model = {}
local standard = { "open", "in_progress", "test", "review", "closed" }
local names: { [string]: string } = {
	open = "Todo", in_progress = "In Progress", test = "Test", review = "Review",
	closed = "Done", blocked = "Blocked", deferred = "Deferred",
}
local tones: { [string]: string } = {
	open = "todo", in_progress = "progress", test = "test", review = "review",
	closed = "done", blocked = "blocked", deferred = "deferred",
}
local function text(value: any): string
	return if type(value) == "string" then value else ""
end

function Model.parse(stdout: string): ({ Issue }?, string?)
	-- Checking the envelope also distinguishes an empty object from an empty list.
	if not string.match(stdout, "^%s*%[") then
		return nil, "Expected a JSON array from bd list."
	end
	local ok, data = pcall(tern.json.decode, stdout)
	if not ok or type(data) ~= "table" then
		return nil, "bd returned invalid JSON."
	end
	local issues: { Issue } = {}
	local ids: { [string]: boolean } = {}
	for _, item in data do
		if type(item) ~= "table" or type(item.id) ~= "string" or item.id == ""
			or type(item.title) ~= "string" or type(item.status) ~= "string" or item.status == "" then
			return nil, "An issue is missing its id, title, or status. No partial list was applied."
		end
		if ids[item.id] then
			return nil, "bd returned duplicate issue ids. No partial list was applied."
		end
		ids[item.id] = true
		local labels: { string } = {}
		if type(item.labels) == "table" then
			for _, label in item.labels do
				if type(label) == "string" then table.insert(labels, label) end
			end
		end
		table.insert(issues, {
			id = item.id, title = item.title, status = item.status,
			priority = if type(item.priority) == "number" then item.priority else nil,
			kind = text(item.issue_type), assignee = text(item.assignee), labels = labels,
			description = text(item.description), design = text(item.design),
			acceptance = text(item.acceptance_criteria), notes = text(item.notes),
			created = text(item.created_at), updated = text(item.updated_at), closed = text(item.closed_at),
		})
	end
	table.sort(issues, function(a, b)
		local ap, bp = a.priority or 5, b.priority or 5
		if ap ~= bp then return ap < bp end
		return a.id < b.id
	end)
	return issues, nil
end

function Model.lanes(issues: { Issue }): { Lane }
	local lanes: { Lane } = {}
	local by_status: { [string]: Lane } = {}
	local function add(status: string)
		local lane: Lane = {
			status = status, title = names[status] or status, tone = tones[status] or "custom", issues = {},
		}
		by_status[status] = lane
		table.insert(lanes, lane)
	end
	for _, status in standard do add(status) end
	local extra: { [string]: boolean } = {}
	for _, issue in issues do
		if not by_status[issue.status] then extra[issue.status] = true end
	end
	local statuses: { string } = {}
	for status in extra do table.insert(statuses, status) end
	table.sort(statuses)
	for _, status in statuses do add(status) end
	for _, issue in issues do table.insert(by_status[issue.status].issues, issue) end
	return lanes
end

function Model.find(issues: { Issue }?, id: string?): Issue?
	for _, issue in issues or {} do
		if issue.id == id then return issue end
	end
	return nil
end

return Model
