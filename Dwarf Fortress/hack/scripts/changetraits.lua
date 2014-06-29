--changetraits.lua v1.0
--[[
changetraits - will change a units trait values
	TRAIT_TOKEN - trait to change, separate multiple tokens with ‘+’
		valid tokens found here
	ID # - the units id number
		\UNIT_ID - when triggering with a syndrome
		\WORKER_ID - when triggering with a reaction
	change type - the type of change to make, separate multiple types with ‘+’ (must have same number of types as trait tokens)
		percent - adjust the units traits by a specified percent
		fixed - add a specific amount to the units traits
		set - set the units traits to the given strength
	strength - the amount to change by, separate multiple strengths with ‘+’ (must have same number of strengths as skill tokens)
		#
			Equation for percent: value = value*(100+strength)/100
			Equation for fixed: value = value + strength
			Equation for set: value = strength
	(OPTIONAL) duration - sets a specified length of time for the changes to last (in in-game ‘ticks’)
		#
			DEFAULT: 0 - trait changes will be permanent
			NOTE: Will set traits back to previous value after effect wears off, any natural changes during the change will be reverted..
EXAMPLE: changetraits ANGER+EMOTIONALITY \UNIT_ID set+percent 100+-50 3600
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
		save = effect(etype,unitTarget,ctype,strength,save,-1)
	end
end

function effect(etype,unitTarget,ctype,strength,save,dir)
	local value = 0
	local int16 = 30000
	local int32 = 200000000
	if dir == 1 then save = unitTarget.status.current_soul.traits[etype] end

	if ctype == 'fixed' then
		value = unitTarget.status.current_soul.traits[etype] + strength
	elseif ctype == 'percent' then
		percent = (100+strength)/100
		value = unitTarget.status.current_soul.traits[etype]*strength
	elseif ctype == 'set' then
		value = strength
	end
	if dir == -1 then value = save end
	if value > 100 then value = 100 end
	if value < 0 then value = 0 end
	unitTarget.status.current_soul.traits[etype] = value

	return save
end

local types = args[1]
local unit = df.unit.find(tonumber(args[2]))
local ctype = args[3]
local strengtha = split(args[4],'/')
local typea = split(types,'/')
local dur = 0
if #args == 5 then dur = tonumber(args[5]) end

for i,etype in ipairs(typea) do
	save = effect(etype,unit,ctype,tonumber(strengtha[i]),0,1)
	if dur > 0 then
		dfhack.timeout(dur,'ticks',createcallback(etype,unit,ctype,tonumber(strengtha[i]),save))
	end
end
