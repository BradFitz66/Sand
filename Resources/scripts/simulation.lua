local Simulation={}
Simulation.__index=Simulation
local setColor,points=love.graphics.setColor,love.graphics.points



--Create a new simulation 
function Simulation.new(width,height,particleSize)
    local sim=setmetatable({}, Simulation)
    sim.width,sim.height=width,height
    sim.particleSize=particleSize
    sim.writeBuffer={}
    for x=0,width-1 do
        for y=0,height-1 do
            local i = sim:calculate_index(x,y)
            sim.writeBuffer[i]=1
        end
    end
    sim.particleTypes=require 'Resources.scripts.particles'
    sim.updatedIndexes={}
    sim.imageData = love.image.newImageData(width, height)
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
        return self.writeBuffer[i],true
    end
    return 3,false
end

local random = math.random


--Set a specific index to a specfic type
function Simulation:set_index(x,y,type)
    local i = self:calculate_index(x,y)
    local color = self.particleTypes[type][2]
    local colorVariation=(math.random(-20,20)*self.particleTypes[type][4])/255
    if(x>0 and y > 0 and x<self.width-1 and y<self.height-1)then
        self.imageData:setPixel(x,y,color[1]+colorVariation,color[2]+colorVariation,color[3]+colorVariation,1)
        self.writeBuffer[i]=type    
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
    for x=0,self.width-1 do
        for y=0,self.height-1 do
            local i = self:calculate_index(x,y)
            local data = self.particleTypes[self.writeBuffer[i]]
            if(data[1]~="AIR" and not self.updatedIndexes[i]) then 
                local nx,ny=data[3](x,y,self)--new x, new y
                --Keep track of updated indexes (this stops the update loop from cascadingly updating the pixels in one frame)
                self.updatedIndexes[self:calculate_index(nx,ny)]=true
            end
        end
    end
    self.updatedIndexes={}
end

return Simulation