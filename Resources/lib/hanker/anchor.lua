local util = require 'Resources.lib.hanker.util'

-- @enum AnchorAxis
-- @value x
-- @value y

-- @class Anchor
-- @desc the building block of UI layout. Layout Rects are defined as a
-- collection of anchor points, which can anchored absolutely, to other
-- Rects, etc.
local Anchor = {}
local Anchor_mt = {__index = Anchor}

Anchor.anchorType = {
	'none',
	'absolute',
	'relative',
	'lerp',
	'size',
}

function Anchor.new(axis, debugName)
	assert(axis)
	return setmetatable({
		axis = axis,
		debugName = debugName,
		type='none',
	}, Anchor_mt)
end

Anchor.growDirections = {
	-- in the positive direction, toward 'end'
	'out',
	'halfout',
	-- in the negative direction, toward 'begin'
	'in',
	'halfin',
}
local growMultipliers = {
	out = 1,
	halfout = .5,
	['in'] = -1,
	halfin = -.5,
}
local function evalSize(size, growDirection)
	local growMultiplier = growMultipliers[growDirection]
	return size * growMultiplier
end

-- @function Anchor:getValue
-- @desc Return this anchor's current value
-- @return value in Anchor units
function Anchor:getValue()
	--if self.cachedValue then
	--	return self.cachedValue
	--end

	-- TODO: implement caching and dirty flags

	-- the core problem here is that each node in a relative tree will
	-- calculate every node above it, which means that nodes closer to the top
	-- of the tree will be recalculated over and over and over again. Because
	-- right now the math is pretty simple, this doesn't have a huge impact,
	-- but on very large trees this will probably be noticable. A good
	-- reference example are browser layout engines, which work in an
	-- incremental top-down manner.
	if self.type == 'none' then
		error('anchor unset')
	elseif self.type == 'absolute' then
		self.cachedValue = self.value
	elseif self.type == 'relative' then
		self.cachedValue = self.parentAnchor:getValue() + self.offset
	elseif self.type == 'lerp' then
		local b, e = self.beginAnchor, self.endAnchor
		self.cachedValue = util.lerp(b:getValue(), e:getValue(), self.value)
	elseif self.type == 'size' then
		local size = self.parentRect[self.axis].size
		self.cachedValue = self.parentAnchor:getValue() + evalSize(size, self.growDirection)
	else
		error('invalid anchor')
	end

	return self.cachedValue
end

-- @function Anchor:getViewportValue
-- @desc Returns value normalized to the current viewport. Viewport values are
-- what you ultimately get when we actually draw or compare control sizes
-- to the  mouse.
--
-- @return value in Viewport units.
function Anchor:getViewportValue()
	return Anchor.UnscaledToViewportValue(self.axis, self:getValue())
end

-- @function Anchor:getAxis
-- @return axis either "x" or "y"
function Anchor:getAxis()
	return self.axis
end

local anchorFields = {
	"value",
	"parentAnchor",
	"offset",
	"beginAnchor",
	"endAnchor",
	"rect",
	"growDirection",
}
function Anchor:clear()
	self.type = 'none'
	for _, k in ipairs(anchorFields) do
		self[k] = nil
	end
end

-- @funciton Anchor:copyFrom
-- @desc Set Anchor to use the same settings as the provided anchor.
-- @param otherAnchor another anchor on the same axis as this one.
-- @return self
function Anchor:copyFrom(otherAnchor)
	assert(otherAnchor:getAxis() == self.axis)
	self.type = otherAnchor.type
	for _, k in ipairs(anchorFields) do
		self[k] = otherAnchor[k]
	end
	return self
end

-- @function Anchor:setAbsolute
-- @desc Set Anchor to an absolute value.
-- @param value the value this anchor should return. In Anchor units.
-- @return self
function Anchor:setAbsolute(value)
	self:clear()
	self.type = 'absolute'
	self.value = value
	return self
end

-- @function Anchor:setRelative
-- @desc Set Anchor relative to another anchor plus or minus a fixed offset.
-- This means when the parent anchor changes, so will this one.
-- @param parentAnchor another anchor on the same axis.
-- @param offset a fixed offset from the parent anchor. In Anchor units.
-- @return self
function Anchor:setRelative(parentAnchor, offset)
	assert(parentAnchor:getAxis() == self.axis)
	self:clear()
	self.type = 'relative'
	self.parentAnchor = parentAnchor
	self.offset = offset or 0
	return self
end

-- @function Anchor:set
-- @desc alias for [Anchor:setRelative()](#anchorsetrelative)
-- @param parentAnchor another anchor on the same axis.
-- @param offset a fixed offset from the parent anchor. In Anchor units.
-- @return self
Anchor.set = Anchor.setRelative

-- @function Anchor:setLerp
-- @desc Set anchor between two different anchors along the same axis.
-- A value of 0 places this anchor at `beginAnchor`.
-- A value of 1 places this anchor at `endAnchor`.
-- @param beginAnchor the first parent anchor
-- @param endAnchor the second parent anchor
-- @param value the lerp fraction between the two anchors.
-- @return self
function Anchor:setLerp(beginAnchor, endAnchor, value)
	assert(beginAnchor:getAxis() == self.axis)
	assert(endAnchor:getAxis() == self.axis)
	self:clear()
	self.type = 'lerp'
	self.beginAnchor = beginAnchor
	self.endAnchor = endAnchor
	self.value = value
	return self
end

-- Set anchor to match a given rect's size. Internal only.
function Anchor:setSize(rect, anchorName, growDirection)
	self:clear()
	self.type = 'size'
	self.parentRect = rect
	self.parentAnchor = rect[self.axis][anchorName]
	self.growDirection = growDirection
	return self
end

-- TODO: pull all this stuff out into hanker.state, then make that work the way you expect
Anchor.UnscaledToViewportValue = function(axis, value)
	if axis == 'x' then
		return value * Anchor.xMultiplier + Anchor.xOffset
	elseif axis == 'y' then
		return value * Anchor.yMultiplier + Anchor.yOffset
	end
end

Anchor.UnscaledSizeToViewportSize = function(axis, size)
	if axis == 'x' then
		return size * Anchor.xMultiplier
	elseif axis == 'y' then
		return size * Anchor.yMultiplier
	end
end

--- Set the target viewport. Mouse and Draw coordinates are measured in
-- viewport units.
Anchor.SetViewport = function(x, y, w, h)
	local targetW = Anchor.RIGHT:getValue()
	local targetH = Anchor.BOTTOM:getValue()

	local scale = math.min(w/targetW, h/targetH)
	Anchor.xMultiplier = scale
	Anchor.xOffset = (w * .5) - (targetW * scale * .5) + x
	Anchor.yMultiplier = scale
	Anchor.yOffset = (h * .5) - (targetH * scale * .5) + y

	Anchor.viewportX = x
	Anchor.viewportY = y
	Anchor.viewportW = w
	Anchor.viewportH = h
end

Anchor.SetUnscaledDimensions = function(w, h)
	Anchor.TOP:setAbsolute(0)
	Anchor.LEFT:setAbsolute(0)
	Anchor.RIGHT:setAbsolute(w)
	Anchor.BOTTOM:setAbsolute(h)

	if Anchor.viewportX then
		Anchor.SetViewport(Anchor.viewportX, Anchor.viewportY, Anchor.viewportW, Anchor.viewportH)
	end
end

Anchor.LEFT    = Anchor.new('x'):setAbsolute(0)
Anchor.RIGHT   = Anchor.new('x'):setAbsolute(0)

Anchor.TOP     = Anchor.new('y'):setAbsolute(1)
Anchor.BOTTOM  = Anchor.new('y'):setAbsolute(1)

Anchor.CENTERX = Anchor.new('x'):setLerp(Anchor.LEFT, Anchor.RIGHT, .5)
Anchor.CENTERY = Anchor.new('y'):setLerp(Anchor.TOP, Anchor.BOTTOM, .5)

Anchor.xOffset, Anchor.xMultiplier = 0, 1
Anchor.yOffset, Anchor.yMultiplier = 0, 1

return Anchor
