
--Data for the particles. Name, color, update function and color variation multiplier (0=no color variation)
local particles={
    {"AIR",{1,.9,.9,1},function(x,y,s) end,0,{}},
    {"SAND",{(255)/255,209/255,128/255},function(x,y,s,d,dt) return update_sand(x,y,s,d,dt) end,1,{}},
    {"WALL",{100/255,100/255,100/255},function(x,y,s,d,dt) return x,y end,0,{}},
    {"WATER",{116/255,209/255,299/255},function(x,y,s,d,dt) return update_water(x,y,s,d,dt) end,1,{}},
    {"FIRE",{255/255,150/255,150/255},function(x,y,s,d,dt) return update_fire(x,y,s,d,dt) end,1,{["maxMoves"]=3}},
    {"WOOD",{202/255,169/255,119/255},function(x,y,s,d,dt) return x,y end,1,{},{}},
    {"PLANT",{80/255,131/255,67/255},function(x,y,s,d,dt) return update_plant(x,y,s,d,dt) end,.1,{},{}},
    {"ROCK",{90/255,77/255,65/255},function(x,y,s,d,dt) return x,y end,.1,{}},
    {"OIL",{55/255,58/255,59/255},function(x,y,s,d,dt) return update_oil(x,y,s,d,dt) end,.25,{}},
    {"LAVA",{207/255,16/255,32/255},function(x,y,s,d,dt) return update_lava(x,y,s,d,dt) end,1,{}},

}

--Update function for sand
function update_sand(x,y,sim)
    local dx=math.random(-1,1) -- Random direction on the x axis
    local b=sim:get_index(x,y+1) -- Index below current index
    local lr=sim:get_index(x+dx,y+1) --Index to the diagonal down left or right (depending on the value of dx)
    --If index isn't nil and is air then set the index below us to sand and set where we currently are to air
    if(b~= nil and b==1 )then
        sim:set_index(x,y,1)
        sim:set_index(x,y+1,2)
    --If the index below us is water, replace current pixel with water, and replace below water pixel with sand
    elseif(b~= nil and b==4 )then
        local i=sim:calculate_index(x,y)
        local i2=sim:calculate_index(x,y+1)
        sim:set_index(x,y,4)
        sim:set_index(x,y+1,2)
    --Move diagonally down left/right if index is air
    elseif lr~=nil and lr==1 then
        sim:set_index(x,y,1)
        sim:set_index(x+dx,y+1,2)
    --Move diagonally down left/right if index is water
    elseif lr~=nil and lr==4 then
        sim:set_index(x,y,4)
        sim:set_index(x+dx,y+1,2)
    end
end


function update_water(x,y,sim)
    local floor=math.floor
    local dx=math.random(-1,1)
    local b=sim:get_index(x,y+1)
    local lrd=sim:get_index(x+dx,y+1)
    local lr=sim:get_index(x+dx,y)
    local a = sim:get_index(x,y-1)
    if((b==1) )then
        sim:set_index(x,y,1,clock)
        sim:set_index(x,y+1,4,clock)
    elseif (lr==1) then
        sim:set_index(x,y,1,clock)
        sim:set_index(x+dx,y,4,clock)
    elseif((b==10) )then
        for py = floor(-5/sim.particleSize), floor(5/sim.particleSize)+1 do
            for px= floor(-5/sim.particleSize), floor(5/sim.particleSize)+1 do
                if((px*px+py*py)<(5*5)/(sim.particleSize*sim.particleSize))then
                    sim:set_index(x+px,y+py,8,clock)
                end
            end
        end
    elseif (lr==10) then
        for py = floor(-5/sim.particleSize), floor(5/sim.particleSize)+1 do
            for px= floor(-5/sim.particleSize), floor(5/sim.particleSize)+1 do
                if((px*px+py*py)<(5*5)/(sim.particleSize*sim.particleSize))then
                    sim:set_index(x+px,y+py,8,clock)
                end
            end
        end
    elseif a==10 then
        for py = floor(-5/sim.particleSize), floor(5/sim.particleSize)+1 do
            for px= floor(-5/sim.particleSize), floor(5/sim.particleSize)+1 do
                if((px*px+py*py)<(5*5)/(sim.particleSize*sim.particleSize))then
                    sim:set_index(x+px,y+py,8,clock)
                end
            end
        end
    end
end

function update_oil(x,y,sim)
    local dx=math.random(-1,1)
    local b=sim:get_index(x,y+1)
    local lrd=sim:get_index(x+dx,y+1)
    local lr=sim:get_index(x+dx,y)
    if(b~= nil and (b==1) )then
        sim:set_index(x,y,1,clock)
        sim:set_index(x,y+1,9,clock)
    elseif lr~=nil and (lr==1) then
        sim:set_index(x,y,1,clock)
        sim:set_index(x+dx,y,9,clock)
    elseif lr~=nil and (lr==2) then
        sim:set_index(x,y,2,clock)
        sim:set_index(x+dx,y,9,clock)
    end
end
function update_lava(x,y,sim)
    local dx=math.random(-1,1)
    local b=sim:get_index(x,y+1)
    local lrd=sim:get_index(x+dx,y+1)
    local lr=sim:get_index(x+dx,y)
    if(b~= nil and (b==1) )then
        sim:set_index(x,y,1,clock)
        sim:set_index(x,y+1,10,clock)
    elseif(b~=nil and b==9)then

    elseif lr~=nil and (lr==1) then
        sim:set_index(x,y,1,clock)
        sim:set_index(x+dx,y,10,clock)
    elseif lr~=nil and (lr==2) then
        sim:set_index(x,y,2,clock)
        sim:set_index(x+dx,y,10,clock)
    end
end

function update_fire(x,y,sim,data,dt)
    local a = sim:get_index(x,y-1)
    if(data.maxMoves>0)then
        
        data.maxMoves=data.maxMoves-1
        if(data.createdChild==false)then
            for i=1,5 do
                local rx,ry=math.random(-5,5),math.random(-5,5)--r = relative
                sim:set_index(x+rx,y+ry,5,{["createdChild"]=true})
            end
            data.createdChild=true
        else
            sim:set_index(x,y-1,5,{["createdChild"]=true})
            sim:set_index(x,y,1)
        end
        return x,y-1,data
    end

    if(data.maxMoves<=0)then
        sim:set_index(x,y,1)
        return x,y,data
    end   


    return 0,0,0
end

function update_plant(x,y,sim)
    local a=sim:get_index(x,y-1)
    local b=sim:get_index(x,y+1)
    local l=sim:get_index(x-1,y)
    local r=sim:get_index(x+1,y)
    if(a==4)then
        sim:set_index(x,y-1,7,true)
    elseif b==4 then
        sim:set_index(x,y+1,7,true)
    elseif l==4 then
        sim:set_index(x-1,y,7,true)
    elseif r==4 then
        sim:set_index(x+1,y,7,true)
    end
end




return particles