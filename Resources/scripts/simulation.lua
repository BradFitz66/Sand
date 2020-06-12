local Simulation={}
Simulation.__index=Simulation
local setColor,points=love.graphics.setColor,love.graphics.points
local ffi = require("ffi")
local cwd = love.filesystem.getWorkingDirectory()
--Create a new simulation 
function Simulation.new(width,height,particleSize)
    local sim=setmetatable({}, Simulation)
    sim.width,sim.height=width,height
    sim.particleSize=particleSize
    --use minimum integer size we can use for memory purposes (doesn't really improve much since even with a normal int we only get just over 1MB of memory)
    ffi.cdef[[
        typedef struct { uint8_t type,clock; float lifetimer; int maxMoves; bool createdChild; } particle;
    ]]
    --Create new array of the particle struct with a size of width*height
    sim.writeBuffer=ffi.new("particle[?]",width*height)

    sim.particleTypes=require 'Resources.scripts.particles'
    sim.updatedIndexes={}
    sim.imageData = love.image.newImageData(width, height)
    for i = 1, width*height do
        sim.writeBuffer[i].type=1
    end
    sim.updateClock=0
    for x=0,width-1 do
        for y=0,height-1 do
            sim.imageData:setPixel(x,y,1,.9,.9,1)
        end
    end
    sim.image=love.graphics.newImage(sim.imageData)
    sim.shader=love.graphics.newShader('Resources/shaders/shader.fs')
    return sim
end

--Calculate the 1D index from a 2D position (x,y)
function Simulation:calculate_index(x,y)
    return x+self.width*y
end

--Function just to get an index. Checks whether it's in bounds or not so we don't have to do that every time we want to check an index
function Simulation:get_index(x,y,buffer)
    local i = self:calculate_index(x,y)
    if(x>0 and y > 0 and x<self.width-1 and y<self.height-1)then
        return self.writeBuffer[i].type,true
    end
    return 3,false
end

local random = math.random

--Set a specific index to a specfic type
function Simulation:set_index(x,y,type,replacing)
    local i = self:calculate_index(x,y)
    --print("Modifing index: "..self.Capi.calculate_index(x,y,self.width-1,self.height-1))
    local color = self.particleTypes[type][2]
    local colorVariation=(math.random(-20,20)*self.particleTypes[type][4])/255
    local extraData=self.particleTypes[type][5]
    if(x>0 and y > 0 and x<self.width-1 and y<self.height-1)then
        self.imageData:setPixel(x,y,color[1]+colorVariation,color[2]+colorVariation,color[3]+colorVariation,1)
        self.writeBuffer[i].type=type
        --Keep particles 1 ahead of the clock if they're being updated.
        self.writeBuffer[i].clock=self.updateClock+1


        if(type==1)then
            particleCount=particleCount-1
        else
            --Some particles get replaced (ex: plant replaces water) so we don't want to update the particle count since the particle count would stay the same. 
            if(not replacing) then
                particleCount=particleCount+1
            end
        end
    
         
    end

end

--Draw simulation
function Simulation:draw()
    --For drawing, we draw a single image using a shader. Pixels on that image are set when we set an index.
    love.graphics.setShader(self.shader)
    love.graphics.rectangle("fill", 0, 0, self.width*self.particleSize, self.height*self.particleSize)
    self.image:replacePixels(self.imageData)
	self.shader:send("tex", self.image)
    love.graphics.setShader()
end

--Update simulation
function Simulation:update(dt)
    for x=1,self.width-1 do
        for y=1,self.height-1 do
            local i = self:calculate_index(x,y)
            local data = self.particleTypes[self.writeBuffer[i].type]
            local clock = self.writeBuffer[i].clock
            if(data[1]~="AIR" and(clock-self.updateClock~=1)) then
                data[3](x,y,self,self.writeBuffer[i],dt)
            end
        end
    end
    self.updateClock=self.updateClock+1
    if(self.updateClock>254)then --Stop updateClock from going over 255, the maximum value for 8 bit integers. This stops the particle clocks from overflowing to 0.
        self.updateClock=0
    end
end

return Simulation