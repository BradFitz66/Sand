-- luacheck: ignore
return function()
	local prof = require 'jprof'
	local Hanker = require 'hanker'

	--[[
	local _getViewportValue = Hanker.Anchor.getViewportValue
	function Hanker.Anchor:getViewportValue()
		prof.push("Anchor:getViewportValue")
		local val = _getViewportValue(self)
		prof.pop("Anchor:getViewportValue")
		return val
	end
	]]--

	for _, Control in pairs(require'hanker.controls') do
		if type(Control) == 'table' and Control.ControlType then
			do
				local _draw = Control.draw
				local tag = Control.ControlType .. ":draw()"
				function Control:draw()
					prof.push(tag)
					_draw(self)
					prof.pop(tag)
				end
			end

			do
				local _compute = Control.compute
				local tag = Control.ControlType .. ":compute()"
				function Control:compute(shouldHide)
					prof.push(tag)
					_compute(self, shouldHide)
					prof.pop(tag)
				end
			end

			if Control.reflowText then
				do
					local _reflowText = Control.reflowText
					local tag = Control.ControlType .. ":reflowText()"
					function Control:reflowText(shouldHide)
						prof.push(tag)
						_reflowText(self, shouldHide)
						prof.pop(tag)
					end
				end
			end

			--[[
			do
				local _getAABB = Control.compute
				local tag = Control.ControlType .. ":getAABB()"
				function Control:getAABB()
					prof.push(tag)
					local x, y, w, h = _getAABB(self)
					prof.pop(tag)
					return x, y, w, h
				end
			end
			]]--
		end
	end

	local Rect = require 'hanker.rect'
	--[[
	do
		local _getAABB = Rect.getAABB
		local tag = "Rect:getAABB()"
		function Rect:getAABB()
			prof.push(tag)
			local x, y, w, h = _getAABB(self)
			prof.pop(tag)
			return x, y, w, h
		end
	end
	]]--
end
