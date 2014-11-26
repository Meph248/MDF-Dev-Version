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
		dfhack.gui.showAnnouncement(v, COLOR_RED, true)
	end

	for _, v in ipairs(input_reagents or {}) do
		v.flags.PRESERVE_REAGENT = true
	end

	--unit.job.current_job.flags.suspend = true
end

-- Search the site for a creature
local function hasCreature(creatureId)
	local unitRaw
	for k, unit in ipairs(df.global.world.units.all) do
		unitRaw = df.global.world.raws.creatures.all[fnUnit.race]
		if unitRaw.creature_id == creatureId then return true end
	end

	return false
end
-- Make sure that we have the right creature on the site, add the effect
local function slothCreature(creatureId, reaction, unit, input_reagents)
	if hasCreature(creatureId) == false then
		cancelReaction(reaction, unit, input_reagents, "no creature in the area")
		return nil
	end

	if creatureId == 'TENTACLE_MONSTER' then
		dfhack.run_script('succubus/protective-tentacles', unit.id)
	end
end

-- Search the site for an invader
local function hasInvader()
	for k, unit in ipairs(df.global.world.units.all) do
		if unit.flags1.active_invader and not unit.flags1.caged and dfhack.units.isAlive(unit) then return true end
	end
	return false
end

-- Manages effects targeting invaders
local function invadersEffect(code, reaction, unit, input_reagents)
	if hasInvader() == false then
		cancelReaction(reaction, unit, input_reagents, "no invaders in the area")
		return nil
	end

	if code == 'SOW_DISCORD' then
		dfhack.run_script('succubus/crazed-invader', unit.id)
	elseif code == 'LURE_INVADERS' then
		dfhack.run_script('succubus/lure-invader')
	elseif code == 'DIMENSION_PULL' then
		dfhack.run_script('succubus/dimpull-invader', unit.id) -- todo catch the reagent's value
	end
end

-- Add a random skill from a defined set
local function addSkill(set, unit)
	local skillSet, roll

	if(set == 'BROKER') then
		dfhack.run_script('trainskill', unit.id, 'APPRAISAL', 15)
		skillSet = {'LYING', 'FLATTERY', 'RECORD_KEEPING'}
	elseif(set == 'CRAFTER') then
		skillSet = {'WOODCRAFT', 'STONECRAFT', 'METALCRAFT', 'GLASSMAKER', 'LEATHERWORK'}
	elseif(set == 'FARMER') then
		skillSet = {'PLANT', 'COOK', 'BREWING'}
	elseif(set == 'SOLDIER') then
		skillSet = {'SIEGEOPERATE', 'DODGING', 'ARMOR', 'MELEE_COMBAT', 'RANGED_COMBAT'}
	end

	roll = math.random(1, #skillSet)
	print("Skill increase : "..skillSet[roll])
	dfhack.run_script('trainskill', unit.id, skillSet[roll], 15)
	dfhack.run_script('succubus/influence', 'lust', unit.id)
end

-- Resize the preserved reagents to make those succubus sized
local function resizeReagents(input_items, input_reagents)
	local sitems = {}

	for i,x in ipairs(input_reagents) do
		if x.flags.PRESERVE_REAGENT then sitems[i] = input_items[i] end
	end

	for _,x in pairs(sitems) do
		x.maker_race = df.global.ui.race_id
	end
end

-- Reaction hook
eventful.onReactionComplete.fooccubusReaction = function(reaction, unit, input_items, input_reagents, output_items, call_native)

	-- GUI
	if reaction.code == 'LUA_HOOK_CHECK_POWERS' then
		dfhack.run_script('show-powers', unit.id)
	end

	-- upgrades
	if reaction.code:find('LUA_HOOK_IMPROVE_ITEM_DEFILE') then
		resizeReagents(input_items, input_reagents)

	-- fire
	elseif reaction.code == 'LUA_HOOK_FOOCCUBUS_RAIN_FIRE' then
		dfhack.run_script('syndromeweather', 'firebreath', 400, 100, 500)
		dfhack.gui.showAnnouncement('The sky darkens and fireballs strikes the earth.', COLOR_YELLOW)

	-- lust
	elseif reaction.code == 'LUA_HOOK_FOOCCUBUS_UPGRADE_EXCITATION' or
		reaction.code == 'LUA_HOOK_FOOCCUBUS_UPGRADE_LUST_SECRET' or
		reaction.code == 'LUA_HOOK_FOCCUBUS_UPGRADE_ABYSSAL_GAZE'
	then
		dfhack.run_script('succubus/influence', 'lust', unit.id)
	elseif reaction.code == 'LUA_HOOK_NIGHTMARE_BROKER' then addSkill('BROKER', unit)
	elseif reaction.code == 'LUA_HOOK_NIGHTMARE_CRAFTER' then addSkill('CRAFTER', unit)
	elseif reaction.code == 'LUA_HOOK_NIGHTMARE_FARMER' then addSkill('FARMER', unit)
	elseif reaction.code == 'LUA_HOOK_NIGHTMARE_SOLDIER' then addSkill('SOLDIER', unit)

	-- wrath
	elseif reaction.code == 'LUA_HOOK_DIMENSION_PULL' then
		invadersEffect('DIMENSION_PULL', reaction, unit, input_reagents)
		dfhack.run_script('succubus/influence', 'wrath',unit.id)
	elseif reaction.code == 'LUA_HOOK_FOOCCUBUS_UPGRADE_BERSERK' or
		reaction.code == 'LUA_HOOK_FOOCCUBUS_UPGRADE_NECROSIS_CHANT'
	then
		dfhack.run_script('succubus/influence', 'wrath', unit.id)

	-- pride
	elseif reaction.code == 'LUA_HOOK_FORGET_DEATH' then
		dfhack.run_script('succubus/forget-death', unit.id)
		dfhack.run_script('succubus/influence', 'pride', unit.id)

	-- greed

	-- sloth
	elseif reaction.code == 'LUA_HOOK_PROTECTIVE_TENTACLES' then
		slothCreature('TENTACLE_MONSTER', reaction, unit, input_reagents)
		dfhack.run_script('succubus/influence', 'sloth', unit.id)

	-- gluttony
	elseif reaction.code == 'LUA_HOOK_FOOCCUBUS_DEVOUR_SOUL' then
		dfhack.run_script('succubus/influence', 'gluttony', unit.id)

	-- envy
	elseif reaction.code == 'LUA_HOOK_SOW_DISCORD' then
		invadersEffect('SOW_DISCORD', reaction, unit, input_reagents)
		dfhack.run_script('succubus/influence', 'envy',unit.id)
	elseif reaction.code == 'LUA_HOOK_LURE_INVADERS' then
		invadersEffect('LURE_INVADERS', reaction, unit, input_reagents)
		dfhack.run_script('succubus/influence', 'envy',unit.id)
	elseif reaction.code == 'LUA_HOOK_CALL_SIEGE' then
		dfhack.run_script('succubus/callsiege', 100)
		dfhack.run_script('succubus/influence', 'envy', unit.id)

	-- Special summon
	elseif reaction.code == 'LUA_HOOK_SUMMON_OBSIDIAN_COLOSSUS' or
		reaction.code == 'LUA_HOOK_SUMMON_SPIRIT_OF_FIRE' or
		reaction.code == 'LUA_HOOK_SUMMON_NIGHTMARE' or
		reaction.code == 'LUA_HOOK_SUMMON_FROST_WRAITH' then
		creatureId = string.sub(reaction.code, 17)
		print(creatureId)
		dfhack.timeout(2, 'ticks', function() dfhack.run_script('succubus/fovunsentient', unit.id, creatureId) end)
	end
end

print('Succubus reaction hook activated')