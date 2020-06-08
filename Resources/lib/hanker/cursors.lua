--[[
Cursors represent navigational behavior within a given menu, for example using
a dpad or the keyboard arrow keys. Each control that wants to be navigated to
in this way needs to register with a cursor that provides that behavior, and
then the currently active cursor needs to be called from the update loop, as if
it were a control.

for simple static layouts the FixedGridCursor is good: if you only want one
dimensional layouts, just only add rows, or only add columns.

The ScrollListCursor is built to be used in tandem with a ScrollList: it'll
automatically handle the nuances of controls coming and leaving and movement
causing the scrollList to, yknow, scroll.

TODO: multicursors. it should be possible to put cursors inside of a meta-cursor
and lay them out in a horizontal/vertical direction.

TODO: the FixedGridCursor really should gracefully handle removing and adding
controls at runtime. Then it can be upgraded to GridCursor.

TODO: it might be nice to have an AutoFixedGridCursor that just pulls the
buttons out from the drawList and adds them that way
]]

local Cursors = {}

Cursors.CURSOR_KEYS = {
	"confirm", -- usually 'A'
	"cancel", -- usually 'B'
	"options", -- this is intended for context/right click menus
	"next", -- for tab
	"previous", -- for shift-tab
	"pageup", -- you know what this is
	"pagedown", -- ditto
	"first", -- use with home key
	"last", -- use with end key
	"nexttab", -- use with gamepad LB, for tabbed interfaces
	"previoustab", -- use with gamepad RB, for tabbed interfaces
	"up",
	"down",
	"left",
	"right",
}

-- {{{ FixedGridCursor
local FixedGridCursor = {}
local FixedGridCursor_mt = {__index = FixedGridCursor}
Cursors.FixedGridCursor = FixedGridCursor

local fixedGridCursorDefaults = {
	shouldWrapY = false,
	shouldWrapX = false,
	tabAxis = nil,
}
--- Creates a fixed grid cursor, which is good for static lists of controls
--  that don't have complicated layout.
function FixedGridCursor.new(context, config)
	config = config or {}
	for k, v in pairs(fixedGridCursorDefaults) do
		if config[k] == nil then
			config[k] = v
		end
	end

	return setmetatable({
		context = context,
		grid = {},
		config = config,
		_isLeaving = false,
	}, FixedGridCursor_mt)
end

function FixedGridCursor:isLeaving()
	local isLeaving = self._isLeaving
	self._isLeaving = false
	return isLeaving
end

function FixedGridCursor:selectIndex(x, y)
	if self.grid[x] == nil or self.grid[x][y] == nil then
		return false
	end

	local oldControl = self:getSelectedControl()
	self.x, self.y = x, y
	local newControl = self:getSelectedControl()
	if oldControl ~= newControl then
		if oldControl then
			oldControl:setPressed(false)
			oldControl:setSelected(false)
		end
		newControl:setSelected(true)
	end
	return true
end

function FixedGridCursor:selectControl(control)
	for x, col in pairs(self.grid) do
		for y, _control in pairs(col) do
			if _control == control then
				return self:selectIndex(x, y)
			end
		end
	end
	return false
end

function FixedGridCursor:getSelectedControl(control)
	return self.x and self.grid[self.x][self.y]
end

function FixedGridCursor:getGridControl(x, y)
	return self.grid[x] and self.grid[x][y]
end

function FixedGridCursor:setGridControl(control, x, y)
	if not self.grid[x] then self.grid[x] = {} end
	self.grid[x][y] = control
	return self
end

function FixedGridCursor:addRow(control, x)
	local newx = x or math.max(#self.grid-1, 1)
	local newy = self.grid[newx] and (#self.grid[newx] + 1) or 1

	self:setGridControl(control, newx, newy)
	return newx, newy
end

function FixedGridCursor:addColumn(control)
	local newx = #self.grid + 1
	local newy = 1

	self:setGridControl(control, newx, newy)
	return newx, newy
end

function FixedGridCursor:move(direction)
	local newX = self.x
	local newY = self.y
	local lastControl = self:getGridControl(self.x, self.y)
	local iter = 0
	repeat
		iter = iter + 1
		if iter > 100 then
			-- just in case, because unbounded loop
			error("cursor move could not resolve successfully")
		end
		local lastX = newX
		local lastY = newY
		if direction == 'left' then
			newX = newX - 1
		elseif direction == 'right' then
			newX = newX + 1
		end

		if self.config.shouldWrapX then
			newX = ((newX - 1) % #self.grid) + 1
		elseif not self.grid[newX] then
			newX = lastX
		end

		local numRows = #self.grid[newX]

		if direction == 'up' then
			newY = newY - 1
		elseif direction == 'down' then
			newY = newY + 1
		elseif direction == 'pageup' or direction == 'first' then
			newY = 1
		elseif direction == 'pagedown' or direction == 'last' then
			newY = numRows
		end

		if self.config.shouldWrapY then
			newY = ((newY - 1) % numRows) + 1
		elseif not self.grid[newX][newY] then
			newY = lastY
		end
		-- This loop allows us to treat the same control occupying multiple
		-- grid cells as a single control, ala windows 8 style multi-sized
		-- tiles. If you try to move and and the control hasn't changed, we
		-- repeat until it does or the effect of your movement stops causing
		-- changes (e.g.  you're at the end of the grid)
	until lastControl ~= self:getGridControl(newX, newY) or (newX == lastX and newY == lastY)

	return self:selectIndex(newX, newY)
end

function FixedGridCursor_mt.__call(self)
	if self.x == nil then
		assert(self:selectIndex(1, 1))
	end

	if #self.grid > 1 then
		if self.config.tabAxis == 'x' then
			self.context.activeCursorTab = self
		else
			self.context.activeCursorX = self
		end
	end

	if #self.grid[1] > 1 then
		if self.config.tabAxis == 'y' then
			self.context.activeCursorTab = self
		else
			self.context.activeCursorY = self
		end
	end
end

local function set(keys)
	local t = {}
	for _, k in ipairs(keys) do t[k] = true end
	return t
end

local function clickPressedButtons(self)
	for x, col in pairs(self.grid) do
		for y, control in pairs(col) do
			if control.pressed then
				control:setClicked(true)
			else
				control.pressed = false
			end
		end
	end
end

local fixedGridKeys = set{'up', 'down', 'left', 'right', 'first', 'last'}
function FixedGridCursor:cursorKeyPressed(k)
	if fixedGridKeys[k] then
		clickPressedButtons(self)
		self:move(k)
	elseif k == 'next' then
		clickPressedButtons(self)
		if not self:move('right') then
			self:move('down')
		end
	elseif k == 'previous' then
		clickPressedButtons(self)
		if not self:move('left') then
			self:move('up')
		end
	elseif k == 'confirm' then
		self:getSelectedControl():setPressed(true)
	else
		return false
	end
	return true
end

function FixedGridCursor:cursorKeyReleased(k)
	if k == 'confirm' then
		clickPressedButtons(self)
		return true
	end
	return false
end

function FixedGridCursor:mouseMoved(x, y)
	-- TODO: update selected to match mouse selected
end
-- }}}

-- {{{ ScrollListCursor
local ScrollListCursor = {}
local ScrollListCursor_mt = {__index = ScrollListCursor}
Cursors.ScrollListCursor = ScrollListCursor

local scrollListCursorDefaults = {
	shouldWrap = false,
	useFixedScrollPoint = false,
	shouldAutoSelectOnMouseMoved = false,
}
--- Creates a list cursor, which is built to be used with list controls.
-- TODO: make totally axis independent instead of just making it sorta work
function ScrollListCursor.new(context, list, config)
	config = config or {}
	for k, v in pairs(scrollListCursorDefaults) do
		if config[k] == nil then
			config[k] = v
		end
	end

	return setmetatable({
		context = context,
		list = list,
		config = config,
		_isLeaving = false
	}, ScrollListCursor_mt)
end

function ScrollListCursor:isLeaving()
	local isLeaving = self._isLeaving
	self._isLeaving = false
	return isLeaving
end

function ScrollListCursor:selectIndex(index, instantly)
	self.index = index

	if self.config.useFixedScrollPoint then
		-- scroll to center, or to scrollAnchor if provided
		self.list:scrollToIndex(index, instantly)
	else
		self.list:scrollIndexIntoView(index, instantly)
	end
	return true
end

function ScrollListCursor:selectIndexWithoutScroll(index)
	self.index = index
end

function ScrollListCursor:updateSelected()
	local activeControls = self.list:getActiveControls()
	for entryIndex, control in pairs(activeControls) do
		control:setSelected(self.index == entryIndex)
	end
end

function ScrollListCursor:getSelectedControl()
	return self.list:getControlAt(self.index)
end

function ScrollListCursor:getSelectedEntry()
	return self.list:getEntries()[self.index]
end

function ScrollListCursor:move(direction)
	local numCellsTotal = self.list:getNumCellsTotal()

	local newIndex
	if direction == 'previous' then
		newIndex = self.index - 1
	elseif direction == 'next' then
		newIndex = self.index + 1
	elseif direction == 'pageup' then
		newIndex = self.index - self.list:getNumCellsPerPage()
	elseif direction == 'pagedown' then
		newIndex = self.index + self.list:getNumCellsPerPage()
	elseif direction == 'first' then
		newIndex = 1
	elseif direction == 'last' then
		newIndex = numCellsTotal
	else
		error("not a valid direction")
	end

	if self.config.shouldWrap then
		newIndex = ((newIndex - 1) % numCellsTotal) + 1
	end
	newIndex = math.min(math.max(newIndex, 1), numCellsTotal)
	self:selectIndex(newIndex)
end

function ScrollListCursor_mt.__call(self)
	if self.index == nil then
		assert(self:selectIndex(1, 'instant'))
	end

	self.list:setActiveCursor(self)
	if self.list.axis == 'x' then
		if self.config.tabAxis == 'x' then
			self.context.activeCursorTab = self
		else
			self.context.activeCursorX = self
		end
	else
		if self.config.tabAxis == 'y' then
			self.context.activeCursorTab = self
		else
			self.context.activeCursorY = self
		end
	end
end


local scrollListDirections = set{
	'up', 'down', 'left', 'right',
	'previous', 'next',
	'pageup', 'pagedown',
	'first', 'last',
	'nexttab', 'previoustab',
}

local interpretMove = {
	['left'] = 'previous',
	['right'] = 'next',
	['up'] = 'previous',
	['down'] = 'next',
	['nexttab'] = 'previous',
	['previoustab'] = 'next',
}
function ScrollListCursor:cursorKeyPressed(k)
	if scrollListDirections[k] then
		self:move(interpretMove[k] or k)
	elseif k == 'confirm' then
		self:getSelectedControl():setPressed(true)
	else
		return false
	end
	return true
end

function ScrollListCursor:cursorKeyReleased(k)
	if k == 'confirm' then
		for y, control in pairs(self.list:getActiveControls()) do
			if control:isPressed() then
				control:setClicked(true)
			else
				control:setPressed(false)
			end
		end
	elseif k == 'cancel' then
		self._isLeaving = true
	else
		return false
	end
	return true
end

function ScrollListCursor:mouseMoved(dx, dy)
	if self.config.shouldAutoSelectOnMouseMoved then
		for y, control in pairs(self.list:getActiveControls()) do
			if control:isOver() then
				self:selectIndexWithoutScroll(dy)
				break
			end
		end
	end
end
-- }}}

return Cursors
