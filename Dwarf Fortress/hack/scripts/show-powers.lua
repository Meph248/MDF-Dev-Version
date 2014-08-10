--Search for specific syndromes on an unit and display a report in an alert box.
--[[
	Usage succubus/show-powers <unit-id>
	Alt usage : select an unit then type succubus/show-powers in the dfhack terminal

	The syndromes must have a SYN_NAME matching one of the entries in the whitelists below.
--]]
if not dfhack.isMapLoaded() then qerror('Map is not loaded.') end

-- Used to make the syntax below easier
function Set (list)
	local set = {}
	for _, l in ipairs(list) do set[l] = true end
	return set
end

-- A SYN_NAME entered here is considered as passive upgrades (ie. an attribute buff)
local boostWhiteList = Set {
	-- Succubus
	'Protected by tentacles',
	'Focused thoughts (focus boost)',
	'Spasms (speed/strength boost)',
	'Courtesan (pheromones, entice)',
	'Soul eater (+250 physical attributes)',
	'Excited mind (no pain, no stun)',
	-- Orc
	'orcish turbo',
	'orcish courage',
	'orcish pain resistance'
}

-- A SYN_NAME is considered an active interaction (ie. a combat spell)
local interactionWhiteList = Set {
	-- Dwarf chocolate
	'Pyromancer (fireballs, directed ash, firejet)',
	-- Succubus
	'Corrupter',
	'Berserk rage',
	'Battle excitation',
	'Protective tentacles',
	'Torrid kiss',
	'Mind theft',
	'Necrosis chant',
	'Abyssal gaze',
	'Soul harvester',
	-- Orc
	'Hibernate',
	'Fairyfire',
	'Wasp cloud',
	'Disabling',
	'Crushing grip',
	'Consume souls',
	'Icebolt',
	'Static discharge',
	'Chill blood',
	'Astral vortex',
	'Tarot',
	'Warming rays',
	'Starcloak',
	-- Warlock
	'learnt Fire Ball',
	'learnt Dragon Fire',
	'learnt Incinerate',
	'learnt Freeze',
	'learnt Icicle',
	'learnt Arctic Wind',
	'learnt Blizzard',
	'learnt Frost Nova',
	'learnt Blind',
	'learnt Lightning',
	'learnt Chain Lightning',
	'learnt Shock',
	'learnt Gust',
	'learnt Bind',
	'learnt Petrify',
	'learnt Boulder',
	'learnt Stoneskin',
	'learnt Rock Slide',
	'learnt Haste',
	'learnt Slow',
	'learnt Blink',
	'learnt Arcane Missle',
	'learnt Arcane Armor';
	'learnt Heal',
	'learnt Greater Heal',
	'learnt Rejuvenate',
	'learnt Cleanse',
	'learnt Ward',
	'learnt Bless',
	'learnt Sanctify',
	'learnt Resurrect',
	'learnt Fortify',
	'learnt Holy Armor',
	'learnt Turn Undead',
	'learnt Holy',
	'learnt Curse',
	'learnt Necrosis',
	'learnt Enfeeble',
	'learnt Drain Life',
	'learnt Agony',
	'learnt Dark Pact',
	'learnt Shackle',
	'learnt Bone Armor',
	'learnt Raise Dead (friendly)',
	'learnt Raise Dead (violent)',
	'learnt Fury',
	'learnt Calm',
	'learnt Entangle',
	'learnt Barkskin',
	'learnt Poison',
	'learnt Berserk',
	'learnt Heroic Strength',
	'learnt War Cry',
	'learnt Battle Cry',
	'learnt Intimidate',
	'learnt Charge',
	'learnt Rally',
	'learnt Hide',
	'learnt Evade',
	'learnt Speed',
	'learnt Mark for Death',
	'learnt Poison Flask',
	'learnt Smoke Bomb'
}

-- Script begins
local foundBoost = {}
local foundInteraction = {}
local text = ''

local gui = require 'gui'
local dialog=require 'gui.dialogs'
local args = {...}
local unit

if not args[1] then
	unit = dfhack.gui.getSelectedUnit()
else
	unit = df.unit.find(args[1])
end

if not unit then qerror('Showpowers: Unit not found or selected.') end

-- Tries to redraw the screen to remove the twbt ASCII display. Does not work, suggestions are welcome.
function dialog.MessageBox:on_close()
	--print('Show powers dismissed')
	dfhack.screen.invalidate()
end

-- Check if the syn_name is in one of the whitelists and save it if needed.
function addSynName(syn_name)
	if boostWhiteList[syn_name] then
		table.insert(foundBoost, syn_name)
	elseif interactionWhiteList[syn_name] then
		table.insert(foundInteraction, syn_name)
	end
end

-- Search for the active syndromes and calls for the sorting function for all of them.
function getSyndrome()
	local synNames = {}
	local rawSyndrome, syn_id

	for _, syndrome in ipairs(unit.syndromes.active) do
		syn_id = syndrome.type
		rawSyndrome = df.syndrome.find(syn_id)
		if #rawSyndrome.syn_name > 0 then addSynName(rawSyndrome.syn_name) end
	end
end

-- Get the frst name or nickname
function getName(unitTarget)
	local name = dfhack.units.getVisibleName(unit)

	if not name.has_name then return 'This creature' end
	if string.len(name.nickname) > 0 then return "'"..name.nickname.."'" end

	return string.gsub(name.first_name, '^(.)', string.upper)
end

-- Creates a list of found syndrom and send it to a dialog box.
function showResults()
	local unitName = getName(unit)

	if #foundInteraction == 0 and #foundBoost == 0 then
		text = unitName..' has not received any bonus or interactions.'
	end

	if #foundBoost > 0 then
		text = unitName..' has received the following upgrades:'
		for _, v in pairs(foundBoost) do 
			text = text..NEWLINE..'- '..v
		end
	end

	if #foundInteraction > 0 then
		if #foundBoost > 0 then 
			text = text..NEWLINE..'and'
		else 
			text = unitName..' has'
		end

		text = text..' the following interactions:'

		text = text
		for _, v in pairs(foundInteraction) do 
			text = text..NEWLINE..'- '..v
		end
	end

	dialog.showMessage('Checking for powers', text)
end

getSyndrome()
showResults()
