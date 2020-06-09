local UI={}
UI.__index=UI
local u = require "Resources.lib.urutora"

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
local input={text=""}
function UI.load()
    local UI=setmetatable({}, UI)
    UI.buttons = { }
    u.setResolution(love.graphics.getWidth(), love.graphics.getHeight())
    for i = 0,7 do
        if(particleTypes[i])then
            local angle = TWOPI / 4 * i
            local x_pos = math.cos(angle) * 150
            local y_pos = math.sin(angle) * 150
            local panel = u.button({text=particleTypes[i][1], x=(love.graphics.getWidth()/2 - 50)+x_pos, y=(love.graphics.getHeight()/2-50)+y_pos, w=100, h=100, rows=1, cols=1})
            panel:setStyle({bgColor={particleTypes[i][2][1]+.01,particleTypes[i][2][2]+.01,particleTypes[i][2][3]+.01},fgColor={0,0,0,1}})
            panel:action(function (e) currentType=i end)
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

local rot=0
local targetRot = 0
local lastSelectedControl
local isMouseDown=love.mouse.isDown
function UI:update(dt)
    local buttons=self.buttons
    local info=self.info
    self.showButtons=isMouseDown(2)
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
