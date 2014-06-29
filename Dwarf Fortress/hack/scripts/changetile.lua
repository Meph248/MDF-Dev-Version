--changetile.lua v1.0
--[[
changetile - will change a tiles temperature or material
	style - how to perform the change, both styles have a different set of input arguments
		plan - changes tiles based on a plan.txt file, similarly to how the plan@ wrapper works
			ID # - the units id number
				\UNIT_ID - when triggering with a syndrome
				\WORKER_ID - when triggering with a reaction
			filename - filename of .txt file placed in hack/scripts
				Any file name without the .txt
			change type - the type of change to perform
				temperature - changes the temperature of the tile
				material - changes the material the tile is made out of, only works for inorganics, and doesn’t work all the time
				SPECIAL TOKEN: clear - clears all veins in area (based on blocks not tiles, only use if you are wanting to clear large amounts of veins)
			change
				# - For use with a change type of ‘temperature’ (remember 10067 is standard body temperature)
				INORGANIC_TOKEN - For use with a change type of ‘material’
			(OPTIONAL) duration - sets a specified length of time for the changes to last (in in-game ‘ticks’)
				#
					DEFAULT: 0 - material changes will be permanent, temperature changes will gradually return to normal using in game mechanics
					NOTE: Will set tile back to previous value after effect wears off, doesn’t always work with a change type of ‘material’
	EXAMPLE: changetile plan \UNIT_ID 5x5_X temperature 9600 100
		location****** - changes specific locations tile
			x/y/z - the location of the change
			change type - the type of change to perform
				temperature - changes the temperature of the tile
				material - changes the material the tile is made out of, only works for inorganics, and doesn’t work all the time
				SPECIAL TOKEN: clear - clears all veins in area (based on blocks not tiles, only use if you are wanting to clear large amounts of veins)
			change
				# - For use with a change type of ‘temperature’ (remember 10067 is standard body temperature)
				INORGANIC_TOKEN - For use with a change type of ‘material’
			(OPTIONAL) duration - sets a specified length of time for the changes to last (in in-game ‘ticks’)
				#
					DEFAULT: 0 - temperature and material changes will be permanent
					NOTE: Will set tile back to previous value after effect wears off, doesn’t always work with a change type of ‘material’, and the game will eventually set the temperature of a tile back to normal
	EXAMPLE: changetile location 136/142/168 temperature 9600 100
--]]

args = {...}

function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
	 table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

function read_file(path)
	local iofile = io.open(path,"r")
	local read = iofile:read("*all")
	iofile:close()

	local reada = split(read,',')
	local x = {}
	local y = {}
	local t = {}
	local xi = 0
	local yi = 1
	local x0 = 0
	local y0 = 0
	for i,v in ipairs(reada) do
		if split(v,'\n')[1] ~= v then
			xi = 1
			yi = yi + 1
		else
			xi = xi + 1
		end
		if v == 'X' or v == '\nX' then
			x0 = xi
			y0 = yi
		end
		if v == 'X' or v == '\nX' or v == '1' or v == '\n1' then
			t[i] = true
		else
			t[i] = false
		end
		x[i] = xi
		y[i] = yi
	end
	return x,y,t
end

function resetTemp(pos,temp1,temp2)
	return function(reset1)
		dfhack.maps.ensureTileBlock(pos).temperature_1[pos.x%16][pos.y%16] = temp1
		dfhack.maps.ensureTileBlock(pos).temperature_1[pos.x%16][pos.y%16] = temp2
		dfhack.maps.ensureTileBlock(pos).flags.update_temperature = true
	end
end

function changeTemp(x,y,z,temp,dur)
	local pos = {x=x,y=y,z=z}
	local block = dfhack.maps.ensureTileBlock(pos)
	local stemp1 = block.temperature_1[x%16][y%16]
	local stemp2 = block.temperature_2[x%16][y%16]

	block.temperature_1[x%16][y%16] = temp
	if dur >= 0 then 
		block.temperature_2[x%16][y%16] = temp
		block.flags.update_temperature = false
	end

	if dur > 0 then dfhack.timeout(dur,'ticks',resetTemp(pos,stemp1,stemp2)) end
end

function findMineralEv(block,inorganic) -- Taken from Warmist's constructor.lua
	for k,v in pairs(block.block_events) do
		if df.block_square_event_mineralst:is_instance(v) and v.inorganic_mat==inorganic then
			return v
		end
	end
end

function set_vein(x,y,z,mat) -- Taken from Warmist's constructor.lua
    local b=dfhack.maps.ensureTileBlock(x,y,z)
    local ev=findMineralEv(b,mat.index)
    if ev==nil then
        ev=df.block_square_event_mineralst:new()
        ev.inorganic_mat=mat.index
        ev.flags.vein=true
        b.block_events:insert("#",ev)
    end
    dfhack.maps.setTileAssignment(ev.tile_bitmask,math.fmod(x,16),math.fmod(y,16),true)
end

function clear_vein(x,y,z)
	local b=dfhack.maps.ensureTileBlock(x,y,z)
	for k = #b.block_events-1,0,-1 do
		print(k)
		b.block_events:erase(k)
	end
end

function changeType(x,y,z,material,dur)
	local mat
	if material ~= 'clear' then 
		mat = dfhack.matinfo.find(material)
		set_vein(x,y,z,mat)
	else
		clear_vein(x,y,z)
	end
end

local etype = args[1]

if etype == 'plan' then
	local unitTarget = df.unit.find(tonumber(args[2]))
	local file = args[3]..".txt"
	local path = dfhack.getDFPath().."/hack/scripts/"..file
	local change = args[4]
	local dur = 0
	if #args == 6 then dur = tonumber(args[6]) end
	local x,y,t = read_file(path)
	for i,_ in ipairs(x) do
		xc = x[i] - x0 + pos.x
		yc = y[i] - y0 + pos.y
		zc = z
		if t[i] then
			if change == 'temperature' then changeTemp(xc,yc,zc,tonumber(args[5]),dur) end
			if change == 'material' then changeType(xc,yc,zc,args[5],dur) end
		end
	end
elseif etype == 'location' then
	local x = split(args[2],'/')[1]
	local y = split(args[2],'/')[2]
	local z = split(args[2],'/')[3]
	local change = args[3]
	local dur = 0
	if #args == 5 then dur = tonumber(args[5]) end
	if change == 'temperature' then changeTemp(xc,yc,zc,tonumber(args[4]),dur) end
	if change == 'material' then changeType(xc,yc,zc,args[4],dur) end
end

