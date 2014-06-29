--changeattributes.lua v1.0
--[[
changeattributes - will change a units physical or mental attributes
	type
		mental - specifies that the change is to a mental attribute
		physical - specifies that the change is to a physical attribute
	ATTRIBUTE_TOKEN - attribute to change, separate multiple tokens with ‘+’
		valid tokens found here
	ID # - the units id number
		\UNIT_ID - when triggering with a syndrome
		\WORKER_ID - when triggering with a reaction
	change type - the type of change to make, separate multiple types with ‘+’ (must have same number of types as attribute tokens)
		percent - adjust the units attributes by a specified percent
		fixed - add a specific amount to the units attributes
		set - set the units attributes to the given strength
	strength - the amount to change by, separate multiple strengths with ‘+’ (must have same number of strengths as attribute tokens)
		#
			Equation for percent: value = value*(100+strength)/100
			Equation for fixed: value = value + strength
			Equation for set: value = strength
	(OPTIONAL) duration - sets a specified length of time for the changes to last (in in-game ‘ticks’)
		#
			DEFAULT: 0 - attribute changes will be permanent
			NOTE: Will set attributes back to previous value after effect wears off, this may interfere with other attribute changing syndromes.
EXAMPLE: changeattributes physical STRENGTH+ENDURANCE+AGILITY \UNIT_ID fixed+fixed+percent 500+500+-50 3600
--]]

args={...}

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

function createcallback(etype,mental,unitTarget,ctype,strength,save)
	return function(reseteffect)
		effect(etype,mental,unitTarget,ctype,strength,save,-1)
	end
end

function effect(etype,mental,unitTarget,ctype,strength,save,dir)
	local value = 0
	local int16 = 30000
	local int32 = 200000000

	if mental == 'physical' then
		if dir == 1 then save = unitTarget.body.physical_attrs[etype].value end
		value = unitTarget.body.physical_attrs[etype].value
		if ctype == 'fixed' then
			value = value + strength
		elseif ctype == 'percent' then
			local percent = (100+strength)/100
			value = value*percent
		elseif ctype == 'set' then
			value = strength
		end
		if value > int16 then value = int16 end
		if value < 0 then value = 0 end
		if dir == -1 then value = save end
		unitTarget.body.physical_attrs[etype].value = value
	elseif mental == 'mental' then
		if dir == 1 then save = unitTarget.status.current_soul.mental_attrs[etype].value end
		value = unitTarget.status.current_soul.mental_attrs[etype].value
		if ctype == 'fixed' then
			value = value + strength
		elseif ctype == 'percent' then
			local percent = (100+strength)/100
			value = value*percent
		elseif ctype == 'set' then
			value = strength
		end
		if value > int16 then value = int16 end
		if value < 0 then value = 0 end
		if dir == -1 then value = save end
		unitTarget.status.current_soul.mental_attrs[etype].value = value
	end
	return save
end

local types = args[2]
local mental = args[1]
local unit = df.unit.find(tonumber(args[3]))
local ctype = args[4]
local strengtha = split(args[5],'+')
local typea = split(types,'+')
local ctypea = split(ctype,'+')
local dur = 0
if #args == 6 then dur = tonumber(args[6]) end

for i,etype in ipairs(typea) do
	save = effect(etype,mental,unit,ctypea[i],tonumber(strengtha[i]),0,1)
	if dur > 0 then
		dfhack.timeout(dur,'ticks',createcallback(etype,mental,unit,ctypea[i],tonumber(strengtha[i]),save))
	end
end
