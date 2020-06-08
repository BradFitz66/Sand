local util = require 'Resources.lib.hanker.util'
local Anchor = require 'Resources.lib.hanker.anchor'

local Rect = {}
local Rect_mt = {__index = Rect}

-- @class Rect
-- @desc A rect represents a rectangle in 2d space.
function Rect.new()
	local self = setmetatable({
		x = {},
		y = {},
	}, Rect_mt)

	self.x.beginAnchor  = Anchor.new('x', 'left'):setRelative(Anchor.LEFT)
	self.x.endAnchor    = Anchor.new('x', 'right')
	self.x.centerAnchor = Anchor.new('x', 'centerX')
	self.x.size = 0
	self.x.align = 'left'

	self.y.beginAnchor  = Anchor.new('y', 'top'):setRelative(Anchor.TOP)
	self.y.endAnchor    = Anchor.new('y', 'bottom')
	self.y.centerAnchor = Anchor.new('y', 'centerY')
	self.y.size = 0
	self.y.align = 'top'

	-- calling setAlign will reset sizeAnchors to point to the current rect
	self:setAlign('left', 'top')

	return self
end

function Rect:copyFrom(other)
	self.x.beginAnchor:copyFrom(other.x.beginAnchor)
	self.x.centerAnchor:copyFrom(other.x.centerAnchor)
	self.x.endAnchor:copyFrom(other.x.endAnchor)
	self.x.size = other.x.size
	self.x.align = other.x.align

	self.y.beginAnchor:copyFrom(other.y.beginAnchor)
	self.y.centerAnchor:copyFrom(other.y.centerAnchor)
	self.y.endAnchor:copyFrom(other.y.endAnchor)
	self.y.size = other.y.size
	self.y.align = other.y.align

	-- calling setAlign will reset sizeAnchors to point to the current rect
	self:setAlign(other.x.align, other.y.align)
end


-- @function Rect:getAABB
-- @desc returns the final calculated space this rect takes up.
-- @return x, y, w, h in viewport units
function Rect:getAABB()
	local leftX = self:left():getViewportValue()
	local rightX = self:right():getViewportValue()
	local topY = self:top():getViewportValue()
	local bottomY = self:bottom():getViewportValue()
	return leftX, topY, rightX - leftX, bottomY - topY
end

-- @function Rect:isInside
-- @desc performs a point-AABB hit test, in viewport units.
-- @param x
-- @param y
-- @return isInside
function Rect:isInside(x, y)
	return util.pointInsideRect(x, y, self:getAABB())
end

-- @function Rect:getAxisSize
-- @param axis the axis to measure along.
-- @return size in Anchor units
function Rect:getAxisSize(axis)
	local beginValue = self[axis].beginAnchor:getValue()
	local endValue = self[axis].endAnchor:getValue()
	return endValue - beginValue
end

-- @function Rect:getWidth
-- @return width in Anchor units
function Rect:getWidth()
	return self:getAxisSize('x')
end

-- @function Rect:getHeight
-- @return height in Anchor units
function Rect:getHeight()
	return self:getAxisSize('y')
end

-- @function Rect:getDimensions
-- @return width, height in Anchor units
function Rect:getDimensions()
	return self:getAxisSize('x'), self:getAxisSize('y')
end

-- @function Rect:setAxisSize
-- @desc directly set the size of the rect along an axis. The size can also be
-- defined by setting both the begin/end anchors of a rect, in which case this
-- is ignored.
-- @param axis the axis to set
-- @param size in Anchor units
-- @return self
function Rect:setAxisSize(axis, size)
	self[axis].size = size
	return self
end

-- @function Rect:setWidth
-- @param width in Anchor units
-- @return self
function Rect:setWidth(width)
	self.x.size = width
	return self
end

-- @function Rect:setHeight
-- @param height in Anchor units
-- @return self
function Rect:setHeight(height)
	self.y.size = height
	return self
end

-- @function Rect:setDimensions
-- @param width in Anchor units
-- @param height in Anchor units
-- @return self
function Rect:setDimensions(width, height)
	self.x.size = width
	self.y.size = height
	return self
end

-- @enum RectAlignX
-- @value left
-- @value center
-- @value right

-- @enum RectAlignY
-- @value top
-- @value center
-- @value bottom

-- @function Rect:setAlign
-- @desc sets which anchors should user-defined, and which anchors should be
-- defined by the `size` variable. By default, the top and the left anchors are
-- the alignment anchors, but for example you could set the xAlign to 'center'
-- and then se can anchor this rect from its center, and have the left and
-- right anchors grow out automatically.
-- @param xAlign either 'top', 'center', or 'bottom'
-- @param yAlign either 'left', 'center', or 'right'
-- @return self
function Rect:setAlign(xAlign, yAlign)
	-- FIXME: depending on alignment, some anchors should be user-modifiable,
	-- and others shouldn't. we should protect those anchors somehow.
	local oldXAlign, oldYAlign = self.x.align, self.y.align
	local targetAnchorX, targetAnchorY
	if oldXAlign == 'left' then
		targetAnchorX = self.x.beginAnchor
	elseif oldXAlign == 'center' then
		targetAnchorX = self.x.centerAnchor
	elseif oldXAlign == 'right' then
		targetAnchorX = self.x.endAnchor
	end

	if oldYAlign == 'top' then
		targetAnchorY = self.y.beginAnchor
	elseif oldYAlign == 'center' then
		targetAnchorY = self.y.centerAnchor
	elseif oldYAlign == 'bottom' then
		targetAnchorY = self.y.endAnchor
	end

	xAlign = xAlign or 'left'
	if xAlign == 'left' then
		self.x.beginAnchor:copyFrom(targetAnchorX)
		self.x.endAnchor:setSize(self, 'beginAnchor', 'out')
		self.x.centerAnchor:setLerp(self.x.beginAnchor, self.x.endAnchor, .5)
	elseif xAlign == 'right' then
		self.x.endAnchor:copyFrom(targetAnchorX)
		self.x.beginAnchor:setSize(self, 'endAnchor', 'in')
		self.x.centerAnchor:setLerp(self.x.beginAnchor, self.x.endAnchor, .5)
	elseif xAlign == 'center' then
		self.x.centerAnchor:copyFrom(targetAnchorX)
		self.x.beginAnchor:setSize(self, 'centerAnchor', 'halfin')
		self.x.endAnchor:setSize(self, 'centerAnchor', 'halfout')
	elseif xAlign ~= 'none' then
		error('invalid X alignment')
	end

	yAlign = yAlign or 'top'
	if yAlign == 'top' then
		self.y.beginAnchor:copyFrom(targetAnchorY)
		self.y.endAnchor:setSize(self, 'beginAnchor', 'out')
		self.y.centerAnchor:setLerp(self.y.beginAnchor, self.y.endAnchor, .5)
	elseif yAlign == 'bottom' then
		self.y.endAnchor:copyFrom(targetAnchorY)
		self.y.beginAnchor:setSize(self, 'endAnchor', 'in')
		self.y.centerAnchor:setLerp(self.y.beginAnchor, self.y.endAnchor, .5)
	elseif yAlign == 'center' then
		self.y.centerAnchor:copyFrom(targetAnchorY)
		self.y.beginAnchor:setSize(self, 'centerAnchor', 'halfin')
		self.y.endAnchor:setSize(self, 'centerAnchor', 'halfout')
	elseif yAlign ~= 'none' then
		error('invalid Y alignment')
	end

	self.x.align = xAlign
	self.y.align = yAlign
	return self
end

-- @function Rect:left
-- @return anchor
function Rect:left()
	return self.x.beginAnchor
end

-- @function Rect:right
-- @return anchor
function Rect:right()
	return self.x.endAnchor
end

-- @function Rect:centerX
-- @return anchor
function Rect:centerX()
	return self.x.centerAnchor
end

-- @function Rect:top
-- @return anchor
function Rect:top()
	return self.y.beginAnchor
end

-- @function Rect:bottom
-- @return anchor
function Rect:bottom()
	return self.y.endAnchor
end

-- @function Rect:centerY
-- @return anchor
function Rect:centerY()
	return self.y.centerAnchor
end

-- @function Rect:axisBegin
-- @param axis
-- @return anchor
function Rect:axisBegin(axis)
	return self[axis].beginAnchor
end

-- @function Rect:axisEnd
-- @param axis
-- @return anchor
function Rect:axisEnd(axis)
	return self[axis].endAnchor
end

-- @function Rect:axisCenter
-- @param axis
-- @return anchor
function Rect:axisCenter(axis)
	return self[axis].centerAnchor
end

return Rect
