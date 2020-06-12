local UI={}
UI.__index=UI
u = require "Resources.lib.urutora"

local TWOPI = math.pi * 2
showButtons=false
function UI.load()
    local UI=setmetatable({}, UI)
    UI.buttons = { }
    u.setResolution(love.graphics.getWidth(), love.graphics.getHeight())
    for i = 360,0,-1 do
        if(particleTypes[i])then
            local panel = u.button({text=particleTypes[i][1], x=0,y=0, w=50, h=50, rows=1, cols=1})
            panel:setStyle({bgColor={particleTypes[i][2][1]+.03,particleTypes[i][2][2]+.03,particleTypes[i][2][3]+.03},fgColor={0,0,0,1}}) -- Color the buttons using the particle color (+ a small offset because otherwise air button would be invisible)
            panel:action(function (e)  currentType=i end)
            table.insert(UI.buttons,panel)
        end
    end
    UI.showButtons=false
    return UI
end

function UI:draw()
    if self.showButtons==true then
        u.draw()
    end
end

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

local isMouseDown=love.mouse.isDown
function UI:update(dt)
    local buttons=self.buttons
    local info=self.info
    self.showButtons=showButtons
    if(self.showButtons) then
        for i=1,#buttons do
            local theta = (TWOPI*i/#particleTypes)
            local x_pos = math.cos(theta) * 120
            local y_pos = math.sin(theta) * 120
            buttons[i].x=(mx-25)+x_pos
            buttons[i].y=(my-25)+y_pos
        end
    end
    u.update(dt)
end


return UI
