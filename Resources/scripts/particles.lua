local particles={
    [0]={"AIR",{1,.9,.9,1},function(x,y,s) end,0},
    [1]={"SAND",{(255)/255,204/255,128/255},function(x,y,s) return update_sand(x,y,s) end,1},
    [2]={"WALL",{100/255,100/255,100/255},function(x,y,s) return x,y end,0},
    [3]={"WATER",{116/255,204/255,244/255},function(x,y,s) return update_water(x,y,s) end,1},
}

function getLength(dictionary)
    local len=0
    for _, v in pairs(dictionary) do
        len=len+1
    end
    return len-1 --this will also take into account 'len' inside the dictionary. We don't want that.
end

function update_sand(x,y,sim)
    local dx=math.random(-1,1)
    local b=sim:get_index(x,y+1)
    local lr=sim:get_index(x+dx,y+1)
    if(b~= nil and b==0 )then
        local i=sim:calculate_index(x,y)
        local i2=sim:calculate_index(x,y+1)
        sim:set_index(x,y,0)
        sim:set_index(x,y+1,1)
        return x,y+1
    elseif(b~= nil and b==3 )then
        local i=sim:calculate_index(x,y)
        local i2=sim:calculate_index(x,y+1)
        sim:set_index(x,y,3)
        sim:set_index(x,y+1,1)
        return x,y+1
    elseif lr~=nil and lr==0 then
        sim:set_index(x,y,0)
        sim:set_index(x+dx,y+1,1)
        return x+dx,y+1
    elseif lr~=nil and lr==3 then
        sim:set_index(x,y,3)
        sim:set_index(x+dx,y+1,1)
        return x+dx,y+1
    end
    return x,y
end

function update_water(x,y,sim)
    local dx=math.random(-1,1)
    local b=sim:get_index(x,y+1)
    local lrd=sim:get_index(x+dx,y+1)
    local lr=sim:get_index(x+dx,y)
    if(b~= nil and b==0 )then
        local i=sim:calculate_index(x,y)
        local i2=sim:calculate_index(x,y+1)
        sim:set_index(x,y,0)
        sim:set_index(x,y+1,3)
        return x,y+1
    elseif lr~=nil and lr==0 then
        sim:set_index(x,y,0)
        sim:set_index(x+dx,y,3)
        return x+dx,y
    elseif lrd~=nil and lrd==0 then
        sim:set_index(x,y,0)
        sim:set_index(x+dx,y+1,3)
        return x+dx,y+1
    end
    return x,y
end


return particles