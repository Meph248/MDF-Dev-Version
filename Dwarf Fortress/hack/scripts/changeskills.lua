--changeskills.lua v1.0
--[[
changeskills - will change a units skill levels
	SKILL_TOKEN - skill to change, separate multiple tokens with ‘+’
		valid tokens found here
	ID # - the units id number
		\UNIT_ID - when triggering with a syndrome
		\WORKER_ID - when triggering with a reaction
	change type - the type of change to make, separate multiple types with ‘+’ (must have same number of types as skill tokens)
		percent - adjust the units skills by a specified percent
		fixed - add a specific amount to the units skills
		set - set the units skills to the given strength
	strength - the amount to change by, separate multiple strengths with ‘+’ (must have same number of strengths as skill tokens)
		#
			Equation for percent: value = value*(100+strength)/100
			Equation for fixed: value = value + strength
			Equation for set: value = strength
	(OPTIONAL) duration - sets a specified length of time for the changes to last (in in-game ‘ticks’)
		#
			DEFAULT: 0 - skill changes will be permanent
			NOTE: Will set skills back to previous value after effect wears off, any levels the unit makes during the change will be reverted..
EXAMPLE: changeskills MINING \UNIT_ID set 0 3600
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

function effect(skill,unit,ctype,strength,save,dir)
	local skills = unit.status.current_soul.skills
	local skillid = df.job_skill[skill]
	local value = 0
	local found = false

	if skills ~= nil then
		for i,x in ipairs(skills) do
			if x.id == skillid then
				if dir == 1 then save = x.rating end
				found = true
				if ctype == 'fixed' then
					value = x.rating + strength
				end
				if ctype == 'percent' then
					percent = (100 + strength)/100
					value = x.rating*percent
				end
				if ctype == 'set' then
					value = strength
				end
				if dir == -1 then value = save end
				if value > 20 then value = 20 end
				if value < 0 then value = 0 end
				x.rating = value
			end
		end
	end

	if not found then
		utils = require 'utils'
		utils.insert_or_update(unit.status.current_soul.skills,{new = true, id = skillid, rating = 1},'id')
		skills = unit.status.current_soul.skills
		for i,x in ipairs(skills) do
			if x.id == skillid then
				if dir == 1 then save = x.rating end
				found = true
				if etype == 'fixed' then
					value = x.rating + strength
				end
				if etype == 'percent' then
					percent = (100 + strength)/100
					value = x.rating*percent
				end
				if etype == 'set' then
					value = strength
				end
				if dir == -1 then value = save end
				if value > 20 then value = 20 end
				if value < 0 then value = 0 end
				x.rating = value
			end
		end
	end
	return save
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
