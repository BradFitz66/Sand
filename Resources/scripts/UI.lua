local UI={}
UI.__index=UI
local suit = require 'Resources.lib.suit'

local TWOPI = math.pi * 2

local function idk(t, length)
    return t - math.floor(t/length) * length
end

local function lerpAngle(a, b, t)
    local num = idk(b-a, TWOPI)
    if num > math.pi then
        num = num - TWOPI
    end
    return a + num * t
end

function UI.load()
    local UI=setmetatable({}, UI)
    UI.buttons = { }

	for i=0, 7 do
		local btn = suit.Label("Hello, "..input.text, {align = "left"}, suit.layout:row())
        table.insert(UI.buttons, btn)
    end


end

function UI:draw()
    Hanker.draw()
end

local rot
local targetRot = 0
local lastSelectedControl
function UI:update(dt)
    local buttons=self.buttons
    local info=self.info


	for i, btn in ipairs(buttons) do
		if cursor:getSelectedControl() == btn then
			targetRot = -(math.pi*(i+2)/4)
			if rot == nil then rot = targetRot end
		end
	end

	-- ghetto quadout tween
	rot = lerpAngle(rot, targetRot, dt*10)

	for i, btn in ipairs(buttons) do
	end
end

return UI
