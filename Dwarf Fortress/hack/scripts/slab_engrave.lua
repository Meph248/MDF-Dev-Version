--Allows custom slab engraving.  Requires a reaction that starts with LUA_HOOK_ENGRAVE_SLAB that takes a NOT_ENGRAVED slab as a reagent (make sure to preserve the reagent).

local eventful = require 'plugins.eventful'
local utils = require 'utils'

function engraveSlab(reaction,unit,job,input_items,input_reagents,output_items,call_native)
	for index,item in ipairs(job) do
		local slab = item
		if getmetatable(slab) == 'item_slabst' then
			script.start(function()
				local descriptionok,description=script.showInputPrompt('Slab','What should the slab say?',COLOR_WHITE)
				slab.description=description
				slab.engraving_type=0
			end)
			break
		end
	end
end

dfhack.onStateChange.loadEngraveSlab = function(code)
	local registered_reactions
	if code==SC_MAP_LOADED then
		--registered_reactions = {}
		for i,reaction in ipairs(df.global.world.raws.reactions) do
			if string.starts(reaction.code,'LUA_HOOK_ENGRAVE_SLAB') then
				eventful.registerReaction(reaction.code,engraveSlab)
				registered_reactions = true
			end
		end
		--if #registered_reactions > 0 then print('Construct Creature: Loaded') end
		if registered_reactions then
			print('Engrave Slab: Loaded.')
		end
	elseif code==SC_MAP_UNLOADED then
	end
end

-- if dfhack.init has already been run, force it to think SC_WORLD_LOADED to that reactions get refreshed
if dfhack.isMapLoaded() then dfhack.onStateChange.loadEngraveSlab(SC_MAP_LOADED) end