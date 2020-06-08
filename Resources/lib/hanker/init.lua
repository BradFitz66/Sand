-- @module Hanker
-- @desc The main entry point of Hanker. Most Context functions can be called
-- on Hanker directly like so:
-- ```
-- Hanker.newContext():newButton()
-- -- Can be translated to
-- Hanker.newButton()
-- ```
-- @see Context

local Hanker = {}
local Context = require 'Resources.lib.hanker.context'

Hanker.defaultContext = Context.new()

for k, v in pairs(Context) do
	if type(v) == 'function' and k ~= 'new' then
		Hanker[k] = function(...)
			return v(Hanker.defaultContext, ...)
		end
	end
end

-- @function Hanker.newContext
-- @return context
function Hanker.newContext()
	return Context.new()
end

local Anchor = require 'Resources.lib.hanker.anchor'

-- @function Hanker.setViewport
-- @return context
function Hanker.setViewport(x, y, w, h)
	return Anchor.SetViewport(x, y, w, h)
end

-- @function Hanker.setUnscaledDimensions
-- @return context
function Hanker.setUnscaledDimensions(w, h)
	return Anchor.SetUnscaledDimensions(w, h)
end

-- @field LEFT The leftmost point of the viewport
Hanker.LEFT    = Anchor.LEFT
-- @field RIGHT The rightmost point of the viewport
Hanker.RIGHT   = Anchor.RIGHT
--
-- @field TOP The top of the viewport
Hanker.TOP     = Anchor.TOP
-- @field BOTTOM The bottom of the viewport
Hanker.BOTTOM  = Anchor.BOTTOM

-- @field CENTERX The center of the viewport along the X axis.
Hanker.CENTERX = Anchor.CENTERX
-- @field CENTERY The center of the viewport along the Y axis.
Hanker.CENTERY = Anchor.CENTERY

return Hanker
