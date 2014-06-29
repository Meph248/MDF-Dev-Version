--changeboolean.lua v1.0
--DO NOT USE - Causes crashes in the game when certain flags are toggled on and off, will investigate when time allows.
--[[
changeboolean - will change a series of true/false flags on a unit, currently not very useful
	BOOLEAN_TOKEN - boolean to change, separate multiple tokens with ‘+’
		valid tokens found here
	ID # - the units id number
		\UNIT_ID - when triggering with a syndrome
		\WORKER_ID - when triggering with a reaction
	(OPTIONAL) duration - sets a specified length of time for the changes to last (in in-game ‘ticks’)
		#
			DEFAULT: 0 - boolean changes will be permanent
			NOTE: Will set booleans back to false after effect wears off
EXAMPLE: changeboolean caged \UNIT_ID 3600
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

local function createcallback(unitTarget,etype)
	return function (resetboolean)
		unitTarget.flags1[etype] = false
	end
end

local function effect(etype,unitTarget,dur)
	unitTarget.flags1[etype] = true
	if dur ~= 0 then
		dfhack.timeout(time,'ticks',createcallback(unitTarget,etype))
	end
end

local types = args[1]
local unit = df.unit.find(tonumber(args[2]))
local dur = 0
if #args == 3 then dur = tonumber(args[3]) end
local typea = split(types,'+')

for i,etype in ipairs(typea) do
	effect(etype,unit,dur)
end
