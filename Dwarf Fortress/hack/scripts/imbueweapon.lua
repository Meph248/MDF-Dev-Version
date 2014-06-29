args = {...}

function createcallback(item,stype,sindex)
	return function (resetweapon)
		item.mat_type = stype
		item.mat_index = sindex
	end
end

local unit = df.unit.find(tonumber(args[1]))
local mat = args[2]
local time = tonumber(args[3])
local mat_type = dfhack.matinfo.find(mat).type
local mat_index = dfhack.matinfo.find(mat).index

local inv = unit.inventory
local mode = 0
local weapon = 'nil'
for i = 0, #inv - 1, 1 do
	mode = inv[i].mode
	if mode == 1 then
		weapon = i
	end
end

if weapon == 'nil' then 
	print('No weapon equiped')
	return
end

local item = inv[weapon].item
local stype = item.mat_type
local sindex = item.mat_index
item.mat_type = mat_type
item.mat_index = mat_index

if time ~= 0 then
	dfhack.timeout(time,'ticks',createcallback(item,stype,sindex))
end
