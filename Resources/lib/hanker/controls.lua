local util   = require 'Resources.lib.hanker.util'
local Anchor = require 'Resources.lib.hanker.anchor'
local Rect   = require 'Resources.lib.hanker.rect'
local utf8   = require 'utf8'

local function set(list)
	local s = {}
	for _, v in ipairs(list) do
		s[v] = true
	end
	return s
end

local NO_OVERRIDES = {}
local function mixin(class, mymixin)
	local overrides = mymixin._overrides or NO_OVERRIDES
	for k, v in pairs(mymixin) do
		if class[k] ~= nil and not overrides[k] then
			local errorString = ("mixing over an existing field %q: to override, define after mixing in."):format(k)
			error(errorString, 2)
		end
		class[k] = v
	end
end

local Controls = {}
-- @class Control
-- @desc Controls are the elements you actually build UI with. Every frame you
-- intend to draw or update a control, you must should call it, and then every
-- control called that frame that was not marked hidden will be drawn in the
-- order they were called.
-- @usage
-- local myControl = Hanker.newLabel("My Control")
-- myControl:setDimensions(100, 20)
-- myControl:left():setAbsolute(100)
-- myControl:top():setAbsolute(100)
-- function love.update(dt)
--   if showLabel then
--     -- recomputes the internal text object if needed, and draws.
--      myControl()
--   else
--      -- ony recompute the text object
--      myControl('hide')
--   end
-- end

-- @enum ControlHideBehavior
-- @value nil
-- @value "hide"

-- @function Control
-- @desc Computes the control, and adds it to the DrawList. What this means
-- varies per `controlType`, but this can be seen as "activating" the control to be used in this screen.
-- @param shouldHide when set to 'hide', will not add this control to the DrawList. this can be useful when a control needs to be computed but not drawn.
-- @usage
-- local myControl1 = Hanker.newLabel("My Control 1")
-- local myControl2 = Hanker.newLabel("My Control 2")
-- local myControl3 = Hanker.newLabel("My Control 3")
-- function love.update()
--   myControl1() -- will show "My Control 1" on screen.
--   myControl2('hide') -- will compute the size of myControl, so it can be anchored to, but it won't be visible
--   -- myControl3 will not be recomputed or shown this frame, unless it is called.
-- end
function Controls.newControlType(controlType)
	local Control = {}
	local control_mt = {__index = Control}
	Control.ControlType = controlType
	function Control.new(context, maybeParentStyle, ...)
		local parentStyle
		if type(maybeParentStyle) == 'table' then
			if maybeParentStyle.ControlType then
				parentStyle = util.shallowCopy_({}, maybeParentStyle.style)
			else
				parentStyle = maybeParentStyle
			end
		end

		local self = setmetatable({
			context = context,
			state = {},
		}, control_mt)

		if parentStyle then
			self.style = setmetatable({}, {__index = parentStyle})
			self:init(...)
		else
			parentStyle = context:getDefaultStyle(Control.ControlType)
			self.style = setmetatable({}, {__index = parentStyle})
			self:init(maybeParentStyle, ...)
		end

		return self
	end

	function Control:init()
		-- override me
	end

	function Control:resetState()
		-- override me
	end

	function control_mt.__call(self, shouldHide)
		if shouldHide ~= 'hide' then
			self.context:addToDrawList(self)
		end
		self:compute(shouldHide)
		return self
	end

	return Control
end

--{{{ DrawMixin

-- @class DrawMixin
-- @desc defines draw behavior.
-- @see Drawable
local DrawMixin = {}

function DrawMixin:initDraw()
	if not self.style.drawFn then
		self.style.drawFn = self.defaultDraw
	end
end

-- @function DrawMixin:setDrawFn
-- @desc Specifies a custom draw function. The needs of draw functions for any
-- given control are pretty varied, so for any control you'd like to override
-- the draw function for, A good start would be to copy-paste the existing
-- defaultDraw() function for that control type and modify it from there.
-- @param drawFn
-- @return self
function DrawMixin:setDrawFn(drawFn)
	self.style.drawFn = drawFn
	return self
end

function DrawMixin:draw()
	local x, y, w, h = self.style.box:getAABB()
	self:applyMask()
	self.style.drawFn(self, x, y, w, h)
	love.graphics.setScissor()
end

-- @function DrawMixin:defaultDraw
-- @desc All controls specify a defaultDraw function for diagnostic and example
-- purposes. For your own applications, custom draw implementations can provide
-- more complex and visually appealing results.
-- @param x
-- @param y
-- @param w
-- @param h
function DrawMixin:defaultDraw(x, y, w, h)
end
--}}}

--{{{ RectMixin

-- @class RectMixin
-- @desc controls with a RectMixin have a rectangle bounding box and
-- participate in the anchor layout system. As a general rule, if you can
-- call a method with a Rect, you can call that same method on a RectMixin
-- control, and use them interchangably.
-- @see Rect
local RectMixin = {}

function RectMixin:initRect()
	self.style.box = Rect.new()
end

-- @function RectMixin:setMask
-- @desc masked controls will only draw within the confines of the given mask.
-- This is implemented internally using `love.graphics.intersectScissor()`.
-- @param mask The mask Rect or RectMixin object. Set to nil to unset mask.
function RectMixin:setMask(mask)
	self.style.maskRect = mask
	return self
end

function RectMixin:applyMask()
	if self.style.maskRect then
		local x, y, w, h = self.style.maskRect:getAABB()
		love.graphics.intersectScissor(x, y, w, h)
	end
end

-- @function RectMixin:isInside
-- @desc returns true when the given position is inside the control's rectangle.
-- @param x in viewport units
-- @param y in viewport units
function RectMixin:isInside(x, y)
	if self.style.maskRect and not self.style.maskRect:isInside(x, y) then
		return false
	end
	return self.style.box:isInside(x, y)
end

local boxForwards = {
	'setAlign',
	'setDimensions',
	'getDimensions',
	'getAABB',

	-- axis independent
	'getAxisSize',
	'setAxisSize',
	'axisBegin',
	'axisEnd',
	'axisCenter',

	-- X
	'left',
	'right',
	'centerX',
	'setWidth',
	'getWidth',

	-- Y
	'top',
	'bottom',
	'centerY',
	'setHeight',
	'getHeight',
}

for _, name in ipairs(boxForwards) do
	RectMixin[name] = function(control, ...)
		local box = control.style.box
		return box[name](box, ...)
	end
end
--}}}

--{{{ TextObjectMixin
local TextObjectMixin = {_overrides=set{"setWidth", "setHeight"}}

-- @class TextObjectMixin
-- @desc TextObjectMixin controls can display text.
-- By default, objects with a textObjectMixin will default to having a floating
-- size. this means they will automatically resize to fit the text provided.
-- You can also have them automatically resize to fit a specific number of
-- lines, or have their width be fixed and grow downwards to compensate. Line
-- wrapping is automatically supported, just specify a fixed width.
-- @see Label
function TextObjectMixin:initTextObject(text, textSize, font)
	font = font or self.context:getDefaultFont()

	self.style.font = font
	self.style.textSize = textSize or font:getDefaultTextSize()
	self.style.textAlignX = 'left'
	self.style.textAlignY = 'top'
	self.style.dynamicHeight = {type="floatingSize"}

	self.textObject = font:newText()
	self.needsRecompute = false
	self.desiredWidth = -1
	self.desiredHeight = -1
	self.lastComputedWidth = nil

	-- this way editbox can hide setText
	TextObjectMixin.setText(self, text)
end

-- @function TextObjectMixin:setText
-- @param text
-- @return self
function TextObjectMixin:setText(text)
	if text ~= self.style.text then
		self.style.text = text
		self.needsRecompute = true
	end
	return self
end

-- @function TextObjectMixin:getText
-- @return text
function TextObjectMixin:getText()
	return self.style.text
end

-- @function TextObjectMixin:setTextSize
-- @param textSize
-- @return self
function TextObjectMixin:setTextSize(textSize)
	if textSize ~= self.style.textSize then
		self.style.textSize = textSize
		self.needsRecompute = true
	end
	return self
end

-- @function TextObjectMixin:setTextAlign
-- @desc Sets the text alignment within the control's bounding rectangle. This
-- is independent of the rectangle itself, so for example, you could have a
-- rectangle that's right-aligned to the screen, and have the text inside it be
-- left or center aligned to that rectangle.
-- @param textAlignX (default 'left')
-- @param textAlignY (default 'top')
-- @return self

-- @enum TextAlignX
-- @value "left"
-- @value "center"
-- @value "right"

-- @enum TextAlignY
-- @value "top"
-- @value "center"
-- @value "bottom"
function TextObjectMixin:setTextAlign(alignX, alignY)
	alignX = alignX or 'left'
	alignY = alignY or 'top'

	if alignX ~= self.style.textAlignX then
		self.style.textAlignX = alignX
		self.needsRecompute = true
	end

	if alignY ~= self.style.textAlignY then
		self.style.textAlignY = alignY
		-- align Y is only computed in draw()
	end
	return self
end

-- @function TextObjectMixin:setFont
-- @param font The `Hanker.Font` object.
-- @return self
function TextObjectMixin:setFont(font)
	if font ~= self.style.font then
		self.style.font = font
		self.textObject = self.style.font:newText()
		self.needsRecompute = true
	end
	return self
end

-- @function TextObjectMixin:UseFloatingHeight
-- @desc when called, this control will automatically set its height to fit all
-- the text it needs to display. This means that text that goes beyond your
-- specified width will wrap and grow downwards instead of out. You can undo
-- this by using `control:setHeight()`.
-- @return self
function TextObjectMixin:useFloatingHeight()
	if self.style.dynamicHeight.type ~= "floatHeight" then
		self.style.dynamicHeight.type = "floatHeight"
		self.needsRecompute = true
	end
	return self
end

-- @function TextObjectMixin:UseFloatingSize
-- @desc when called, this control will automatically set its size to fit all
-- the text it needs to display. You can undo this by using
-- `control:setHeight()` or `control:setWidth()`
-- @return self
function TextObjectMixin:useFloatingSize()
	if self.style.dynamicHeight.type ~= "floatSize" then
		self.style.dynamicHeight.type = "floatSize"
		self.needsRecompute = true
	end
	return self
end

-- Overrides RectMixin
function TextObjectMixin:setHeight(height)
	self.style.dynamicHeight.type = "none"
	self.style.box:setHeight(height)
	-- changing height does not affect wrap so we don't need to recompute
	return self
end

-- Overrides RectMixin
function TextObjectMixin:setWidth(width)
	if self.style.dynamicHeight.type == "floatSize" then
		self:useFloatingHeight()
	end
	self.style.box:setWidth(width)
	self.needsRecompute = true
	return self
end

-- @function TextObjectMixin:setHeightLines
-- @desc Automatically sets the height of the control to fit `numLines` worth
-- of text.
-- @param numLines
-- @return self
function TextObjectMixin:setHeightLines(numLines)
	if self.style.dynamicHeight.type ~= "lines" then
		self.style.dynamicHeight.type = "lines"
		self.style.dynamicHeight.numLines = numLines
		self.needsRecompute = true
	end
	return self
end

function TextObjectMixin:getTextWidth()
	return self.style.font:getTextWidth(self.style.text, self.style.textSize)
end

function TextObjectMixin:reflowText()
	local wrap = self.style.box:getWidth()
	local dynamicHeight = self.style.dynamicHeight
	if dynamicHeight.type == "floatSize" then
		wrap = nil
	end

	self.lastComputedWidth,
	self.desiredWidth,
	self.desiredHeight
	= self.style.font:setf(
		self.textObject,
		self.style.text,
		wrap,
		self.style.textSize,
		self.style.textAlignX
	)

	if dynamicHeight.type == "floatSize" then
		self.style.box:setWidth(self.desiredWidth)
		self.style.box:setWidth(self.desiredHeight)
	elseif dynamicHeight.type == "floatHeight" then
		self.style.box:setHeight(self.desiredHeight)
	elseif dynamicHeight.type == "lines" then
		local heightPerLine = self.style.font:getTextHeight(self.style.textSize)
		self.style.box:setHeight(dynamicHeight.numLines * heightPerLine)
	end
end

-- @function TextObjectMixin:drawText
-- @desc Draw current text within the provided bounding box
-- @see DrawMixin:setDrawFn
-- @param x
-- @param y
-- @param w
-- @param h
function TextObjectMixin:drawText(x, y, w, h)
	local sx, sy, sw, sh = love.graphics.getScissor()
	love.graphics.intersectScissor(x, y, w, h)

	-- TODO: move label scissoring into here
	if self.style.textAlignY == 'bottom' then
		y = y + h - self.desiredHeight
	elseif self.style.textAlignY == 'center' then
		y = y + (h * .5) - (self.desiredHeight * .5)
	end
	self.style.font:draw(self.textObject, x, y, self.style.textSize)

	love.graphics.setScissor(sx, sy, sw, sh)
end

--}}}

-- {{{ ClickMixin

-- @class ClickMixin
-- @desc ClickMixin controls can be clicked and selected. They provide the
-- "button" behavior in the Button control.

local ClickMixin = {}

function ClickMixin:initClick()
	self:resetClickState()
	self.context.clickables[self] = true
end

function ClickMixin:resetClickState()
	self.pressed  = false
	self.clicked  = false
	self.selected = false
	self.over     = false
end

function ClickMixin:computeClickState()
	local mx, my = self.context.mouseX, self.context.mouseY
	self.over = self:isInside(mx, my)
end

function ClickMixin:onUpdate()
	self.clicked = false
	self.doubleClicked = false
end

function ClickMixin:onPress(mx, my, _)
	if self:isInside(mx, my) then
		self.pressed = true
	end
end

function ClickMixin:onRelease(mx, my, _)
	if self.pressed and self:isInside(mx, my) then
		self:registerClick()
	end
	self.pressed = false
end

function ClickMixin:setPressed(pressed)
	self.pressed = pressed
	return self
end

-- @function ClickMixin:isPressed
-- @desc Returns true when this control is being currently pressed down.
-- @return isPressed
function ClickMixin:isPressed()
	return self.pressed
end

-- @function ClickMixin:setClicked
-- @desc Sets this current control's state to clicked. this can be used to emulate mouseclicks.
-- @param clicked
function ClickMixin:setClicked(clicked)
	if clicked then
		self.pressed = false
		self:registerClick()
	else
		self.clicked = false
	end
	return self
end

function ClickMixin:registerClick()
	self.clicked = true
	local now = love.timer.getTime()
	if self.lastClicked and now - self.lastClicked < .5 then
		self.doubleClicked = true
		self.lastClicked = nil
	else
		self.lastClicked = now
	end
end

-- @function ClickMixin:isClicked
-- @desc A control will be clicked when a player has decided to interact with
-- this object. When using a mouse, this means a player has pressed and
-- released mouse1 over this control, but it can come from other sources too.
-- @return clicked
function ClickMixin:isClicked()
	return self.clicked
end

-- @function ClickMixin:isDoubleClicked
-- @desc A control will be double-clicked when the player has clicked within
-- 500 ms of a previous single click. A double click will also register as a single click.
-- @return clicked
function ClickMixin:isDoubleClicked()
	return self.doubleClicked
end

function ClickMixin:setSelected(selected)
	self.selected = selected
	return self
end

-- @function ClickMixin:isSelected
-- @desc A control can be selected, which really should be "focused". it
-- means that a Cursor has it as the active element.
-- @see Cursor
function ClickMixin:isSelected()
	return self.selected
end

-- @function ClickMixin:isOver
-- @desc Is true if a mouse is currently over this control.
-- @return isOver
function ClickMixin:isOver()
	return self.over
end

-- }}}

-- {{{ ScrollMixin
-- @class ScrollMixin
-- @desc ScrollMixin controls can be scrolled along one dimension.

local ScrollMixin = {}

function ScrollMixin:initScroll(axis)
	self.axis = axis or 'y'

	self.offset = 0
	self.content = Rect.new()
	self:offsetAnchor():setRelative(self:axisBegin(self.axis), -self.offset)

	local cAxis = util.swapAxis(self.axis)
	self.content:axisBegin(cAxis):setRelative(self:axisBegin(cAxis))
	self.content:axisEnd(cAxis):setRelative(self:axisEnd(cAxis))

	self.startOffset = 0
	self.targetOffset = 0
	self.startTime = 0
	self.targetTime = 0

	self.clampMin = true
	self.clampMax = true

	self.context.scrollLists[self] = true
end

function ScrollMixin:resetScrollState()
	self.offset = 0

	self.startOffset = 0
	self.targetOffset = 0
	self.startTime = 0
	self.targetTime = 0
end

function ScrollMixin:scrollOnUpdate(dt)
	if self.targetTime > self.context.time then
		local time = self.context.time - self.startTime
		local change = self.targetOffset - self.startOffset
		local duration = self.targetTime - self.startTime
		self.offset = util.outExpo(time, self.startOffset, change, duration)
	else
		self.offset = self.targetOffset
	end
	self:offsetAnchor():setRelative(self:axisBegin(self.axis), -self.offset)
end

function ScrollMixin:offsetAnchor()
	return self.content[self.axis].beginAnchor
end

-- @function ScrollMixin:getScrollOffset
-- @desc Get the scroll area offset along the scroll axis. This will be 0 at the top/left of the page and grow as you scroll down/right.
-- @return scrollOffset in Anchor units
function ScrollMixin:getScrollOffset()
	return self.offset
end

-- @function ScrollMixin:getViewScrollSize
-- @desc Returns the size of the scroll list control along the scroll axis.
-- @return viewScrollSize in Anchor units.
function ScrollMixin:getViewScrollSize()
	return self:getAxisSize(self.axis)
end

function ScrollMixin:setContentScrollSize(size)
	self.content:setAxisSize(self.axis, size)
end

-- @function ScrollMixin:getTotalScrollSize
-- @desc Returns the size of the entire list including offscreen entries.
-- @return totalScrollSize in Anchor units.
function ScrollMixin:getTotalScrollSize()
	return self.content:getAxisSize(self.axis)
end

-- @function ScrollMixin:getMaxScrollOffset
-- @desc Returns the scroll offset needed to line up the last entry with the
-- bottom of the scroll list. When `shouldClampMax` is set, this will be the
-- max possible offset.
-- @return maxScrollOffset in Anchor units.
function ScrollMixin:getMaxScrollOffset()
	return self:getTotalScrollSize() - self:getViewScrollSize()
end

-- @function ScrollMixin:setShouldClamp
-- @desc Sets clamp points for the control.
-- @see ScrollList:scroll
-- @see ScrollList:getMaxScrollOffset
-- @param clampMin when true, list offset will never go below 0.
-- @param clampMax when true, list offset will never go above `getMaxScrollOffset()`.
-- @return self
function ScrollMixin:setShouldClamp(clampMin, clampMax)
	if clampMin ~= nil then self.clampMin = clampMin end
	if clampMax ~= nil then self.clampMax = clampMax end
	return self
end

-- @function ScrollMixin:scroll
-- @desc scrolls this control to the given offset.
-- @param offset the target offset along the scroll axis. Measured in Anchor units.
-- @param instantly When set, immediately jump to the given offset. Otherwise, animate smoothly toward it.
-- @return self
function ScrollMixin:scroll(offset, instantly)
	if self.clampMin then
		offset = math.max(offset, 0)
	end

	if self.clampMax then
		offset = math.min(offset, self:getMaxScrollOffset())
	end

	if instantly then
		self.targetOffset = offset
		self.targetTime = 0
	else
		self.startOffset = self.offset
		self.startTime = self.context.time
		self.targetOffset = offset
		self.targetTime = self.startTime + .4
	end

	return self
end

ScrollMixin.minDistanceToEdge = 30
function ScrollMixin:scrollOffsetValueIntoView(offset, instantly)
	local edge = self.minDistanceToEdge
	local viewSize = self:getAxisSize(self.axis)
	local cellSize = self:getCellScrollSize()
	local topOfView = self.offset + edge
	local bottomOfView = self.offset - cellSize + viewSize - edge

	if offset < topOfView then
		-- all the signs are negated
		offset = offset - edge
		return self:scroll(offset, instantly)
	elseif offset > bottomOfView then
		-- all the signs are negated
		offset = offset + cellSize - viewSize + edge
		return self:scroll(offset, instantly)
	end
end

ScrollMixin.offsetPerScrollUnit = 10
function ScrollMixin:scrollOnWheelMove(scrollx, scrolly)
	local mx, my = self.context.mouseX, self.context.mouseY
	if self:isInside(mx, my) then
		if self.axis == 'x' then
			scrolly = -scrolly
		end
		self:scroll(self.targetOffset - (scrolly * self.offsetPerScrollUnit))
	end
end
-- }}}

-- {{{ Drawable
local Drawable = Controls.newControlType("Drawable")
Controls.Drawable = Drawable
mixin(Drawable, RectMixin)
mixin(Drawable, DrawMixin)
-- @class Drawable
-- @desc Provides an empty control that you can specify a custom draw function
-- for. This can be used for anything, including images/videos or other visual
-- elements
-- @see Control
-- @see RectMixin
-- @see DrawMixin
-- @see DrawMixin:setDrawFn
-- @usage
-- local image = love.graphics.newImage("image.png")
-- local myDrawable = Hanker.newDrawable(function(x, y, w, h)
--     local sx = image:getWidth() / w
--     local sy = image:getHeight() / h
--     love.graphics.draw(image, x, y, 0, sx, sy)
-- end)
-- myDrawable:setDimensions(image:getDimensions())

-- @function Context:newDrawable
-- @param drawFn (default nil) The custom drawfn. if no draw fn is provided, a colored square will be drawn
-- @return drawable
function Drawable:init(drawFn)
	self:initRect()
	self:setDrawFn(drawFn)
	self:initDraw()
end

function Drawable:defaultDraw(x, y, w, h)
	-- Places a colored square on the screen
	love.graphics.setColor(.8, .8, .8)
	love.graphics.rectangle('fill', x, y, w, h)
end
--}}}

-- {{{ Container
local Container = Controls.newControlType("Container")
Controls.Container = Container
mixin(Container, RectMixin)
mixin(Container, DrawMixin)
-- TODO: are containers actually good? should they be documented as if they were actually useful?

function Container:init(childControls)
	self:initRect()
	self:initDraw()
	self.children = childControls
	self._ = self.children -- sneaky trick
	self.style.resizeToFit = false
end

function Container:resetState()
	for _, child in pairs(self.children) do
		child:resetState()
	end
end

function Container:useResizeToFit()
	self.style.resizeToFit = true
end

function Container:setWidth(width)
	self.style.resizeToFit = false
	self.style.box:setWidth(width)
	return self
end

function Container:setHeight(height)
	self.style.resizeToFit = false
	self.style.box:setHeight(height)
	return self
end

function Container:compute()
	local minX, maxX = -math.huge, math.huge
	local minY, maxY = -math.huge, math.huge
	-- TODO: this is p expensive to redo every frame
	if self.style.resizeToFit then
		for _, child in pairs(self.children) do
			local cBeginX = child:left():getValue()
			local cEndX   = child:right():getValue()
			local cBeginY = child:top():getValue()
			local cEndY   = child:bottom():getValue()
			if cBeginX < minX then minX = cBeginX end
			if cEndX < maxX   then maxX = cEndX end
			if cBeginY < minY then minY = cBeginY end
			if cEndY < maxY   then maxY = cEndY end
		end
		self.style.box:setWidth(maxY - minY)
		self.style.box:setHeight(maxX - minX)
	end
end
--}}}

-- {{{ Label
local Label = Controls.newControlType("Label")
Controls.Label = Label
mixin(Label, RectMixin)
mixin(Label, DrawMixin)
mixin(Label, TextObjectMixin)
-- @class Label
-- @desc Labels layout text within the UI.
-- @see Control
-- @see RectMixin
-- @see DrawMixin
-- @see TextObjectMixin
-- @usage
-- local myDrawable = Hanker.newDrawable("my funky label", 20, Hanker.getDefaultFont())

-- @function Context:newLabel
-- @param text the button text.
-- @param textSize the initial text size. defaults to the current love.graphics font size
-- @param font (default nil) the hanker font to use. If not specified, we will use `Context:getDefaultFont()`
-- @return label
function Label:init(text, textSize, font)
	self:initRect()
	self:initDraw()
	self:initTextObject(text, textSize, font)
end

function Label:compute()
	if not self.needsRecompute and self:getWidth() ~= self.lastComputedWidth then
		self.needsRecompute = true
	end

	if self.needsRecompute then
		self:reflowText()
		self.needsRecompute = false
	end
end

function Label:defaultDraw(x, y, w, h)
	love.graphics.setColor(1, 1, 1, 1)
	self:drawText(x, y, w, h)
end
--}}}

-- {{{ Clickable
local Clickable = Controls.newControlType("Clickable")
Controls.Clickable = Clickable
mixin(Clickable, RectMixin)
mixin(Clickable, DrawMixin)
mixin(Clickable, ClickMixin)
-- @class Clickable
-- @desc Provides a button-like clickable control with no styling. You can
-- provide a custom drawFn to create your own visuals.
-- @see Control
-- @see RectMixin
-- @see DrawMixin
-- @see TextObjectMixin
-- @see DrawMixin:setDrawFn

-- @function Context:newClickable
-- @param drawFn (default nil) The custom drawfn. if no draw fn is provided, a basic button will be drawn
-- @return clickable
function Clickable:init(drawFn)
	self:initRect()
	self:setDrawFn(drawFn)
	self:initDraw()
	self:initClick()
end

function Clickable:resetState()
	self:resetClickState()
end

function Clickable:compute(shouldHide)
	if shouldHide ~= 'hide' then
		self:computeClickState()
	end
end

function Clickable:defaultDraw(x, y, w, h)
	-- This provides a simple rectangular button that responds to player input.
	if self.pressed then
		-- This button is pressed
		love.graphics.setColor(.3, .3, .3)
	else
		love.graphics.setColor(.4, .4, .4)
	end
	love.graphics.rectangle('fill', x, y, w, h)

	if (self.over or self.selected) and not self.pressed then
		-- This button is moused over
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.setLineWidth(2)
	else
		love.graphics.setColor(.7, .7, .7, 1)
	end
	love.graphics.rectangle('line', x, y, w, h)
	love.graphics.setLineWidth(1)
end
--}}}

-- {{{ Button
local Button = Controls.newControlType("Button")
Controls.Button = Button
mixin(Button, RectMixin)
mixin(Button, DrawMixin)
mixin(Button, ClickMixin)
mixin(Button, TextObjectMixin)

-- @class Button
-- @desc Buttons are a clickable thing with some text on it. If you would like
-- to have a button with no text, check out Clickable instead.
-- @see Control
-- @see RectMixin
-- @see TextObjectMixin
-- @see ClickMixin

-- @function Context:newButton
-- @param text the button text.
-- @param textSize (default nil) the initial text size.
-- @param font (default nil) the hanker font to use.
-- @return button
function Button:init(text, textSize, font)
	self:initRect()
	self:initDraw()
	self:initTextObject(text, textSize, font)
	self:initClick()
end

function Button:resetState()
	self:resetClickState()
end

function Button:compute(shouldHide)
	if not self.needsRecompute and self.style.box:getWidth() ~= self.lastComputedWidth then
		self.needsRecompute = true
	end

	if self.needsRecompute then
		self:reflowText()
		self.needsRecompute = false
	end

	if shouldHide ~= 'hide' then
		self:computeClickState()
	end
end

function Button:defaultDraw(x, y, w, h)
	-- This provides a simple rectangular button that responds to player input.
	if self.pressed then
		-- This button is pressed
		love.graphics.setColor(.3, .3, .3)
	else
		love.graphics.setColor(.4, .4, .4)
	end
	love.graphics.rectangle('fill', x, y, w, h)

	love.graphics.setColor(1, 1, 1, 1)
	self:drawText(x, y, w, h)

	if (self.over or self.selected) and not self.pressed then
		-- This button is moused over
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.setLineWidth(2)
	else
		love.graphics.setColor(.7, .7, .7, 1)
	end
	love.graphics.rectangle('line', x, y, w, h)
	love.graphics.setLineWidth(1)
end
-- }}}

-- {{{ ScrollAreas
local ScrollArea = Controls.newControlType("ScrollArea")
Controls.ScrollArea = ScrollArea
mixin(ScrollArea, RectMixin)
mixin(ScrollArea, ScrollMixin)

-- @class ScrollArea
-- @desc Scroll Areas are like scroll lists, except you can use it with
-- controls of arbitrary different sizes. It doesn't provide any optimization
-- for controls that aren't currently visible, so only use it if Scroll Lists
-- can't do the job, and if there won't be too many controls inside the scroll
-- area.
-- @see Control
-- @see RectMixin
-- @see ScrollMixin

-- @function Context:newScrollArea
-- @param axis (default 'y') the axis to scroll along, either 'x' or 'y'. 2d scrolls are (deliberately) not supported.
function ScrollArea:init(axis)
	self:initRect()

	self:initScroll(axis or 'y')

	self.context.scrollLists[self] = true
	return self
end

function ScrollArea:resetState()
	self:resetScrollState()
end

function ScrollArea:onUpdate(dt)
	self:scrollOnUpdate(dt)
end

function ScrollArea:onWheelMove(scrollx, scrolly)
	self:scrollOnWheelMove(scrollx, scrolly)
end
-- }}}

-- {{{ ScrollLists
local ScrollList = Controls.newControlType("ScrollList")
Controls.ScrollList = ScrollList
mixin(ScrollList, RectMixin)
mixin(ScrollList, ScrollMixin)

local function updateScrollListSize(self)
	-- TODO: this is really really bad. Can we make another anchor type to
	-- handle this?
	self:setContentScrollSize(self:getNumCellsTotal() * self:getCellScrollSize())
end

-- @class ScrollList
-- @desc ScrollLists are lists of equally sized controls that can be scrolled
-- alongside one axis. Scroll lists keep a list of abstract entries, and will
-- only associate visible entries with a control, So scroll lists can have very
-- large numbers of entries without issue.
-- @see Control
-- @see RectMixin
-- @see ScrollMixin

-- @function Context:newScrollList
-- @param cellScrollSize the size of each control along the scrollable axis
-- @param initFn the constructor function for the control. the control may be a reused control from a pool, but it's your responsibility to properly clear any lingering state. params `(control, entry, entryIndex) -> ()`
-- @param axis the axis to scroll along, 'x' or 'y'. (default 'y')
-- @param entries the initial entry list. the ScrollList control will take ownership of this entry list, and you can get it back to modify using `ScrollList:updateEntries()`. (default empty list)
-- @return scrollList
function ScrollList:init(controlHeight, initFn, axis, entries)
	self:initRect()
	self:initScroll(axis or 'y')

	self.controlScrollSize = assert(controlHeight)
	self.controlScrollPadding = 0
	self.controlCounterScrollPadding = 0

	self.initFn = assert(initFn)

	self.oldActiveControls = {}
	self.activeControls = {}
	self.unusedControls = {}
	self.computedThisFrame = false
	self.needsRemap = false

	self.entries = entries or {}
	self.iteratingOverEntries = false

	self._focusAnchor = Anchor.new(self.axis, 'listFocus')
	self._focusAnchor:setRelative(self:axisCenter(self.axis))
	self.context.scrollLists[self] = true

	updateScrollListSize(self)
end

function ScrollList:resetState()
	self:resetScrollState()
end

-- @function ScrollList:getEntries
-- @desc Returns the list of entries. This should only be used in a read-only
-- context: editing the entry list directly is not a safe operation.
-- Entries can be literally anything, but they will sometimes be used as keys
-- and checked for equality, so keep that in mind.
-- @return entries
function ScrollList:getEntries()
	assert(not self.iteratingOverEntries, "collection is currently locked")
	return self.entries
end

-- @function ScrollList:updateEntries
-- @desc Change/modify the list of entries.
-- @param updateFn An updater function. You should edit the entry list from in here, and _not_ retain a reference to the entry list. params `(entryList) -> ()`.
-- @return self
function ScrollList:updateEntries(updateFn)
	assert(not self.iteratingOverEntries, "collection is currently locked")
	updateFn(self.entries)
	updateScrollListSize(self)
	self.needsRemap = true
	return self
end

local function acquireControl(self, entry, index)
	local control = self.oldActiveControls[index]
	local controlOffset = (index-1) * self:getCellScrollSize()
	local offsetAnchor = self:offsetAnchor()
	if control then
		-- reuse last control
		self.oldActiveControls[index] = nil
	elseif self.unusedControls[1] then
		-- reuse control from pool of unused
		-- FIXME: the order of operations here means you can't reuse a control
		-- if it would only be released this frame. This means that in practice
		-- _every_ list will have one or two extra controls that were created
		-- during that frame, which is unnecessary but ultimately harmless.
		control = table.remove(self.unusedControls)

		control:axisBegin(self.axis):setRelative(offsetAnchor, controlOffset)
	else
		-- create new control
		control = self.initFn(entry, index)

		control:setMask(self.style.box)
		local cAxis = util.swapAxis(self.axis)
		control:axisBegin(cAxis):setRelative(self:axisBegin(cAxis), self.controlCounterScrollPadding)
		control:axisEnd(cAxis):setRelative(self:axisEnd(cAxis), -self.controlCounterScrollPadding)

		control:setAxisSize(self.axis, self.controlScrollSize)
		control:axisBegin(self.axis):setRelative(offsetAnchor, controlOffset)
	end

	self.activeControls[index] = control
	return control
end

local function emptyControlPool(self)
	-- Well this is a bit aggressive, but you know, w/e it's okay
	assert(not self.iteratingOverEntries)
	self.unusedControls = {}
	self.activeControls = {}
	self.oldActiveControls = {}
	self.needsRemap = true
end

function ScrollList:onUpdate(dt)
	self:scrollOnUpdate(dt)
end

-- @function ScrollList:getNumCellsPerPage
-- @desc Gets the max number of control cells that can be visible at any given time.
-- @return numCellsPerPage
function ScrollList:getNumCellsPerPage()
	local viewSize = self:getAxisSize(self.axis)
	local cellSize = self:getCellScrollSize()
	return math.ceil(viewSize / cellSize)
end

-- @function ScrollList:getNumCellsTotal
-- @desc Gets the total number of cells in the list. This is the same as the number of list entries.
-- @return numCellsTotal
function ScrollList:getNumCellsTotal()
	assert(not self.iteratingOverEntries, "collection is currently locked")
	return util.len(self.entries)
end

local function startControlPoolEdit(self)
	self.activeControls,    self.oldActiveControls =
	self.oldActiveControls, self.activeControls
end

local function endControlPoolEdit(self)
	for k, control in pairs(self.oldActiveControls) do
		self.oldActiveControls[k] = nil
		table.insert(self.unusedControls, control)
	end
end

local function updateEntryToControlMapping(self)
	-- This is pretty expensive and it happens every frame.
	-- Possible fixes: dirty when height or offset changes,
	-- otherwise just call the active controls
	local viewSize = self:getAxisSize(self.axis)
	local cellSize = self:getCellScrollSize()
	local numVisibleEntries = math.ceil(viewSize / cellSize) + 2

	local startIndex = math.max(1, math.floor(self.offset / cellSize) - 1)

	self.iteratingOverEntries = true
	startControlPoolEdit(self)
	for i = startIndex, startIndex + numVisibleEntries do
		local entry = self.entries[i]
		if entry == nil then
			break
		end

		local control = acquireControl(self, entry, i)

		if control.entry ~= entry then
			control:resetState()
			-- TODO: is there a cleaner way to mark that this control is
			-- currently being used to reflect this entry?
			control.entry = entry
		end
	end
	endControlPoolEdit(self)
	self.iteratingOverEntries = false
end

function ScrollList:compute(shouldHide)
	local offset = self.offset
	local cellSize = self:getCellScrollSize()
	local viewSize = self:getAxisSize(self.axis)
	if offset ~= self.lastOffset or cellSize ~= self.lastCellSize or viewSize ~= self.lastViewSize then
		self.needsRemap = true
	end

	if self.needsRemap then
		updateEntryToControlMapping(self)
		self.lastOffset = offset
		self.lastViewSize = viewSize
		self.lastCellSize = cellSize

		self.needsRemap = false
	end

	for _, control in pairs(self.activeControls) do
		control(shouldHide)
	end

	self.computedThisFrame = true

	if self.activeCursor then
		self.activeCursor:updateSelected()
		self.activeCursor = nil
	end
end

-- @function ScrollList:setActiveCursor
-- @desc Mark the scroll list as being controlled by a ScrollListCursor.
-- @see ScrollListCursor
-- @param activeCursor the active ScrollListCursor.
-- @return self
function ScrollList:setActiveCursor(activeCursor)
	self.activeCursor = activeCursor
	return self
end

function ScrollList:getControlAt(entryIndex)
	assert(self.iteratingOverEntries == false, "controls are currently locked")
	assert(self.computedThisFrame, "you can't get a control before this is computed")
	return self.activeControls[entryIndex]
end

function ScrollList:getActiveControls()
	assert(self.iteratingOverEntries == false, "controls are currently locked")
	assert(self.computedThisFrame, "you can't get a control before this is computed")
	return self.activeControls
end

-- @function ScrollList:iterateActiveControls
-- @desc returns an iterator for each entry control in view. Use this to write per-control logic.
-- @usage
-- function updateListUI(list)
--    list()
--    for entryIndex, entryControl in pairs(list:iterateActiveControls) do
--        if entryControl:isClicked() then ... end -- your logic goes here
--    end
-- end
-- @return iterator returning `(entryIndex, entryControl)`
function ScrollList:iterateActiveControls()
	assert(self.iteratingOverEntries == false, "controls are currently locked")
	assert(self.computedThisFrame, "you can't get a control before this is computed")
	-- TODO: instead of pairs, do a numeric loop that matches the one in
	-- compute()
	return pairs(self.activeControls)
end

-- @function ScrollList:SetControlScrollSize
-- @desc Set the size of each control along the scroll axis. Every control must have the same size.
-- @param controlScrollSize in Anchor units
-- @return self
function ScrollList:setControlScrollSize(controlScrollSize)
	self.controlScrollSize = controlScrollSize
	-- old anchors are no longer valid, clear them out
	updateScrollListSize(self)
	emptyControlPool(self)
	return self
end

-- @function ScrollList:setControlPadding
-- @desc Set the amount of empty space between each entry control.
-- Along the scroll axis, this is only between controls.
-- Against the scroll axis, this applied between each list edge.
-- @param controlPaddingX in Anchor units
-- @param controlPaddingY in Anchor units
-- @return self
function ScrollList:setControlPadding(controlPaddingX, controlPaddingY)
	if self.axis == 'x' then
		self.controlScrollPadding = controlPaddingX
		self.controlCounterScrollPadding = controlPaddingY
	else
		self.controlScrollPadding = controlPaddingY
		self.controlCounterScrollPadding = controlPaddingX
	end
	-- old anchors are no longer valid, clear them out
	updateScrollListSize(self)
	emptyControlPool(self)
	return self
end

-- @function ScrollList:getCellScrollSize
-- @desc returns the total size of the cell along the scroll axis, including padding.
-- @return cellScrollSize in Anchor units.
function ScrollList:getCellScrollSize()
	return self.controlScrollSize + self.controlScrollPadding
end

-- @function ScrollList:focus
-- @desc Returns the point that should be considered the "focal point" of the
-- list. The default value of this is at the center of the list.
-- @return focus the focus anchor along the scroll axis.
function ScrollList:focus()
	return self._focusAnchor
end

-- @function ScrollList:scrollToIndex
-- @desc scroll the list such that the cell at the given index is centered at
-- the scroll focus.
-- @param entryIndex the entry index
-- @param instantly when set, immediately jump to index.
-- @return self
function ScrollList:scrollToIndex(entryIndex, instantly)
	local scrollSize = self:getCellScrollSize()
	local offset = (entryIndex-1) * scrollSize
	offset = offset - (self._focusAnchor:getValue() - self:axisBegin(self.axis):getValue()) + scrollSize * .5

	return self:scroll(offset, instantly)
end

-- @function ScrollList:scrollIndexIntoView
-- @desc If the given entry index is out of the "safe" view area, scroll it
-- into view. If it's already in view, don't do anything.
-- @param entryIndex the entry index
-- @param instantly when set, immediately jump to index.
-- @return self
function ScrollList:scrollIndexIntoView(index, instantly)
	-- TODO: refactor into using scrollOffsetValueIntoView
	local edge = self.minDistanceToEdge
	local viewSize = self:getAxisSize(self.axis)
	local cellSize = self:getCellScrollSize()
	local topOfView = self.offset + edge
	local bottomOfView = self.offset - cellSize + viewSize - edge

	local offset = (index-1) * cellSize

	if offset < topOfView then
		-- all the signs are negated
		offset = offset - edge
		return self:scroll(offset, instantly)
	elseif offset > bottomOfView then
		-- all the signs are negated
		offset = offset + cellSize - viewSize + edge
		return self:scroll(offset, instantly)
	end
end

function ScrollList:onWheelMove(scrollx, scrolly)
	self:scrollOnWheelMove(scrollx, scrolly)
end
-- }}}

-- {{{ EditBox
local EditBox = Controls.newControlType("EditBox")
Controls.EditBox = EditBox
mixin(EditBox, RectMixin)
mixin(EditBox, DrawMixin)
mixin(EditBox, ClickMixin)
mixin(EditBox, TextObjectMixin)

-- @class EditBox
-- @desc Editboxes are clickable boxes that can be used to let players input
-- text. Editboxes are primarily driven by a keyboard, but gamepad/IME users
-- can programmatically fill in an editbox as if it were a normal label, too.
-- @see Control
-- @see RectMixin
-- @see DrawMixin
-- @see ClickMixin
-- @see TextObjectMixin

-- @function Context:newEditBox
-- @param textSize (default nil) the initial text size.
-- @param font (default nil) the hanker font to use.
-- @param placeholderText (default "") specifies placeholder text.
-- @return editBox
function EditBox:init(textSize, font)
	self:initRect()
	self:initDraw()
	self.editText = ""
	self.editTextLen = 0
	self:initTextObject("", textSize, font)
	self:initClick()

	self.style.placeholderText = ""
	self.style.isPasswordMode = false
	self.style.editMargin = 4

	-- TODO: it's more common for this to be a line
	self.cursor = self.context:newLabel("|", textSize, font)
	self.cursor:setMask(self.style.box)

	self.rangeStartIndex = nil
	self.cursorIndex = 0
	self.cursorChanged = true

	self.editActive = true -- when true, typing will go into this edit box

	self.context.editBoxes[self] = true
end

function EditBox:resetState()
	self:resetClickState()
	self.editActive = false
	self.rangeStartIndex = nil
	self.cursorIndex = 0
	self.cursorChanged = true
	self:setEditText("")
end

function EditBox:compute(shouldHide)
	if self.style.box:getWidth() ~= self.lastComputedWidth then
		self.needsRecompute = true
	end

	if self.needsRecompute then
		if self.editText == "" then
			local placeholderText = self:getPlaceholderText()
			TextObjectMixin.setText(self, placeholderText)
		elseif self:isPasswordMode() then
			local asterisks = string.rep('*', self.editTextLen)
			TextObjectMixin.setText(self, asterisks)
		else
			TextObjectMixin.setText(self, self.editText)
		end
		self:reflowText()
		self.cursor:setWidth(self.style.font:getTextWidth("_", self.style.textSize))
		self.cursor:setHeightLines(1)
		self.cursorChanged = true
		self.needsRecompute = false
	end

	if shouldHide ~= 'hide' then
		self:computeClickState()
		local isPressed = self:isPressed()
		if isPressed then
			self.editActive = true
		end

		-- handle cursor changes
		if self:isDoubleClicked() then
			self:setTextRange(0, self.editTextLen)
		elseif isPressed then
			self:moveCursorToMouse(self.movingCursorStartIndex)
			self.movingCursorStartIndex = self.rangeStartIndex or self.cursorIndex
		end

		if self:isClicked() then
			self.movingCursorStartIndex = nil
		end
	end

	if self.cursorChanged then
		-- TODO: multiline support
		if self.rangeStartIndex then
			local distanceIn = 0
			if self.rangeStartIndex ~= 0 then
				local prefixOffset = utf8.offset(self.editText, self.rangeStartIndex)
				local prefix = self.style.text:sub(1, prefixOffset) -- use visual text
				distanceIn = self.style.font:getTextWidth(prefix, self.style.textSize)
			end
			self.rangeStartIndexOffset = distanceIn
		end

		local distanceIn = 0
		if self.cursorIndex ~= 0 then
			local prefixOffset = utf8.offset(self.editText, self.cursorIndex)
			local prefix = self.style.text:sub(1, prefixOffset) -- use visual text
			distanceIn = self.style.font:getTextWidth(prefix, self.style.textSize)
		end
		self.cursorIndexOffset = distanceIn
		self.cursor:left():set(self:left(), distanceIn+self.style.editMargin+2)
		self.cursor:top():set(self:top())

		self.cursorChanged = false
	end

	if shouldHide ~= 'hide' then
		if not self:isTextRangeSelected() and self.editActive and self.context.time % 1 < .5 then
			self.cursor()
		end
	end
end

function EditBox:onUpdate()
	ClickMixin.onUpdate(self)
	self.lastEditActive = self.editActive
end

function EditBox:isEditComplete()
	return not self.editActive and self.lastEditActive
end

-- @function EditBox:insertTextAtCursor
-- @param text
function EditBox:insertTextAtCursor(text)
	if self:isTextRangeSelected() then
		self:deleteText('range')
	end

	-- TODO: manipulating text in this way can cause performance issues with
	-- large strings could we use an FFI string or a love.data object instead?
	local len = utf8.len(text)
	local max = self:getCharacterLimit()

	if max and self.editTextLen + len > max then
		-- this string is too long, try to fill up the box as best we can
		-- without removing existing text
		len = max - self.editTextLen
		if len == 0 then
			-- no space for this string, so nothing we can do
			return
		end
		text = util.utf8.sub(text, 1, len)
	end

	if self.cursorIndex == 0 then
		self:setEditTextInternal(text .. self.editText)
	elseif self.cursorIndex == self.editTextLen then
		self:setEditTextInternal(self.editText .. text)
	else
		local prefixOffset = utf8.offset(self.editText, self.cursorIndex)
		local prefix = self.editText:sub(1, prefixOffset)
		local suffixOffset = utf8.offset(self.editText, self.cursorIndex + 1)
		local suffix = self.editText:sub(suffixOffset, -1)
		self:setEditTextInternal(prefix .. text .. suffix)
	end
	self:setTextRange(nil, self.cursorIndex + len)
end

local breakString = "\n\t\"\\ ,./<>?;':[]{}|!@#$%^&*()"
local breakCodepoints = {}
for char in breakString:gmatch(".") do
	breakCodepoints[utf8.codepoint(char)] = true
end
local function lastWordBoundary(text, cursorIndex)
	while cursorIndex > 0 do
		cursorIndex = cursorIndex - 1
		local offset = utf8.offset(text, cursorIndex)
		local codepoint = utf8.codepoint(text, offset)
		if breakCodepoints[codepoint] then
			return cursorIndex
		end
	end
	return cursorIndex
end

local function nextWordBoundary(text, cursorIndex, textLen)
	while cursorIndex < textLen do
		cursorIndex = cursorIndex + 1
		local offset = utf8.offset(text, cursorIndex)
		local codepoint = utf8.codepoint(text, offset)
		if breakCodepoints[codepoint] then
			return cursorIndex
		end
	end
	return cursorIndex
end

-- @function EditBox:setTextRange
-- @param rangeStartIndex. If nil, then no range is specified. if defined. it's the range start.
-- @param cursorIndex interpreted as range end when a range start is defined. ranges can be backwards.
-- @return self
function EditBox:setTextRange(rangeStartIndex, cursorIndex)
	self.cursorIndex = util.clamp(cursorIndex, 0, self.editTextLen)
	if rangeStartIndex then
		rangeStartIndex = util.clamp(rangeStartIndex, 0, self.editTextLen)
		if rangeStartIndex == self.cursorIndex then
			rangeStartIndex = nil
		end
	end
	self.rangeStartIndex = rangeStartIndex
	self.cursorChanged = true
	return self
end

-- @function EditBox:setCursorIndex
-- @param cursorIndex The position within the text string the player cursor should be placed at.
-- @return self
function EditBox:setCursorIndex(cursorIndex)
	return self:setTextRange(nil, cursorIndex)
end

-- @function EditBox:isTextRangeSelected
-- @return isSelected
function EditBox:isTextRangeSelected()
	return self.rangeStartIndex ~= nil
end

-- @function EditBox:moveCursorLeft
-- @param moveType
-- @param asRange
function EditBox:moveCursorLeft(moveType, asRange)
	local startIndex = nil
	if asRange then
		startIndex = self.rangeStartIndex or self.cursorIndex
	end

	moveType = moveType or 'character'
	if moveType == 'word' and self:isPasswordMode() then
		moveType = 'begin'
	end

	if moveType == 'character' then
		self:setTextRange(startIndex, self.cursorIndex - 1)
	elseif moveType == 'word' then
		self:setTextRange(startIndex, lastWordBoundary(self.editText, self.cursorIndex))
	elseif moveType == 'begin' then
		self:setTextRange(startIndex, 0)
	end
end

-- @function EditBox:moveCursorRight
-- @param moveType
-- @param asRange
function EditBox:moveCursorRight(moveType, asRange)
	local startIndex = nil
	if asRange then
		startIndex = self.rangeStartIndex or self.cursorIndex
	end

	moveType = moveType or 'character'
	if moveType == 'word' and self:isPasswordMode() then
		moveType = 'end'
	end

	if moveType == 'character' then
		self:setTextRange(startIndex, self.cursorIndex + 1)
	elseif moveType == 'word' then
		self:setTextRange(startIndex, nextWordBoundary(self.editText, self.cursorIndex, self.editTextLen))
	elseif moveType == 'end' then
		self:setTextRange(startIndex, self.editTextLen)
	end
end

-- @function EditBox:moveCursorToMouse
-- @param startIndex if specified, selects a range from the startIndex to the cursor.
-- @return self
function EditBox:moveCursorToMouse(startIndex)
	local x, y = self.context.mouseX, self.context.mouseY

	local rx, _, rw, _ = self.style.box:getAABB()

	x = ((x - rx) / rw) * self.style.box:getWidth() -- normalize to width
	-- TODO: this is a fairly expensive operation: we should instead use
	-- binsearch and stoe the last computed distanceIn for the current cursor
	-- position
	local newCursorIndex = self.editTextLen
	for i = 1, self.editTextLen do
		local prefixOffset = utf8.offset(self.editText, i)
		local prefix = self.style.text:sub(1, prefixOffset) -- use visual text
		local distanceIn = self.style.font:getTextWidth(prefix, self.style.textSize)
		if distanceIn > x then
			newCursorIndex = i-1
			break
		end
	end

	self:setTextRange(startIndex or newCursorIndex, newCursorIndex)
	return self
end

-- @function EditBox:deleteText
-- @param moveType
function EditBox:deleteText(moveType)
	moveType = moveType or 'character'
	if moveType == 'word' and self:isPasswordMode() then
		moveType = 'begin'
	end

	local startIndex, stopIndex
	if moveType == 'character' then
		if self.cursorIndex == 0 then
			return
		end
		startIndex, stopIndex = self.cursorIndex - 1, self.cursorIndex
	elseif moveType == 'word' then
		if self.cursorIndex == 0 then
			return
		end
		startIndex = lastWordBoundary(self.editText, self.cursorIndex)
		stopIndex = self.cursorIndex
	elseif moveType == 'begin' then
		if self.cursorIndex == 0 then
			return
		end
		startIndex, stopIndex = 0, self.cursorIndex
	elseif moveType == 'range' then
		if not self.rangeStartIndex then
			return
		end
		startIndex, stopIndex = util.sortArgs(self.rangeStartIndex, self.cursorIndex)
		if stopIndex == 0 then
			return
		end
	end

	if startIndex == 0 then
		local suffixOffset = utf8.offset(self.editText, stopIndex + 1)
		local suffix = self.editText:sub(suffixOffset, -1)
		self:setEditTextInternal(suffix)
	else
		local prefixOffset = utf8.offset(self.editText, startIndex)
		local prefix = self.editText:sub(1, prefixOffset)
		local suffixOffset = utf8.offset(self.editText, stopIndex + 1)
		local suffix = self.editText:sub(suffixOffset, -1)
		self:setEditTextInternal(prefix .. suffix)
	end
	self:setTextRange(nil, startIndex)
end

-- @function EditBox:setEditText
-- @desc replaces setText(). sets the current user-editable string within the edit box.
-- @param text
-- @return self
function EditBox:setEditText(text)
	self:setEditTextInternal(text)
	self:setTextRange(nil, self.editTextLen)
end

-- @function EditBox:setText
-- @desc with edit boxes, use setEditText instead
EditBox.setText = nil

-- @function EditBox:getEditText
-- @desc replaces getText(). returns the current user-editable string within the edit box.
-- @return editText
function EditBox:getEditText(text)
	return self.editText
end

-- @function EditBox:getText
-- @desc with edit boxes, use getEditText instead
EditBox.getText = nil

function EditBox:setEditTextInternal(text)
	if self.style.maxCodepoints then
		-- truncate if necessary
		text = text:sub(1, utf8.offset(text, self.style.maxCodepoints))
	end

	self.editText = text
	self.editTextLen = utf8.len(self.editText)
	self.needsRecompute = true
end

-- Overrides TextObjectMixin:setFont
function EditBox:setFont(font)
	self.cursor:setFont(font)
	return TextObjectMixin.setFont(self, font)
end

-- Overrides TextObjectMixin:setTextSize
function EditBox:setTextSize(textSize)
	self.cursor:setTextSize(textSize)
	return TextObjectMixin.setTextSize(self, textSize)
end

-- Overrides ClickMixin:onRelease
function EditBox:onRelease(mx, my)
	-- auto disable edit when clicking away
	if self.pressed and self:isInside(mx, my) then
		self:registerClick()
	else
		self:deactivate()
	end
	self.pressed = false
end

function EditBox:onKeyboardKeyPressed(key)
	if self.editActive then
		local ctrl = love.keyboard.isDown('lctrl', 'rctrl')
		local shift = love.keyboard.isDown('lshift', 'rshift')
		local copypaste = ctrl
		if love.system.getOS() == 'OS X' then
			copypaste = love.keyboard.isDown('lgui', 'rgui')
		end

		if key == 'backspace' or key == 'delete' then
			if self:isTextRangeSelected() then
				self:deleteText('range')
			elseif ctrl then
				self:deleteText('word')
			else
				self:deleteText('character')
			end
		elseif key == 'left' then
			self:moveCursorLeft(ctrl and 'word' or 'character', shift)
		elseif key == 'right' then
			self:moveCursorRight(ctrl and 'word' or 'character', shift)
		elseif key == 'home' then
			self:moveCursorLeft('begin')
		elseif key == 'end' then
			self:moveCursorRight('end')
		elseif ctrl and key == 'a' then
			self:setTextRange(0, self.editTextLen)
		elseif copypaste and key == 'x' then
			self:cutClipboard()
		elseif copypaste and key == 'c' then
			self:copyClipboard()
		elseif copypaste and key == 'v' then
			self:pasteClipboard()
		elseif key == 'return' or key == 'escape' then
			self:deactivate()
		end
		return true
	end
end

function EditBox:cutClipboard()
	if self:isTextRangeSelected() and not self:isPasswordMode() then
		self:copyClipboard()
		self:deleteText('range')
	end
end

function EditBox:copyClipboard()
	if self:isTextRangeSelected() and not self:isPasswordMode() then
		local startIndex, stopIndex = util.sortArgs(self.rangeStartIndex, self.cursorIndex)
		local text = util.utf8.sub(self.editText, startIndex, stopIndex)
		love.system.setClipboardText(text)
	end
end

function EditBox:pasteClipboard()
	self:insertTextAtCursor(love.system.getClipboardText())
end

function EditBox:deactivate()
	self.editActive = false
	self:setTextRange(nil, self.editTextLen)
end

function EditBox:onTextInput(text)
	if self.editActive then
		self:insertTextAtCursor(text)
	end
end

-- @function EditBox:setEditMargin
-- @param editMargin the margin, in UI units, to place between the inner text and the control boundaries.
-- @return self
function EditBox:setEditMargin(editMargin)
	self.style.editMargin = editMargin
	self.needsRecompute = true
	return self
end

-- @function EditBox:getEditMargin
-- @return editMargin
function EditBox:getEditMargin()
	return self.style.editMargin
end

-- @function EditBox:setPlaceholderText
-- @desc Sets placeholder text. When a textbox is empty and deactivated, the
-- placeholder text will be visible instead to give users a clue to fill it in.
-- @param text
-- @return self
function EditBox:setPlaceholderText(text)
	self.style.placeholderText = text
	self.needsRecompute = true
	return self
end

-- @function EditBox:getPlaceholderText
-- @return text
function EditBox:getPlaceholderText()
	return self.style.placeholderText
end

-- @function EditBox:setCharacterLimit
-- @param maxCodepoints (nil for unlimited)
-- @return self
function EditBox:setCharacterLimit(maxCodepoints)
	self.style.maxCodepoints = maxCodepoints
	self:setEditText(self:getEditText())
	return self
end

-- @function EditBox:getCharacterLimit
-- @return maxCodepoints (nil for unlimited)
function EditBox:getCharacterLimit()
	return self.style.maxCodepoints
end

-- @function EditBox:setPasswordMode
-- @desc sets password mode, which will replace all visible characters with asterisks.
-- @param isPasswordMode
-- @return self
function EditBox:setPasswordMode(isPasswordMode)
	self.style.isPasswordMode = isPasswordMode
	self.needsRecompute = true
	return self
end

-- @function EditBox:isPasswordMode
-- @return isPasswordMode
function EditBox:isPasswordMode()
	return self.style.isPasswordMode
end

function EditBox:defaultDraw(x, y, w, h)
	if self.pressed or self.editActive then
		love.graphics.setColor(.1, .1, .1, 1)
	else
		love.graphics.setColor(.2, .2, .2, 1)
	end
	love.graphics.rectangle('fill', x, y, w, h)

	local editMargin = self:getEditMargin()
	-- highlight
	if self.rangeStartIndex then
		love.graphics.setColor(.2, .2, .4)
		local startx = x + self.rangeStartIndexOffset + editMargin
		local endx = x + self.cursorIndexOffset + editMargin
		love.graphics.rectangle('fill', startx, y, endx-startx, h)
	end

	if self:getEditText() ~= "" then
		-- draw real text
		love.graphics.setColor(1, 1, 1, 1)
		self:drawText(x+editMargin, y, w-(editMargin*2), h)
	elseif not self.editActive then
		-- draw placeholder text
		love.graphics.setColor(.4, .4, .4, 1)
		self:drawText(x+editMargin, y, w-(editMargin*2), h)
	end

	if self.editActive then
		love.graphics.setColor(.6, .6, .9, 1)
	elseif self.selected then
		love.graphics.setColor(.5, .5, .9, 1)
	elseif self.over and not self.pressed then
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.setLineWidth(2)
	else
		love.graphics.setColor(.7, .7, .7, 1)
	end
	love.graphics.rectangle('line', x, y, w, h)
	love.graphics.setLineWidth(1)
end
-- }}}

return Controls
