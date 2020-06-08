local util   = require 'Resources.lib.hanker.util'

-- @class Hanker.Context
-- @desc A hanker context represents the top level state of the UI. multiple
-- contexts can be used to keep UI state separate, or you can use the default
-- context by calling context methods directly on the `Hanker` object.
local Context = {}
local Context_mt = {__index = Context}

function Context.new()
	local self = setmetatable({}, Context_mt)
	self.time = 0
	self.deltaTime = 0

	self.mouseX, self.mouseY = 0, 0

	self.defaultFont = self.newFont(love.graphics.getFont())
	self.defaultStyles = {}

	self.drawList = {}

	-- TODO: instead of storing all buttons ever, instead use a system more
	-- like drawList
	self.clickables = setmetatable({}, {__mode ='k'})
	self.scrollLists = setmetatable({}, {__mode ='k'})
	self.editBoxes = setmetatable({}, {__mode ='k'})
	return self
end

function Context:addToDrawList(control)
	if control.draw then
		table.insert(self.drawList, control)
	end
end

-- @function Context:draw
-- @desc draw the currently active UI controls.
function Context:draw()
	local numDrawables = #self.drawList
	for i = 1, numDrawables do
		self.drawList[i]:draw()
	end

	for i = numDrawables, 1, -1 do
		self.drawList[i] = nil
	end

	for btn, _ in pairs(self.clickables) do
		btn:onUpdate()
	end
end

-- @function Context:mousePressed
-- @desc call when a mouse button has been pressed.
-- @param x cursor x coordinate, in viewport units
-- @param y cursor y coordinate, in viewport units
-- @param m mouse button
-- @see love.mousepressed
function Context:mousePressed(x, y, m)
	for btn, _ in pairs(self.clickables) do
		btn:onPress(x, y, m)
	end
end

-- @function Context:mouseReleased
-- @desc call when a mouse button has been released.
-- @param x cursor x coordinate, in viewport units
-- @param y cursor y coordinate, in viewport units
-- @param m mouse button
-- @see love.mousereleased
function Context:mouseReleased(x, y, m)
	for btn, _ in pairs(self.clickables) do
		btn:onRelease(x, y, m)
	end
end

local function tryCall(obj, fname, ...)
	if obj and obj[fname] then
		return obj[fname](obj, ...)
	end
	return nil
end

-- @function Context:mouseMoved
-- @desc call when the mouse cursor has been moved.
-- @param x cursor x coordinate, in viewport units
-- @param y cursor y coordinate, in viewport units
-- @see love.mousemoved
function Context:mouseMoved(x, y)
	self:updateMouse(x, y)
	tryCall(self.activeCursorTab, "mouseMoved", x, y)
	tryCall(self.activeCursorX, "mouseMoved", x, y)
	tryCall(self.activeCursorY, "mouseMoved", x, y)
end

-- @function Context:updateMouse
-- @desc Update the UI mouse position. In most cases you should rely on
-- mouseMoved to update the mouse for you instead.
-- @param x cursor x coordinate, in viewport units
-- @param y cursor y coordinate, in viewport units
function Context:updateMouse(x, y)
	self.mouseX, self.mouseY = x, y
end

-- @function Context:wheelMoved
-- @desc call when the mouse wheel has been moved.
-- @param x wheel x coordinate, in mousewheel units
-- @param y wheel y coordinate, in mousewheel units
-- @see love.wheelmoved
function Context:wheelMoved(x, y)
	for list, _ in pairs(self.scrollLists) do
		list:onWheelMove(x, y)
	end
end

-- @function Context:textInput
-- @desc call when the user has input some text.
-- @param text the text to be input. utf8 string.
-- @see love.textinput
function Context:textInput(text)
	for editBox, _ in pairs(self.editBoxes) do
		editBox:onTextInput(text)
	end
end

-- @function Context:keyboardKeyPressed
-- @desc call when the user has pressed a key on their keyboard.
-- @param key the keycode of the pressed key. scancode unused.
-- @see love.keypressed
function Context:keyboardKeyPressed(key)
	for editBox, _ in pairs(self.editBoxes) do
		local inputUsed = editBox:onKeyboardKeyPressed(key)
		if inputUsed then
			return true
		end
	end
	return false
end

local horizontalMove = {left=true,right=true,next=true,previous=true}
local verticalMove   = {up=true,down=true}
local tabMove        = {nexttab=true,previoustab=true}

-- @function Context:cursorKeyPressed
-- @desc call when the user starts performing an action that should be translated into
-- UI cursor movement. This is application-defined: you may want gamepads or
-- the arrow keys or even tab/shift-tab to cause cursor movement. You can
-- also programmatically change the cursor, although for many cases you can
-- just directly manipulate the current cursor yourself.
-- @param cursorKey the cursorKey that has been pressed.
-- @see Hanker.Cursors
function Context:cursorKeyPressed(k)
	if horizontalMove[k] then
		return tryCall(self.activeCursorX, "cursorKeyPressed", k)
	elseif verticalMove[k] then
		return tryCall(self.activeCursorY, "cursorKeyPressed", k)
	elseif tabMove[k] then
		return tryCall(self.activeCursorTab, "cursorKeyPressed", k)
	else
		if not tryCall(self.activeCursorY, "cursorKeyPressed", k) then
			return tryCall(self.activeCursorX, "cursorKeyPressed", k)
		else
			return true
		end
	end
end

-- @function Context:cursorKeyPressed
-- @desc call when the user finishes performing an action that should be
-- translated into UI cursor movement. If there is no begin/end to the
-- action, you should call pressed and released at the same time.
-- @param cursorKey the cursorKey that has been released.
-- @see Hanker.Cursors
function Context:cursorKeyReleased(k)
	if horizontalMove[k] then
		return tryCall(self.activeCursorX, "cursorKeyReleased", k)
	elseif verticalMove[k] then
		return tryCall(self.activeCursorY, "cursorKeyReleased", k)
	elseif tabMove[k] then
		return tryCall(self.activeCursorTab, "cursorKeyReleased", k)
	else
		-- TODO: users should be able to flip the order
		if not tryCall(self.activeCursorY, "cursorKeyReleased", k) then
			return tryCall(self.activeCursorX, "cursorKeyReleased", k)
		else
			return true
		end
	end
end

-- @function Context:updateFrame
-- @desc Update the UI time. this is used to drive animations.
-- @param dt The amount of time to update the UI by, in seconds.
-- @see love.update
function Context:updateFrame(dt)
	self.deltaTime = dt
	self.time = self.time + self.deltaTime

	for list, _ in pairs(self.scrollLists) do
		list:onUpdate(dt)
	end
end

-- @function Context:setDefaultFont
-- @desc Set the font controls should use when no other font is provided in
-- their constructor. controls will _not_ update their font if you change the
-- default after they have been constructed, they will just keep the old
-- default font.
-- @param hankerFont the Hanker.Font object
-- @return self
function Context:setDefaultFont(hankerFont)
	self.defaultFont = hankerFont
	return self
end

-- @function Context:getDefaultFont
-- @return hankerFont
function Context:getDefaultFont()
	return self.defaultFont
end

-- @function Context:setDefaultStyle
-- @desc Set the default parent style for a given control type.
-- nil is valid and is treated as "no default style".
-- @param controlType the control type string.
-- @param style the control style table.
-- @return self
function Context:setDefaultStyle(controlType, style)
	if style.ControlType then
		style = util.shallowCopy_({}, style.style)
	end
	self.defaultStyles[controlType] = style
	return self
end

-- @function Context:getDefaultStyle
-- @param controlType the control type string.
-- @return style
function Context:getDefaultStyle(controlType)
	return self.defaultStyles[controlType]
end

function Context.RegisterControlClass(ControlClass)
	local controlName = ControlClass.ControlType
	local factoryName = 'new'..controlName
	Context[factoryName] = function(instance, ...)
		return ControlClass.new(instance, ...)
	end
end

function Context.RegisterCursorClass(cursorName, CursorClass)
	local factoryName = 'new'..cursorName
	Context[factoryName] = function(instance, ...)
		return CursorClass.new(instance, ...)
	end
end

function Context.RegisterFontClass(fontName, FontClass)
	local factoryName = 'new'..fontName
	Context[factoryName] = function(_instance, ...)
		return FontClass.new(...)
	end
end

local BuiltinControls = require 'Resources.lib.hanker.controls'
for _, ControlClass in pairs(BuiltinControls) do
	if type(ControlClass) == 'table' and ControlClass.ControlType then
		Context.RegisterControlClass(ControlClass)
	end
end

local BuiltinCursors = require 'Resources.lib.hanker.cursors'
for cursorName, CursorClass in pairs(BuiltinCursors) do
	Context.RegisterCursorClass(cursorName, CursorClass)
end

local BuiltinFonts = require 'Resources.lib.hanker.fonts'
for fontName, fontClass in pairs(BuiltinFonts) do
	Context.RegisterFontClass(fontName, fontClass)
end

return Context
