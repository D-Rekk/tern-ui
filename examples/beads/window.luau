--!strict

tern.command({
	id = "open",
	title = "Open Beads board",
	icon = "list",
	run = function(cx: WindowCx)
		local focused = cx.session:focused()
		local pane = if focused then cx.session:pane(focused) else nil
		local cwd = if pane then pane.cwd else nil
		if not cwd or cwd == "" then
			cx:toast("error", "The current pane has no known working directory", "Open the board from a project shell, or launch beads.board with an explicit directory argument.")
			return
		end
		-- Block creation may use the tab cwd rather than this shell's latest cwd.
		-- Passing the inspected pane directory makes the project choice explicit.
		if cx:new_block("beads.board", { cwd }, "beside") == nil then
			cx:toast("error", "Beads is not loaded on this pane host", "Install the Beads plugin and bd where the session's panes run.")
		end
	end,
})
