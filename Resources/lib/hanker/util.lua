local utf8   = require 'utf8'
local util = {}

function util.pointInsideRect(x, y, ax, ay, aw, ah)
	-- So the choice of inclusive/exclusive here is made so that rects with 0
	-- margin in between them still have exclusive hitboxes, e.g.
	-- * rect 1 has x 0, w, 100
	-- * rect 2 has x 100, w, 100
	-- x 100 will always go to rect 2, and x 200 will not trigger anything.
	return x >= ax and x < ax + aw and y >= ay and y < ay + ah
end

function util.pointInsideCircle(x, y, ax, ay, ar)
	local dx, dy = ax - x, ay - y
	return (dx * dx + dy * dy) < ar * ar
end

function util.lerp(a, b, t)
	return a + (b - a) * t
end

function util.outExpo(time, begin, change, duration)
	return change * 1.001 * (-math.pow(2, -10 * time / duration) + 1) + begin
end

function util.len(tbl)
	local mt = getmetatable(tbl)
	if mt and mt.__len then
		return mt.__len(tbl)
	end
	return #tbl
end

function util.isAxis(maybeAxis)
	return maybeAxis == 'x' or maybeAxis == 'y'
end

function util.swapAxis(axis)
	return axis == 'x' and 'y' or 'x'
end

function util.clamp(value, min, max)
	if value < min then
		return min
	elseif value > max then
		return max
	else
		return value
	end
end

function util.sortArgs(...)
	local numArgs = select('#', ...)
	if numArgs == 2 then
		local left, right = ...
		if left > right then
			return right, left
		else
			return left, right
		end
	else
		local args = {...}
		table.sort(args)
		return unpack(args)
	end
end

util.utf8 = {}
function util.utf8.sub(str, i, j)
	if i then i = utf8.offset(str, i) end
	if j then j = utf8.offset(str, j) end
	return string.sub(str, i, j)
end

function util.shallowCopy_(newtbl, tbl)
	for k, v in pairs(newtbl) do
		newtbl[k] = nil
	end

	for k, v in pairs(tbl) do
		newtbl[k] = v
	end

	return newtbl
end

return util
