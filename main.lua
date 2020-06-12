local particleSize=2
local width,height=976/particleSize,976/particleSize
local sim=nil
local size=50
local particleCount=0
local UI
local setColor,points,line,circle=love.graphics.setColor,love.graphics.points,love.graphics.line,love.graphics.circle
local isMouseDown,floor=love.mouse.isDown,math.floor
--End of local variables

currentType=2
debug=false
paused=nil
particleTypes=nil
--End of global variables

function love.load()
    success = love.window.setMode(width*particleSize, height*particleSize,{vsync=true})
    love.graphics.setDefaultFilter("nearest","nearest",0)
    sim=require'Resources.scripts.simulation'.new(width,height,particleSize)
    particleTypes=sim.particleTypes
    love.mouse.setVisible(false)
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
    local mx,my=love.mouse.getPosition()
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
end

function love.update(dt) 
    local cx,cy=love.mouse.getPosition()
    --Drawing.
    if(not UI.showButtons) then
        if isMouseDown(1) then
            --Draw filled circle of pixels.
            for y = floor(-size/sim.particleSize), floor(size/sim.particleSize)+1 do
                for x= floor(-size/sim.particleSize), floor(size/sim.particleSize)+1 do
                    if((x*x+y*y)<(size*size)/(sim.particleSize*sim.particleSize))then
                        local oX=floor(cx/sim.particleSize)
                        local oY=floor(cy/sim.particleSize)
                        local i=sim:calculate_index(oX+x,oY+y)
                        local type,success=sim:get_index(oX+x,oY+y)
                        if(type==1 and success and currentType~=1)then
                            sim:set_index(oX+x,oY+y,currentType)  
                            particleCount=particleCount+1
                        elseif currentType==1 and type~=1 and success then
                            sim:set_index(oX+x,oY+y,currentType)  
                            particleCount=particleCount-1
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
    sim:update(UI.showButtons)
end



function love.wheelmoved(x, y)
    if(not UI.showButtons)then
        size=size+y
    else
        if(y<0) then
            currentType=currentType > 1 and currentType-1 or #particleTypes
        else
            currentType=currentType < #particleTypes and currentType+1 or 1
        end
        UI.buttonOffset=90*(currentType-2);
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