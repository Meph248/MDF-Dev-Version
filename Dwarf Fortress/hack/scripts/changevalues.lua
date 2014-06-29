--changevalues.lua v1.0
--[[
changevalues - will change a series of unit values (like stun, paralysis, hunger timer, etc…)
	VALUE_TOKEN - value to change, separate multiple tokens with ‘+’
		valid tokens found here
	ID # - the units id number
		\UNIT_ID - when triggering with a syndrome
		\WORKER_ID - when triggering with a reaction
	change type - the type of change to make, separate multiple types with ‘+’ (must have same number of types as trait tokens)
		percent - adjust the units values by a specified percent
		fixed - add a specific amount to the units values
		set - set the units values to the given strength
	strength - the amount to change by, separate multiple strengths with ‘+’ (must have same number of strengths as skill tokens)
		#
			Equation for percent: value = value*(100+strength)/100
			Equation for fixed: value = value + strength
			Equation for set: value = strength
	(OPTIONAL) duration - sets a specified length of time for the changes to last (in in-game ‘ticks’)
		#
			DEFAULT: 0 - value changes will be permanent
			NOTE: Will set values back to previous value after effect wears off, any natural changes during the change will be reverted..
EXAMPLE: changevalues webbed+blood \UNIT_ID set+percent 1000+-20 3600
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

function createcallback(etype,unitTarget,ctype,strength,save)
	return function(reseteffect)
		effect(etype,unitTarget,ctype,strength,save,-1)
	end
end

function effect(e,unitTarget,ctype,strength,save,dir)
	local value = 0
	local t = 0
	local int16 = 30000
	local int32 = 200000000
	if (e == 'webbed' or e == 'stunned' or e == 'winded' or e == 'unconscious' or e == 'pain'
		or e == 'nausea' or e == 'dizziness') then t = 1 end
	if (e == 'paralysis' or e == 'numbness' or e == 'fever' or e == 'exhaustion' 
		or e == 'hunger' or e == 'thirst' or e == 'sleepiness') then t = 2 end
	if e == 'blood' then t = 3 end
	if e == 'infection' then t = 4 end
	if (e == 'hunger' or e == 'thirst' or e == 'sleepiness') then e = e .. '_timer' end

	if t == 1 then
		value = unitTarget.counters[e]
		if dir == 1 then save = value end
		if ctype == 'fixed' then
			value = value + strength
		elseif ctype == 'percent' then
			local percent = (100+strength)/100
			value = math.floor(value*percent)
		elseif ctype == 'set' then
			value = strength
		end
		if value > int16 then value = int16 end
		if value < 0 then value = 0 end
		if dir == -1 then value = save end
		unitTarget.counters[e] = value
	elseif t == 2 then
		value = unitTarget.counters2[e]
		if dir == 1 then save = value end
		if ctype == 'fixed' then
			value = value + strength
		elseif ctype == 'percent' then
			local percent = (100+strength)/100
			value = math.floor(value*percent)
		elseif ctype == 'set' then
			value = strength
		end
		if value > int16 then value = int16 end
		if value < 0 then value = 0 end
		if dir == -1 then value = save end
		unitTarget.counters2[e] = value
	elseif t == 3 then
		if dir == 1 then save = value end
		if ctype == 'fixed' then
			value = value + strength
		elseif ctype == 'percent' then
			local percent = (100+strength)/100
			value = math.floor(value*percent)
		elseif ctype == 'set' then
			value = strength
		end
		if value > unitTarget.body.blood_max then value = unitTarget.body.blood_max end
		if value < 0 then value = 0 end
		unitTarget.body.blood_count = value
	elseif t == 4 then
		value = unitTarget.body.infection_level
		if dir == 1 then save = value end
		if ctype == 'fixed' then
			value = value + strength
		elseif ctype == 'percent' then
			local percent = (100+strength)/100
			value = math.floor(value*percent)
		elseif ctype == 'set' then
			value = strength
		end
		if value > int16 then value = int16 end
		if value < 0 then value = 0 end
		unitTarget.body.infection_level = value
	end
end

local types = args[1]
local unit = df.unit.find(tonumber(args[2]))
local ctype = args[3]
local strengtha = split(args[4],'+')
local typea = split(types,'+')
local ctypea = split(ctype,'+')
local dur = 0
if #args == 5 then dur = tonumber(args[5]) end

for i,etype in ipairs(typea) do
	save = effect(etype,unit,ctypea[i],tonumber(strengtha[i]),0,1)
	if dur > 0 then
		dfhack.timeout(dur,'ticks',createcallback(etype,unit,ctypea[i],tonumber(strengtha[i]),save))
	end
end


