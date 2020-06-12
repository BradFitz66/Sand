local UI={}
UI.__index=UI
local u = require "Resources.lib.urutora"

local TWOPI = math.pi * 2

function UI.load()
    local UI=setmetatable({}, UI)
    UI.buttons = { }
    u.setResolution(love.graphics.getWidth(), love.graphics.getHeight())
    for i = 7,0,-1 do
        if(particleTypes[i])then
            local angle = TWOPI / #particleTypes * i
            local x_pos = math.cos(angle) * 100
            local y_pos = math.sin(angle) * 100
            local panel = u.button({text=particleTypes[i][1], x=(love.graphics.getWidth()/2 - 25)+x_pos, y=(love.graphics.getHeight()/2-25)+y_pos, w=50, h=50, rows=1, cols=1})
            panel:setStyle({bgColor={particleTypes[i][2][1]+.03,particleTypes[i][2][2]+.03,particleTypes[i][2][3]+.03},fgColor={0,0,0,1}}) -- Color the buttons using the particle color (+ a small offset because otherwise air button would be invisible)
            panel:action(function (e)  currentType=i end)
            table.insert(UI.buttons,panel)
        end
    end
    UI.buttonOffset=90*(currentType-2);
    UI.targetOffset=90*(currentType-2);
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
    self.showButtons=isMouseDown(2)
    local cx,cy=love.mouse.getPosition()
    if(self.showButtons) then
        for i=1,#buttons do
            local angle = (TWOPI / #particleTypes * i)+math.rad(self.buttonOffset)
            local x_pos = math.cos(angle) * 100
            local y_pos = math.sin(angle) * 100
            buttons[i].x=(cx-25)+x_pos
            buttons[i].y=(cy-25)+y_pos
        end
    end
    u.update(dt)
end

function love.mousepressed(x,y,button)
    if(button==1)then
        u.pressed(x, y)
    end
end

function love.mousereleased(x,y,button)
    if(button==1)then
        u.released(x, y)
    end
end

return UI
