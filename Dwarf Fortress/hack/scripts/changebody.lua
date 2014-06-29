--changebody.lua v1.0
--[[
changebody - will change a units body parts temperatures (hopefully other things in the future)
	type
		temperature - currently the only supported body change is to temperature
	ID # - the units id number
		\UNIT_ID - when triggering with a syndrome
		\WORKER_ID - when triggering with a reaction
	body parts - the body party to select, separate multiple types with ‘+’
		all - specifies all body parts
		token - specifies body part by token (i.e. [BP:HEAD:head:STP])
		category - specifies body part by category (i.e. [BP_CON:HAND])
		flags - specifies body part by flags (i.e. [THOUGHT]
			part - specify the actual token/category/flag by concatenating with ‘/’
	strength - the temperature to set the body parts at
		SPECIAL TOKEN: fire - sets the unit body parts on fire
		# - temperature (remember 10067 is standard body temperature)
	(OPTIONAL) duration - sets a specified length of time for the changes to last (in in-game ‘ticks’)
		#
			DEFAULT: 0 - temperature changes will be permanent
			NOTE: Will set temperature back to previous value after effect wears off, or puts out the fire on the affected body parts
EXAMPLE: changebody temperature \UNIT_ID category/HAND+category/FOOT fire
--]]

args={...}

function checkbody(unit,bp)
	local parts = {}
	local body = unit.body.body_plan.body_parts
	if bp == 'all' then
		for k,v in ipairs(body) do
			parts[k] = k
		end
	else
		local bpa = split(bp,'+')
		for i,x in ipairs(bpa) do
			local t = split(bpa[i],'/')[1]
			local b = split(bpa[i],'/')[2]
			local a = 1
			if t == 'token' then
				for j,y in ipairs(body) do
					if y.token == b and not unit.body.components.body_part_status[j].missing then 
						parts[a] = j
						a = a + 1
					end
				end
			elseif t =='category' then
				for j,y in ipairs(body) do
					if y.category == b and not unit.body.components.body_part_status[j].missing then 
						parts[a] = j
						a = a + 1
					end
				end
			elseif t =='flags' then
				for j,y in ipairs(body) do
					if y.flags[b] and not unit.body.components.body_part_status[j].missing then 
						parts[a] = j
						a = a + 1
					end
				end
			end
		end
	end
	return parts
end

function createcallback(etype,parts,unitTarget,strength,save)
	return function(reseteffect)
		effect(etype,parts,unitTarget,strength,save,-1)
	end
end

function effect(etype,parts,unit,strength,save,dir)
	if etype=="temperature" then
		for k,z in ipairs(parts) do
			if strength == 'fire' then
				if dir == 1 then
					unit.body.components.body_part_status[z].on_fire=true
					unit.flags3.body_temp_in_range=false
				elseif dir == -1 then
					unit.body.components.body_part_status[z].on_fire=false
					unit.flags3.body_temp_in_range=true
				end
			else
				if dir == 1 then 
					save[z] = unit.status2.body_part_temperature[z].whole
					strength = tonumber(strength)
					unit.status2.body_part_temperature[z].whole=strength
				elseif dir == -1 then
					unit.status2.body_part_temperature[z].whole=save[z]
				end
			end
		end
	end
	return save
end

local etype = args[1]
local unit = df.unit.find(tonumber(args[2]))
local bp = args[3]
local strength = args[4]
local dur = 0
if #args == 5 then dur = tonumber(args[5]) end

parts = checkbody(unit,bp)
save = effect(etype,parts,unit,strength,0,1)
if dur > 0 then
	dfhack.timeout(dur,'ticks',createcallback(etype,parts,unit,strength,save))
end
