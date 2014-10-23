--Allows custom slab engraving.  Requires a reaction that starts with LUA_HOOK_ENGRAVE_SLAB that takes a NOT_ENGRAVED slab as a reagent (make sure to preserve the reagent).

local eventful = require 'plugins.eventful'
local utils = require 'utils'
local slab_types = {'memorial','craft shop sign','weaponsmith shop sign','armorsmith shop sign','general store sign','food shop sign'}

function engraveSlab(reaction,unit,job,input_items,input_reagents,output_items,call_native)
	for index,item in ipairs(job) do
		local slab = item
		if getmetatable(slab) == 'item_slabst' then
			allUnits = df.global.world.units.active
			names = {}
			ids = {}
			for i=#allUnits-1,0,-1 do	-- search list in reverse
				u = allUnits[i]
				if dfhack.units.isDead(u) and u.hist_figure_id ~= -1 and u.name.has_name then
					local name = dfhack.TranslateName(u.name)
					table.insert(names, name)
					table.insert(ids, u.hist_figure_id)
				end
			end
			local script=require('gui/script')
			script.start(function()
				local choiceok,choice=script.showListPrompt('Engrave Slab', 'What kind of slab should this be?', COLOR_LIGHTGREEN, slab_types)
				if choice ~= nil then
					slab.engraving_type = choice-1
				else
					slab.engraving_type = -1
				end				
				
				if slab.engraving_type == 0 and #ids > 0 then
					local choiceok,choice=script.showListPrompt('Create Memorial', 'Who would you like to memorialize?', COLOR_LIGHTGREEN, names)
					if choice ~= nil then
						id = ids[choice]
						slab.unk_bc = id --This is the histfig id.  This must be changed when dfhack is updated and this variable is given a proper name.
					else
						slab.unk_bc = -1
					end
				end
				
				local descriptionok,description=script.showInputPrompt('Engrave Slab','What should it say?',COLOR_WHITE)
				if description == '' then
					slab.engraving_type = -1
				else
				end
				slab.description=description
			end)
			break
		end
	end
end

dfhack.onStateChange.loadEngraveSlab = function(code)
	local registered_reactions
	if code==SC_MAP_LOADED then
		for i,reaction in ipairs(df.global.world.raws.reactions) do
			if string.starts(reaction.code,'LUA_HOOK_ENGRAVE_SLAB') then
				eventful.registerReaction(reaction.code,engraveSlab)
				registered_reactions = true
			end
		end
		if registered_reactions then
			print('Engrave Slab: Loaded.')
		end
	elseif code==SC_MAP_UNLOADED then
	end
end

-- if dfhack.init has already been run, force it to think SC_WORLD_LOADED to that reactions get refreshed
if dfhack.isMapLoaded() then dfhack.onStateChange.loadEngraveSlab(SC_MAP_LOADED) end