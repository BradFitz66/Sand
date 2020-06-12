local particleSize=2
local width,height=976/particleSize,976/particleSize
local sim=nil
local size=50
particleCount=0
local UI
local setColor,points,line,circle=love.graphics.setColor,love.graphics.points,love.graphics.line,love.graphics.circle
local isMouseDown,floor=love.mouse.isDown,math.floor
local timer;
local printThread
--local timer=hump.timer
--End of local variables

currentType=2
debug=false
paused=nil
particleTypes=nil
mouseDx,mouseDy=0,0
mx,my=0,0
lastMouseX,lastMouseY=0,0
--End of global variables
local pChannel=love.thread.getChannel ( "print" );

function print(str)
    pChannel:push(str)
end

function love.load()
    success = love.window.setMode(width*particleSize, height*particleSize,{vsync=true})
    printThread=love.thread.newThread( [[
        while true do
            local str = love.thread.getChannel( 'print' ):pop()  
            if(str) then
                print(str)
            end
        end ]] ) 
    print("LETS FUCKING GOOOOO")
    printThread:start()
    love.graphics.setDefaultFilter("nearest","nearest",0)
    sim=require'Resources.scripts.simulation'.new(width,height,particleSize)
    particleTypes=sim.particleTypes
    love.mouse.setVisible(false)
    timer= require 'Resources.lib.hump.timer'

    UI=require'Resources.scripts.UI'.load()
end

function math.clamp(value,min,max)
    if(value>max)then
        value=max
    elseif value<min then
        value=min
    end
    return value
end

local selectedTextY=10

function love.draw()
    love.graphics.setLineWidth(1)
    if(not love.mouse.getRelativeMode()) then
        mx,my=love.mouse.getPosition()
    end
    
    love.graphics.setPointSize(particleSize)
    sim:draw()
    UI:draw()
    love.graphics.setColor(.5,.5,0.5)
    if(debug)then
        love.graphics.print("FPS: "..love.timer.getFPS(),5,10)
        love.graphics.print("Particles: "..particleCount,5,24)
    end
    if(paused) then
        love.graphics.print("PAUSED",love.graphics.getWidth()/2,love.graphics.getHeight()/2)
    end
    love.graphics.print("Selected particle type: "..particleTypes[currentType][1],5,selectedTextY)
    line(mx-8,my, mx-3, my)
	line(mx+8,my, mx+3, my)
	line(mx, my-8, mx, my-3)
    line(mx, my+8, mx, my+3)
    circle("line",mx,my,size,200)
    if(love.mouse.getRelativeMode()) then
        love.graphics.setLineWidth(3)
        line(mx,my, love.mouse.getX(),love.mouse.getY())
    end

    
end


function love.update(dt) 
    --Drawing.
    timer.update(dt)
    if(not UI.showButtons) then
        if isMouseDown(1) then
            --Draw filled circle of pixels.
            for y = floor(-size/sim.particleSize), floor(size/sim.particleSize)+1 do
                for x= floor(-size/sim.particleSize), floor(size/sim.particleSize)+1 do
                    if((x*x+y*y)<(size*size)/(sim.particleSize*sim.particleSize))then
                        local oX=floor(mx/sim.particleSize)
                        local oY=floor(my/sim.particleSize)
                        local i=sim:calculate_index(oX+x,oY+y)
                        local type,success=sim:get_index(oX+x,oY+y)
                        if(type==1 and success and currentType~=1)then
                            sim:set_index(oX+x,oY+y,currentType)  
                        elseif currentType==1 and type~=1 and success then
                            sim:set_index(oX+x,oY+y,currentType)  
                        end
                    end
                end
            end
        end
    end
    
    size=math.clamp(size,1,1000)
    UI:update(dt)
    if(paused)then
        return
    end
    sim:update(dt)
end

function love.mousepressed(x,y,button)
    if(button==1)then
        u.pressed(x, y)
    elseif(button==2)then
        print("WOO")
        showButtons=true
        lastMouseX=x
        lastMouseY=y
        love.mouse.setRelativeMode(true)
    end
end

function love.mousereleased(x,y,button)
    if(button==1)then
        u.released(x, y)
    elseif(button==2)then
        showButtons=false
        love.mouse.setRelativeMode(false)
        love.mouse.setPosition(lastMouseX,lastMouseY)
    end
end


function love.mousemoved(x,y,dx,dy,isTouch)
    mouseDx=dx
    mouseDy=dy
end


function love.wheelmoved(x, y)
    if(not UI.showButtons)then
        size=size+y
    end
end

function love.keypressed(key)
    if(key=='lalt')then
        debug=not debug
        selectedTextY = debug and 38 or 10
    end
    if(key=='p')then
        paused=not paused
    end
    if(key=="[")then
		size=size/2
	elseif(key=="]")then
		size=size*2
    end
end