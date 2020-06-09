local particles={
    {"AIR",{1,.9,.9,1},function(x,y,s) end,0},
    {"SAND",{(255)/255,204/255,128/255},function(x,y,s) return update_sand(x,y,s) end,1},
    {"WALL",{100/255,100/255,100/255},function(x,y,s) return x,y end,0},
    {"WATER",{116/255,204/255,244/255},function(x,y,s) return update_water(x,y,s) end,1}
}



function update_sand(x,y,sim)
    local dx=math.random(-1,1)
    local b=sim:get_index(x,y+1)
    local lr=sim:get_index(x+dx,y+1)
    if(b~= nil and b==1 )then
        local i=sim:calculate_index(x,y)
        local i2=sim:calculate_index(x,y+1)
        sim:set_index(x,y,1)
        sim:set_index(x,y+1,2)
        return x,y+1
    elseif(b~= nil and b==4 )then
        local i=sim:calculate_index(x,y)
        local i2=sim:calculate_index(x,y+1)
        sim:set_index(x,y,4)
        sim:set_index(x,y+1,2)
        return x,y+1
    elseif lr~=nil and lr==1 then
        sim:set_index(x,y,1)
        sim:set_index(x+dx,y+1,2)
        return x+dx,y+1
    elseif lr~=nil and lr==4 then
        sim:set_index(x,y,4)
        sim:set_index(x+dx,y+1,2)
        return x+dx,y+1
    end
    return x,y
end

function update_water(x,y,sim)
    local dx=math.random(-1,1)
    local b=sim:get_index(x,y+1)
    local lrd=sim:get_index(x+dx,y+1)
    local lr=sim:get_index(x+dx,y)
    if(b~= nil and (b==1) )then
        local i=sim:calculate_index(x,y)
        local i2=sim:calculate_index(x,y+1)
        sim:set_index(x,y,1)
        sim:set_index(x,y+1,4)
        return x,y+1
    elseif lr~=nil and (lr==1) then
        sim:set_index(x,y,1)
        sim:set_index(x+dx,y,4)
        return x+dx,y
    end
    return x,y
end




return particles