--!strict
-- Route only plain .luau file opens; explicit Open with remains available.

tern.route.open(function(req: OpenRequest, _cx: WindowCx): RouteDecision?
	if req.how ~= "default" or req.line ~= nil or req.col ~= nil then
		return nil
	end
	if req.origin ~= "files" and req.origin ~= "palette" then
		return nil
	end
	if string.lower(string.sub(req.path, -5)) ~= ".luau" then
		return nil
	end
	return { block = "luau-viewer.viewer", args = { req.path } }
end)
