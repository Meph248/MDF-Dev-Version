-- Captures custom reactions and make the appropriate dfhack calls.

local eventful = require 'plugins.eventful'
local utils = require 'utils'

--http://lua-users.org/wiki/StringRecipes  (removed indents since I am not using them)
function wrap(str, limit)--, indent, indent1)
	--indent = indent or ""
	--indent1 = indent1 or indent
	local limit = limit or 72
	local here = 1 ---#indent1
	return str:gsub("(%s+)()(%S+)()",	--indent1..str:gsub(
							function(sp, st, word, fi)
								if fi-here > limit then
									here = st -- - #indent
									return "\n"..word --..indent..word
								end
							end)
end

-- Simulate a canceled reaction message, save the reagents
local function cancelReaction(reaction, unit, input_reagents, message)
	local lines = utils.split_string(wrap(
			string.format("%s, %s cancels %s: %s.", dfhack.TranslateName(dfhack.units.getVisibleName(unit)), dfhack.units.getProfessionName(unit), reaction.name, message)
		) , NEWLINE)
	for _, v in ipairs(lines) do
		dfhack.gui.showAnnouncement(v, COLOR_RED)
	end

	for _, v in ipairs(input_reagents or {}) do
		v.flags.PRESERVE_REAGENT = true
	end
end

-- Can they even use it?
local function creatureIsAffected(unit, raw)
    local unitraws = df.creature_raw.find(unit.race)
    local casteraws = unitraws.caste[unit.caste]
    local unitracename = unitraws.creature_id
    local castename = casteraws.caste_id
	
	-- Check if they are on the allowed list
	for _, syndrome in ipairs(raw.material.syndrome) do
		for caste,creature in ipairs(syndrome.syn_affected_creature) do
			local affected_creature = creature.value
			local affected_caste = syndrome.syn_affected_caste[caste].value
			print(affected_creature .. ' vs ' .. unitracename .. ' and ' .. affected_caste .. ' vs ' .. castename)
			if affected_creature == unitracename and affected_caste == castename then return 1 end
		end
	end
	
    return nil
end

local function syndromeReaction(unit, synName, reaction, input_items, input_reagents)
	
	-- Go through all of the organics
	for _, raw in ipairs(df.global.world.raws.inorganics) do
	
		-- Find the one that matches our syndrome carrier name
        if raw and raw.id == synName then  
			
			if creatureIsAffected(unit, raw) then
			
				-- Add spell
				dfhack.run_script('addsyndrome', raw.id, unit.id)
				break
				
			else
			
				-- Refund it
				cancelReaction(reaction, unit, input_reagents, "unable to learn spell.")
				break
				
			end	
			
		end
		
    end
	
end

-- Reaction hook
eventful.onReactionComplete.orcReaction = function(reaction, unit, input_items, input_reagents, output_items, call_native)

	-- Make sure they're Orcs
	if reaction.code:find('LUA_HOOK_ORC_') then

		-- Check that it's a spell being learned
		if reaction.code:find('_LEARN_SPELL_') then
		
			-- Learn that spell!
			if reaction.code:find('_HIBERNATE') 		then syndromeReaction(unit, 'HIBERNATE_STONE_ORC', reaction, input_items, input_reagents)
			elseif reaction.code:find('_FAIRYFIRE') 	then syndromeReaction(unit, 'FAIRYFIRE_STONE_ORC', reaction, input_items, input_reagents)
			elseif reaction.code:find('_WASPCLOUD') 	then syndromeReaction(unit, 'WASPCLOUD_STONE_ORC', reaction, input_items, input_reagents)
			elseif reaction.code:find('_DISABLE') 		then syndromeReaction(unit, 'DISABLE_STONE_ORC', reaction, input_items, input_reagents) 		
			elseif reaction.code:find('_CRUSH')			then syndromeReaction(unit, 'CRUSH_STONE_ORC', reaction, input_items, input_reagents)
			elseif reaction.code:find('_CONSUME') 		then syndromeReaction(unit, 'CONSUME_STONE_ORC', reaction, input_items, input_reagents)
			elseif reaction.code:find('_ICEBOLT') 		then syndromeReaction(unit, 'ICEBOLT_STONE_ORC', reaction, input_items, input_reagents)
			elseif reaction.code:find('_STATIC') 		then syndromeReaction(unit, 'STATIC_STONE_ORC', reaction, input_items, input_reagents)
			elseif reaction.code:find('_CHILL') 		then syndromeReaction(unit, 'CHILL_STONE_ORC', reaction, input_items, input_reagents)
			elseif reaction.code:find('_VORTEX') 		then syndromeReaction(unit, 'VORTEX_STONE_ORC', reaction, input_items, input_reagents)
			elseif reaction.code:find('_TAROT') 		then syndromeReaction(unit, 'TAROT_STONE_ORC', reaction, input_items, input_reagents)
			elseif reaction.code:find('_WARMYRAY') 		then syndromeReaction(unit, 'WARMRAY_STONE_ORC', reaction, input_items, input_reagents)
			
			end
			
		-- Transformations?
		elseif reaction.code:find('_TRANSFORM_') then
			
			-- Druid
			if reaction.code:find('_DRUID') then
				syndromeReaction(unit, 'DRUID_STONE_M', reaction, input_items, input_reagents)
				syndromeReaction(unit, 'DRUID_STONE_F', reaction, input_items, input_reagents)
				
			-- Sorcerer
			elseif reaction.code:find('_SORCERER') then
				syndromeReaction(unit, 'SORCERER_STONE_M', reaction, input_items, input_reagents)
				syndromeReaction(unit, 'SORCERER_STONE_F', reaction, input_items, input_reagents)
				
			-- Frostskald
			elseif reaction.code:find('_FROSTSKALD') then
				syndromeReaction(unit, 'FROSTSKALD_STONE_M', reaction, input_items, input_reagents)
				syndromeReaction(unit, 'FROSTSKALD_STONE_F', reaction, input_items, input_reagents)
				
			-- Oracle
			elseif reaction.code:find('_ORACLE') then
				syndromeReaction(unit, 'ORACLE_STONE_M', reaction, input_items, input_reagents)
				syndromeReaction(unit, 'ORACLE_STONE_F', reaction, input_items, input_reagents)
			end
			
		end
		
	end
	
end

print('Orc reaction hook activated')