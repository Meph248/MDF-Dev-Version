--Lets you use temple workshops
args={...}

eventful = require 'plugins.eventful'
local mo = require 'makeown'
local fov = require 'fov'
local utils = require 'utils'

local debugMode = false
local deb=args[1]
if deb == 'd' then
	debugMode = true
end

local retainFactor = 360

local pantheon = {}
local altars = {}

function loadPantheon()
	pantheon = {}
	altars = {}
	--First get all the deities your citizens believe in
	for index,unit in pairs(df.global.world.units.all) do
		if ( unit.race == df.global.ui.race_id ) then
			--Find all deities worshipped by this unit
			histfig = df.historical_figure.find(unit.hist_figure_id)
			if histfig ~= nil then
				for index,link in pairs(histfig.histfig_links) do
					if getmetatable(link)=="histfig_hf_link_deityst" then
						godid = link.target_hf
						duplicate = false
						for i = 1, #pantheon, 1 do 
							if pantheon[i].id == godid then
								duplicate = true
								pantheon[i].belief = pantheon[i].belief + link.link_strength
								break
							end
						end
						if duplicate == false then
							goddata = {id=godid,belief=link.link_strength}
							table.insert(pantheon, goddata)
						end
					end
				end
			end
		end
	end
	for index,god in pairs(pantheon) do
		setDeityData(god,0)
		god.histfig = df.historical_figure.find(god.id)
		histfig = god.histfig
		god.name = dfhack.TranslateName(histfig.name)
		god.racedata = df.global.world.raws.creatures.all[histfig.race]
		god.castedata = god.racedata.caste[histfig.caste]
		god.sex = histfig.sex
		spheres = histfig.info.spheres
		god.spheres = {}
		for i,sphere in pairs(spheres) do
			table.insert(god.spheres,df.sphere_type[sphere])
		end
	end
end

function setDeityData(god,amount)
	if amount == nil then amount = 0 end
	local location = df.global.world.world_data.active_site[0].id
	local gid = god.id
	local data = dfhack.persistent.get('spheregod_'..gid..'_'..location)
	if data == nil then
		dfhack.persistent.save({key='spheregod_'..gid..'_'..location})
		data = dfhack.persistent.get('spheregod_'..gid..'_'..location)
		data.ints[1] = gid
		data.ints[2] = god.belief
		data.ints[3] = amount
		data.ints[4] = amount*retainFactor
		data:save()
	end
	if data ~= nil then
		data.ints[1] = gid
		data.ints[2] = god.belief
		data.ints[3] = data.ints[3] + amount*2 -- power goes up faster than belief rises
		data.ints[4] = data.ints[4] + amount
		if data.ints[3] < 0 then 
			data.ints[3] = 0
			data.ints[4] = 0
		elseif data.ints[3] > god.belief then 
			data.ints[3] = god.belief -- but then cap power at belief level
		end
		
		data:save()
	end
	god.strength = data.ints[3]
	god.happiness = data.ints[4]
	--printall(god)
	return god
end

loadPantheon()


--printall(df.global)
local function getItemValue(item)
	local basevalue = 1
	local matvalue = 1
	local qualityvalue = 1
	local improvementvalue = 0
	local stack_size = 1
	local wearvalue = 1
	
	if item then
		local itemname = df.item_type[item:getType()]:lower()
		
		if itemname == "coin" then basevalue = 0.02
		elseif itemname == "corpsepiece"
			or itemname == "corpse"
			or itemname == "remains"
			or itemname == "rock"
			then basevalue = 0
		elseif itemname == "glob"
			or itemname == "seeds"
			or itemname == "drink"
			or itemname == "powder_misc"
			or itemname == "liquid_misc"
			or itemname == "orthopedic_cast"
			then basevalue = 1
		elseif itemname == "fish_raw"
			or itemname == "fish"
			or itemname == "meat"
			or itemname == "egg"
			or itemname == "plant"
			or itemname == "leaves"
			then basevalue = 2
		elseif itemname == "rough"
			or itemname == "wood"
			or itemname == "boulder"
			then basevalue = 3
		elseif itemname == "bar"
			or itemname == "blocks"
			or itemname == "gem"
			or itemname == "skin_tanned"
			then basevalue = 5
		elseif itemname == "thread"
			then basevalue = 6
		elseif itemname == "cloth"
			then basevalue = 7
		elseif itemname == "siegeammo"
			or itemname == "traction_bench"
			then basevalue = 20
		elseif itemname == "window"
			or itemname == "statue"
			then basevalue = 25
		elseif itemname == "catapultparts"
			or itemname == "ballistaparts"
			or itemname == "trapparts"
			then basevalue = 30
		else basevalue = 10
		end
		
		if itemname == "weapon"
			or itemname == "armor"
			or itemname == "shoes"
			or itemname == "gloves"
			or itemname == "shield"
			or itemname == "helm"
			or itemname == "ammo"
			or itemname == "pants"
			or itemname == "trapcomp"
			or itemname == "tool"
			then basevalue = item.subtype.value
		end
		
		material = dfhack.matinfo.decode(item)
		if material then
			matvalue = material.material.material_value
		end
		
		quality = item:getQuality()		
		if quality == 0 then qualityvalue = 1
		elseif quality == 1 then qualityvalue = 2
		elseif quality == 2 then qualityvalue = 3
		elseif quality == 3 then qualityvalue = 4
		elseif quality == 4 then qualityvalue = 5
		elseif quality == 5 then qualityvalue = 12
		end
		
		if item.flags.artifact == true then qualityvalue = 120 end
		if item:isImprovable(nil,0,0) then
			for i = 0, #item.improvements-1, 1 do
				imp = item.improvements[i]
				imp_mat = dfhack.matinfo.decode(imp.mat_type, imp.mat_index)
				imp_mat_value = imp_mat.material.material_value
				if imp.quality == 0 then imp_quality = 1
				elseif imp.quality == 1 then imp_quality = 2
				elseif imp.quality == 2 then imp_quality = 3
				elseif imp.quality == 3 then imp_quality = 4
				elseif imp.quality == 4 then imp_quality = 5
				elseif imp.quality == 5 then imp_quality = 12
				end
				imp_value = 10 * imp_mat_value * imp_quality
				improvementvalue = improvementvalue + imp_value
			end
		end
		--improvementvalue = item:getImprovementsValue(-1) -- crashes the game
		stack_size = item.stack_size
		wearvalue = 1-(item:getWear()*.25)
	end

	return math.floor((((basevalue * matvalue * qualityvalue) + improvementvalue)*stack_size)*wearvalue)
end

function consecrate(reaction,unit,job,input_items,input_reagents,output_items,call_native)
	local building = dfhack.buildings.findAtTile(unit.pos)
	local location = df.global.world.world_data.active_site[0].id
	local data = dfhack.persistent.get('spheregod_altar_'..building.id..'_'..location)

	
	if data == nil then
		local script=require('gui/script')
		histfig = df.historical_figure.find(unit.hist_figure_id)
		local god_id = -1
		local godoptions = {}
		local opt_names = {}
		for index,link in pairs(histfig.histfig_links) do
			if getmetatable(link)=="histfig_hf_link_deityst" then
				godid = link.target_hf
				duplicate = false
				for i = 1, #godoptions, 1 do 
					if godoptions[i].id == godid then
						duplicate = true
						godoptions[i].belief = godoptions[i].belief + link.link_strength
						break
					end
				end
				if duplicate == false then
					goddata = {id=godid,belief=link.link_strength}
					table.insert(godoptions, goddata)
				end
			end
		end
		for index,god in pairs(godoptions) do
			god.histfig = df.historical_figure.find(god.id)
			histfig = god.histfig
			god.name = dfhack.TranslateName(histfig.name)
			god.racedata = df.global.world.raws.creatures.all[histfig.race]
			god.castedata = god.racedata.caste[histfig.caste]
			god.sex = histfig.sex
			god.spheres = histfig.info.spheres
			for i,sphere in pairs(spheres) do
				
			end
			local name = god.name
			table.insert(opt_names, name)
		end
		if (#opt_names > 0) then
			script.start(function()
				local choiceok,choice=script.showListPrompt('Consecration', 'Which deity will be worshipped here?', COLOR_LIGHTGREEN, opt_names)
				if choice ~= nil then
					god_id = godoptions[choice].id
					dfhack.persistent.save({key='spheregod_altar_'..building.id..'_'..location})
					data = dfhack.persistent.get('spheregod_altar_'..building.id..'_'..location)
					data.ints[1] = god_id
					data:save()
					dfhack.gui.showAnnouncement( dfhack.TranslateName(unit.name).." has dedicated the altar in the name of "..opt_names[choice].text.."." , COLOR_LIGHTGREEN, true)
				else
					dfhack.gui.showAnnouncement( dfhack.TranslateName(unit.name).." cancels "..reaction.name..": No deity chosen." , COLOR_RED, true)
				end
			end)
		else
			dfhack.gui.showAnnouncement( dfhack.TranslateName(unit.name).." cancels "..reaction.name..": Too atheistic." , COLOR_RED, true)
		end
	else
		gid = data.ints[1]
		this_god = nil
		for index,god in pairs(pantheon) do
			if god.id == gid then
				this_god = god
				break
			end
		end
		if this_god ~= nil then
			dfhack.gui.showAnnouncement(""..this_god.name..": "..this_god.strength, COLOR_RED, true)
		else
			dfhack.gui.showAnnouncement( dfhack.TranslateName(unit.name).." cancels "..reaction.name..": Altar has already been consecrated." , COLOR_RED, true)
		end
	end
end

function raiseBelief(u,god_id,amount)
	local merit = 0
	local unit = u
	if unit ~= nil and unit.hist_figure_id ~= -1 then
		local histfig = df.historical_figure.find(unit.hist_figure_id)
		local isWorshipper = false
		for index,link in pairs(histfig.histfig_links) do
			local this_link = link
			if getmetatable(this_link)=="histfig_hf_link_deityst" then
				if god_id == this_link.target_hf then
					isWorshipper = true
					if this_link.link_strength < 100 then
						this_link.link_strength = this_link.link_strength + amount
						if this_link.link_strength > 100 then
							this_link.link_strength = 100
						end
						--if debugMode == true then print('increasing: '..god_id..' to '..histfig.name.first_name..', level at '..this_link.link_strength) end
					else
						spreadBelief(god_id,amount)
					end
					merit = merit + this_link.link_strength
				end
			end
		end
		if isWorshipper == false then
			local this_link = df.histfig_hf_link_deityst:new()
			this_link.target_hf = god_id
			this_link.link_strength = amount
			if this_link.link_strength > 100 then
				this_link.link_strength = 100
			end
			--if debugMode == true then print('inserting: '..god_id..' to '..histfig.name.first_name..', level at '..this_link.link_strength) end
			histfig.histfig_links:insert('#',this_link)
		end
	end
	return merit
end

function spreadBelief(god_id,amount)
	allUnits = df.global.world.units.active
	local targets = {}
	local u
	
	for i=#allUnits-1,0,-1 do	-- search list in reverse
		u = allUnits[i]
		local valid = true
		if (dfhack.units.isCitizen(u) and u.hist_figure_id ~= -1) then
			histfig = df.historical_figure.find(u.hist_figure_id)
			for index,link in pairs(histfig.histfig_links) do
				if getmetatable(link)=="histfig_hf_link_deityst" then
					if god_id == link.target_hf and link.link_strength >= 100 then
						valid = false -- unit is already a firm believer
						break
					end
				end
			end
		end
		if valid == true then
			table.insert(targets, u)
		end
	end
	if debugMode == true then print('Spreading belief.  Targets: '..#targets) end
	local target = targets[math.random(#targets)]
	if target ~= nil then
		raiseBelief(target,god_id,amount)
	end
end

function service(reaction,unit,job,input_items,input_reagents,output_items,call_native)
	local building = dfhack.buildings.findAtTile(unit.pos)
	local location = df.global.world.world_data.active_site[0].id
	local this_god = nil
	local data = dfhack.persistent.get('spheregod_altar_'..building.id..'_'..location)
	if data == nil then
		dfhack.gui.showAnnouncement( dfhack.TranslateName(unit.name).." cancels "..reaction.name..": Altar has not been consecrated." , COLOR_RED, true)
	else
		gid = data.ints[1]
		for index,god in pairs(pantheon) do
			if god.id == gid then
				this_god = god
				break
			end
		end
	end
	product = reaction.products[0]
	if product ~= nil then
		if product.mat_type == 0 and product.mat_index == -1 then
			dfhack.maps.spawnFlow(unit.pos,5,0,-1,50)
		end
	end
	if this_god ~= nil then
		--printall(this_god)
		itemMerit = 0
		for index,item in ipairs(job) do
			itemcheck = item
			itemMerit = itemMerit + getItemValue(itemcheck)
		end
		histfig = df.historical_figure.find(unit.hist_figure_id)
		isWorshipper = false
		local merit = 1+math.ceil(itemMerit/10)
		raiseBelief(unit,this_god.id,merit)
		setDeityData(this_god,merit)
	end
end

function isEnemy(u)
	if u == nil then return false end
	if u.flags1.active_invader or 
		u.flags1.hidden_in_ambush or
		u.flags1.hidden_ambusher or
		u.flags1.invades or
		u.flags1.coward or
		u.flags1.invader_origin or
		u.flags2.underworld or
		u.flags2.visitor_uninvited then
			return true
	else
		return false
	end
end

function isPet(u,allowDead)
	--unitRaw = df.global.world.raws.creatures.all[u.race]
	--casteRaw = unitRaw.caste[u.caste]
	if u.flags1.tame
	and not (dfhack.units.isDead(u) and allowDead ~= true)
	and u.civ_id==df.global.ui.civ_id
	and not dfhack.units.isOpposedToLife(u)
	and not u.flags1.merchant 
	and not u.flags1.diplomat
	and not u.flags2.locked_in_for_trading
	then
		return true
	end
	return false
end

function isRoamingAnimal(u)
	unitRaw = df.global.world.raws.creatures.all[u.race]
	casteRaw = unitRaw.caste[u.caste]
	if u.flags2.roaming_wilderness_population_source
	and not dfhack.units.isDead(u)
	and not u.flags1.caged
	and not u.flags2.locked_in_for_trading
	and not u.flags1.tame
	and not dfhack.units.isOpposedToLife(u)
	and u.civ_id==-1
	and not u.flags1.merchant 
	and not u.flags1.diplomat
	and unitRaw.flags.LARGE_ROAMING
	and (casteRaw.flags.NATURAL or casteRaw.flags.PET or casteRaw.flags.PET_EXOTIC)
	and (u.animal.leave_countdown > 0 or u.flags2.roaming_wilderness_population_source_not_a_map_feature == false) then
		return true
	end
	return false
end

function getRandomUnit(mode,area,other)
	allUnits = df.global.world.units.active
	local targets = {}
	local u
	
	for i=#allUnits-1,0,-1 do	-- search list in reverse
		u = allUnits[i]
		local valid = false
		if (mode == nil)
			or (mode == 'citizen' and dfhack.units.isCitizen(u))
			or (mode == 'enemy' and isEnemy(u))
			or (mode == 'pet' and isPet(u))
			or (mode == 'wild' and isRoamingAnimal(u))
			then
			valid = true
		end
		if area ~= nil then
			pos = unit.pos
			local block = dfhack.maps.getTileBlock(pos.x,pos.y,pos.z)
			local designation = block.designation[pos.x%16][pos.y%16]
			if (area == 'outside' and designation.outside == false)
			or (area == 'inside' and  designation.outside == true)
			or (area == 'subterranean' and  designation.subterranean == false)
			or (area == 'surface' and  designation.subterranean == true)
			or (area == 'light' and  designation.light == false)
			or (area == 'dark' and  designation.light == true)
			then
				valid = false
			end
		end
		if other ~= nil then
			if (other == 'pregnant' and unit.relations.pregnancy_timer < 1)
			then
				valid = false
			end
		end
		
		if valid then
			table.insert(targets, u)
		end
	end
	if #targets > 0 then
		selectedunit = targets[math.random(#targets)]
		return selectedunit
	else
		return nil
	end
end


--create unit at pointer or given location. Usage e.g. "spawnunit DWARF 0 Dwarfy"
 
--Made by warmist, but edited by Putnam for the dragon ball mod to be used in reactions
 
--note that it's extensible to any autosyndrome reaction to spawn anything due to this; to use in autosyndrome, you want \COMMAND spawnunit CREATURE caste_number name \LOCATION
 
args={...}
function getCaste(race_id,caste_id)
    local cr=df.creature_raw.find(race_id)
    return cr.caste[caste_id]
end
function genBodyModifier(body_app_mod)
    local a=math.random(0,#body_app_mod.ranges-2)
    return math.random(body_app_mod.ranges[a],body_app_mod.ranges[a+1])
end
function getBodySize(caste,time)
    --todo real body size...
    return caste.body_size_1[#caste.body_size_1-1] --returns last body size
end
function genAttribute(array)
    local a=math.random(0,#array-2)
    return math.random(array[a],array[a+1])
end
function norm()
    return math.sqrt((-2)*math.log(math.random()))*math.cos(2*math.pi*math.random())
end
function normalDistributed(mean,sigma)
    return mean+sigma*norm()
end
function clampedNormal(min,median,max)
    local val=normalDistributed(median,math.sqrt(max-min))
    if val<min then return min end
    if val>max then return max end
    return val
end
function makeSoul(unit,caste)
    local tmp_soul=df.unit_soul:new()
    tmp_soul.unit_id=unit.id
    tmp_soul.name:assign(unit.name)
    tmp_soul.race=unit.race
    tmp_soul.sex=unit.sex
    tmp_soul.caste=unit.caste
    --todo skills,preferences,traits.
    local attrs=caste.attributes
    for k,v in pairs(attrs.ment_att_range) do
       local max_percent=attrs.ment_att_cap_perc[k]/100
       local cvalue=genAttribute(v)
       tmp_soul.mental_attrs[k]={value=cvalue,max_value=cvalue*max_percent}
    end
    for k,v in pairs(tmp_soul.traits) do
        local min,mean,max
        min=caste.personality.a[k]
        mean=caste.personality.b[k]
        max=caste.personality.c[k]
        tmp_soul.traits[k]=clampedNormal(min,mean,max)
    end
    unit.status.souls:insert("#",tmp_soul)
    unit.status.current_soul=tmp_soul
end
function CreateUnit(race_id,caste_id)
    local race=df.creature_raw.find(race_id)
    if race==nil then error("Invalid race_id") end
    local caste=getCaste(race_id,caste_id)
    local unit=df.unit:new()
    unit.race=race_id
    unit.caste=caste_id
    unit.id=df.global.unit_next_id
    df.global.unit_next_id=df.global.unit_next_id+1
	unit.relations.old_year=df.global.cur_year-5 -- everybody will be 15 years old
    if caste.misc.maxage_max==-1 then
        unit.relations.old_year=-1
    else
        unit.relations.old_year=df.global.cur_year+math.random(caste.misc.maxage_min,caste.misc.maxage_max)
    end
    unit.sex=caste.gender
		local num_inter=#caste.body_info.interactions  -- new for interactions
	unit.curse.anon_4:resize(num_inter) -- new for interactions
	unit.curse.anon_5:resize(num_inter) -- new for interactions
    local body=unit.body
    
    body.body_plan=caste.body_info
    local body_part_count=#body.body_plan.body_parts
    local layer_count=#body.body_plan.layer_part
    --components
    unit.relations.birth_year=df.global.cur_year-15
    --unit.relations.birth_time=??
    
    --unit.relations.old_time=?? --TODO add normal age
    local cp=body.components
    cp.body_part_status:resize(body_part_count)
    cp.numbered_masks:resize(#body.body_plan.numbered_masks)
    for num,v in ipairs(body.body_plan.numbered_masks) do
        cp.numbered_masks[num]=v
    end
    
    cp.layer_status:resize(layer_count)
    cp.layer_wound_area:resize(layer_count)
    cp.layer_cut_fraction:resize(layer_count)
    cp.layer_dent_fraction:resize(layer_count)
    cp.layer_effect_fraction:resize(layer_count)
    local attrs=caste.attributes
    for k,v in pairs(attrs.phys_att_range) do
        local max_percent=attrs.phys_att_cap_perc[k]/100
        local cvalue=genAttribute(v)
        unit.body.physical_attrs[k]={value=cvalue,max_value=cvalue*max_percent}
        --unit.body.physical_attrs:insert(k,{new=true,max_value=genMaxAttribute(v),value=genAttribute(v)})
    end
 
    body.blood_max=getBodySize(caste,0) --TODO normal values
    body.blood_count=body.blood_max
    body.infection_level=0
    unit.status2.body_part_temperature:resize(body_part_count)
    for k,v in pairs(unit.status2.body_part_temperature) do
        unit.status2.body_part_temperature[k]={new=true,whole=10067,fraction=0}
        
    end
    --------------------
    local stuff=unit.enemy
    stuff.body_part_878:resize(body_part_count) -- all = 3
    stuff.body_part_888:resize(body_part_count) -- all = 3
    stuff.body_part_relsize:resize(body_part_count) -- all =0
 
    --TODO add correct sizes. (calculate from age)
    local size=caste.body_size_2[#caste.body_size_2-1]
    body.size_info.size_cur=size
    body.size_info.size_base=size
    body.size_info.area_cur=math.pow(size,0.666)
    body.size_info.area_base=math.pow(size,0.666)
    body.size_info.area_cur=math.pow(size*10000,0.333)
    body.size_info.area_base=math.pow(size*10000,0.333)
    
    stuff.were_race=race_id
    stuff.were_caste=caste_id
    stuff.normal_race=race_id
    stuff.normal_caste=caste_id
    stuff.body_part_8a8:resize(body_part_count) -- all = 1
    stuff.body_part_base_ins:resize(body_part_count) 
    stuff.body_part_clothing_ins:resize(body_part_count) 
    stuff.body_part_8d8:resize(body_part_count) 
    unit.recuperation.healing_rate:resize(layer_count) 
    --appearance
   
    local app=unit.appearance
    app.body_modifiers:resize(#caste.body_appearance_modifiers) --3
    for k,v in pairs(app.body_modifiers) do
        app.body_modifiers[k]=genBodyModifier(caste.body_appearance_modifiers[k])
    end
    app.bp_modifiers:resize(#caste.bp_appearance.modifier_idx) --0
    for k,v in pairs(app.bp_modifiers) do
        app.bp_modifiers[k]=genBodyModifier(caste.bp_appearance.modifiers[caste.bp_appearance.modifier_idx[k]])
    end
    --app.unk_4c8:resize(33)--33
    app.tissue_style:resize(#caste.bp_appearance.style_part_idx)
    app.tissue_style_civ_id:resize(#caste.bp_appearance.style_part_idx)
    app.tissue_style_id:resize(#caste.bp_appearance.style_part_idx)
    app.tissue_style_type:resize(#caste.bp_appearance.style_part_idx)
    app.tissue_length:resize(#caste.bp_appearance.style_part_idx)
    app.genes.appearance:resize(#caste.body_appearance_modifiers+#caste.bp_appearance.modifiers) --3
    app.genes.colors:resize(#caste.color_modifiers*2) --???
    app.colors:resize(#caste.color_modifiers)--3
    
    makeSoul(unit,caste)
    
    df.global.world.units.all:insert("#",unit)
    df.global.world.units.active:insert("#",unit)
    --todo set weapon bodypart
    
    local num_inter=#caste.body_info.interactions
    unit.curse.anon_5:resize(num_inter)
    return unit
end
function findRace(name)
    for k,v in pairs(df.global.world.raws.creatures.all) do
        if v.creature_id==name then
            return k
        end
    end
    qerror("Race:"..name.." not found!")
end

function createFigure(trgunit,he)
    local hf=df.historical_figure:new()
    hf.id=df.global.hist_figure_next_id
    hf.race=trgunit.race
    hf.caste=trgunit.caste
	hf.profession = trgunit.profession
	hf.sex = trgunit.sex
    df.global.hist_figure_next_id=df.global.hist_figure_next_id+1
	hf.appeared_year = df.global.cur_year
	
	hf.born_year = trgunit.relations.birth_year
	hf.born_seconds = trgunit.relations.birth_time
	hf.curse_year = trgunit.relations.curse_year
	hf.curse_seconds = trgunit.relations.curse_time
	hf.birth_year_bias = trgunit.relations.birth_year_bias
	hf.birth_time_bias = trgunit.relations.birth_time_bias
	hf.old_year = trgunit.relations.old_year
	hf.old_seconds = trgunit.relations.old_time
	hf.died_year = -1
	hf.died_seconds = -1
	hf.name:assign(trgunit.name)
	hf.civ_id = trgunit.civ_id
	hf.population_id = trgunit.population_id
	hf.breed_id = -1
	hf.unit_id = trgunit.id
	
    df.global.world.history.figures:insert("#",hf)

	hf.info = df.historical_figure_info:new()
	hf.info.unk_14 = df.historical_figure_info.T_unk_14:new() -- hf state?
	--unk_14.region_id = -1; unk_14.beast_id = -1; unk_14.unk_14 = 0
	hf.info.unk_14.unk_18 = -1; hf.info.unk_14.unk_1c = -1
	-- set values that seem related to state and do event
	--change_state(hf, dfg.ui.site_id, region_pos)


--lets skip skills for now
--local skills = df.historical_figure_info.T_skills:new() -- skills snap shot
-- ...
--info.skills = skills


	he.histfig_ids:insert('#', hf.id)
	he.hist_figures:insert('#', hf)

	trgunit.flags1.important_historical_figure = true
	trgunit.flags2.important_historical_figure = true
	trgunit.hist_figure_id = hf.id
	trgunit.hist_figure_id2 = hf.id
    
    hf.entity_links:insert("#",{new=df.histfig_entity_link_memberst,entity_id=trgunit.civ_id,link_strength=100})
    --add entity event
    local hf_event_id=df.global.hist_event_next_id
    df.global.hist_event_next_id=df.global.hist_event_next_id+1
    df.global.world.history.events:insert("#",{new=df.history_event_add_hf_entity_linkst,year=trgunit.relations.birth_year,
        seconds=trgunit.relations.birth_time,id=hf_event_id,civ=hf.civ_id,histfig=hf.id,link_type=0})
    return hf
end
function createNemesis(trgunit,civ_id)
    local id=df.global.nemesis_next_id
    local nem=df.nemesis_record:new()
	local he=df.historical_entity.find(civ_id)
    nem.id=id
    nem.unit_id=trgunit.id
    nem.unit=trgunit
    nem.flags:resize(1)
    --not sure about these flags...
    nem.flags[4]=true
    nem.flags[5]=true
    nem.flags[6]=true
    nem.flags[7]=true
    nem.flags[8]=true
    nem.flags[9]=true
    --[[for k=4,8 do
        nem.flags[k]=true
    end]]
    df.global.world.nemesis.all:insert("#",nem)
    df.global.nemesis_next_id=id+1
    trgunit.general_refs:insert("#",{new=df.general_ref_is_nemesisst,nemesis_id=id})
    trgunit.flags1.important_historical_figure=true
    
    nem.save_file_id=he.save_file_id
	
    he.nemesis_ids:insert("#",id)
	he.nemesis:insert("#",nem)
    nem.member_idx=he.next_member_idx
    he.next_member_idx=he.next_member_idx+1
    --[[ local gen=df.global.world.worldgen
    gen.next_unit_chunk_id
    gen.next_unit_chunk_offset
    ]]
    nem.figure=createFigure(trgunit,he)
end

function PlaceUnit(race,caste,name,position,civ_id)

    local pos=position or copyall(df.global.cursor)
    if pos.x==-30000 then
        qerror("Point your pointy thing somewhere")
    end
    --race=findRace(race)

	
    local u=CreateUnit(race,tonumber(caste) or 0)
    u.pos:assign(pos)
		
    if name then
        u.name.first_name=name
        u.name.has_name=true
    end
    u.civ_id=civ_id or df.global.ui.civ_id

    
    local desig,ocupan=dfhack.maps.getTileFlags(pos)
    if ocupan.unit then
        ocupan.unit_grounded=true
        u.flags1.on_ground=true
    else
        ocupan.unit=true
    end
    
    if df.historical_entity.find(u.civ_id) ~= nil  then
        createNemesis(u,u.civ_id)
    end
	
	return u
end

--Create Item

function createItem(mat,itemType,quality,pos)
	if itemType[1] ~= -1 then
		local item=df['item_'..df.item_type[itemType[1]]:lower()..'st']:new()
		item.id=df.global.item_next_id
		df.global.world.items.all:insert('#',item)
		df.global.item_next_id=df.global.item_next_id+1
		if itemType[2]~=-1 then
			item:setSubtype(itemType[2])
		end
		item:setMaterial(mat.type)
		item:setMaterialIndex(mat.index)
		item:categorize(true)
		item.flags.removed=true
		item:setSharpness(1,0)
		item:setQuality(quality)
		item:setMakerRace(df.global.ui.race_id)
		dfhack.items.moveToGround(item,{x=pos.x,y=pos.y,z=pos.z})
		item.flags.on_ground=true
		--dfhack.items.moveToGround(item,pos)
		item:moveToGround(pos.x,pos.y,pos.z)
		return item
	else
		return nil
	end
end

--Turns the target 20 years old
function rejuvenate(unit)
	local current_year,newbirthyear

	if unit==nil then
		return
	end

	current_year=df.global.cur_year
	newbirthyear=current_year - 20
	if unit.relations.birth_year < newbirthyear then
		unit.relations.birth_year=newbirthyear
	end
end

function fullHeal(unit,resurrect)
	if unit then
		if resurrect then
			if unit.flags1.dead then
				unit.flags2.slaughter = false
				unit.flags3.scuttle = false
			end
			unit.flags1.dead = false
			unit.flags2.killed = false
			unit.flags3.ghostly = false
			--unit.unk_100 = 3
		end
		
		while #unit.body.wounds > 0 do
			unit.body.wounds:erase(#unit.body.wounds-1)
		end
		unit.body.wound_next_id=1

		unit.body.blood_count=unit.body.blood_max

		unit.status2.limbs_stand_count=unit.status2.limbs_stand_max
		unit.status2.limbs_grasp_count=unit.status2.limbs_grasp_max

		unit.flags2.has_breaks=false
		unit.flags2.gutted=false
		unit.flags2.circulatory_spray=false
		unit.flags2.vision_good=true
		unit.flags2.vision_damaged=false
		unit.flags2.vision_missing=false
		unit.flags2.breathing_good=true
		unit.flags2.breathing_problem=false

		unit.flags2.calculated_nerves=false
		unit.flags2.calculated_bodyparts=false
		unit.flags2.calculated_insulation=false
		unit.flags3.compute_health=true

		unit.counters.winded=0
		unit.counters.stunned=0
		unit.counters.unconscious=0
		unit.counters.webbed=0
		unit.counters.pain=0
		unit.counters.nausea=0
		unit.counters.dizziness=0

		unit.counters2.paralysis=0
		unit.counters2.fever=0
		unit.counters2.exhaustion=0
		unit.counters2.hunger_timer=0
		unit.counters2.thirst_timer=0
		unit.counters2.sleepiness_timer=0
		unit.counters2.vomit_timeout=0
		
		v=unit.body.components
		for i=0,#v.nonsolid_remaining - 1,1 do
			v.nonsolid_remaining[i] = 100	-- percent remaining of fluid layers (Urist Da Vinci)
		end

		v=unit.body.components
		for i=0,#v.layer_status - 1,1 do
			for j=0,#v.layer_status-1,1 do -- severed, leaking layers (Urist Da Vinci)
				v.layer_status[j].gone = 0
				v.layer_status[j].leaking = 0
			end
			v.layer_wound_area[i] = 0		-- wound contact areas (Urist Da Vinci)
			v.layer_cut_fraction[i] = 0		-- 100*surface percentage of cuts/fractures on the body part layer (Urist Da Vinci)
			v.layer_dent_fraction[i] = 0		-- 100*surface percentage of dents on the body part layer (Urist Da Vinci)
			v.layer_effect_fraction[i] = 0		-- 100*surface percentage of "effects" on the body part layer (Urist Da Vinci)
		end
		
		v=unit.body.components.body_part_status
		for i=0,#v-1,1 do
			v[i].on_fire = false
			v[i].missing = false
			v[i].organ_loss = false
			v[i].organ_damage = false
			v[i].muscle_loss = false
			v[i].muscle_damage = false
			v[i].bone_loss = false
			v[i].bone_damage = false
			v[i].skin_damage = false
			v[i].motor_nerve_severed = false
			v[i].sensory_nerve_severed = false
		end
		
		if unit.job.current_job and unit.job.current_job.job_type == df.job_type.Rest then
			unit.job.current_job = df.job_type.CleanSelf
		end
	end
end

flowtypes = {
miasma = 0,
mist = 1,
mist2 = 2,
dust = 3,
lavamist = 4,
smoke = 5,
dragonfire = 6,
firebreath = 7,
web = 8,
undirectedgas = 9,
undirectedvapor = 10,
oceanwave = 11,
seafoam = 12
}

function storm(stype,target,radius,number,itype,strength)
        local i
        local rando = dfhack.random.new()
        local snum = flowtypes[stype]
        local inum = 0
        if itype ~= 0 and itype ~= nil then
                inum = dfhack.matinfo.find(itype).index
        end

        local mapx, mapy, mapz = dfhack.maps.getTileSize()
        local xmin = target.x - radius
        local xmax = target.x + radius
        local ymin = target.y - radius
        local ymax = target.y + radius
        if xmin < 1 then xmin = 1 end
        if ymin < 1 then ymin = 1 end
        if xmax > mapx then xmax = mapx-1 end
        if ymax > mapy then ymax = mapy-1 end

        local dx = xmax - xmin
        local dy = ymax - ymin
        local pos = {}
        pos.x = 0
        pos.y = 0
        pos.z = 0

        for i = 1, number, 1 do
                local rollx = rando:random(dx) - radius
                local rolly = rando:random(dy) - radius

                pos.x = target.x + rollx
                pos.y = target.y + rolly
                pos.z = target.z
                
                local j = 0
				
				for j = 0, 100, 1 do
					block = dfhack.maps.ensureTileBlock(pos.x,pos.y,pos.z+j)
					if block then
						if block.designation[pos.x%16][pos.y%16].outside then
							pos.z = pos.z + j
							dfhack.maps.spawnFlow(pos,snum,0,inum,strength)
						end
					end
				end
        end
end

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

function eruption(etype,target,radius,depth)
        local i
        local rando = dfhack.random.new()
        local radiusa = split(radius,',')
        local rx = tonumber(radiusa[1])
        local ry = tonumber(radiusa[2])
        local rz = tonumber(radiusa[3])

        local mapx, mapy, mapz = dfhack.maps.getTileSize()
        local xmin = target.x - rx
        local xmax = target.x + rx
        local ymin = target.y - ry
        local ymax = target.y + ry
        local zmax = target.z + rz
        if xmin < 1 then xmin = 1 end
        if ymin < 1 then ymin = 1 end
        if xmax > mapx then xmax = mapx-1 end
        if ymax > mapy then ymax = mapy-1 end
        if zmax > mapz then zmax = mapz-1 end

        local dx = xmax - xmin
        local dy = ymax - ymin
        local hx = 0
        local hy = 0

        if dx == 0 then
                hx = depth
        else
                hx = depth/dx
        end

        if dy== 0 then
                hy = depth
        else
                hy = depth/dy
        end

        for i = xmin, xmax, 1 do
                for j = ymin, ymax, 1 do
                        for k = target.z, zmax, 1 do
                                if (math.abs(i-target.x) + math.abs(j-target.y)) <= math.sqrt(rx*rx+ry*ry) then
                                        block = dfhack.maps.ensureTileBlock(i,j,k)
										if block then
											dsgn = block.designation[i%16][j%16]
											size = math.floor(depth-hx*math.abs(target.x-i)-hy*math.abs(target.y-j))
											if size < 1 then size = 1 end
											dsgn.flow_size = size
											if etype == 'magma' then
												dsgn.liquid_type = true
											end
											flow = block.liquid_flow[i%16][j%16]
											flow.temp_flow_timer = 10
											flow.unk_1 = 10
											block.flags.update_liquid = true
											block.flags.update_liquid_twice = true
										end
                                end
                        end
                end
        end
end

local function setWeather(value)
	if value == 'clear' then value = 0
	elseif value == 'rain' then value = 1
	elseif value == 'snow' then value = 2
	end
	
	for i = 0, #df.global.current_weather-1, 1 do
		for j = 0, #df.global.current_weather[i]-1, 1 do
			df.global.current_weather[i][j]=value
		end
	end
end

-- Propel a unit
local function propelUnit(unit,xvel,yvel,zvel)
	if unit == nil then
		return false
	end
	if unit then
		local l = df.global.world.proj_list
		local lastlist=l
		l=l.next
		count = 0
		  while l do
			  count=count+1
				if l.next==nil then
						lastlist=l
				end
			  l = l.next
			end

		unitTarget=unit

		newlist = df.proj_list_link:new()
		lastlist.next=newlist
		newlist.prev=lastlist
		proj = df.proj_unitst:new()
		newlist.item=proj
		proj.link=newlist
		proj.id=df.global.proj_next_id
		df.global.proj_next_id=df.global.proj_next_id+1
		proj.unit=unitTarget
		proj.origin_pos.x=unitTarget.pos.x
		proj.origin_pos.y=unitTarget.pos.y
		proj.origin_pos.z=unitTarget.pos.z
		proj.prev_pos.x=unitTarget.pos.x
		proj.prev_pos.y=unitTarget.pos.y
		proj.prev_pos.z=unitTarget.pos.z
		proj.cur_pos.x=unitTarget.pos.x
		proj.cur_pos.y=unitTarget.pos.y
		proj.cur_pos.z=unitTarget.pos.z
		proj.flags.no_impact_destroy=true
		proj.flags.piercing=true
		proj.flags.parabolic=true
		proj.flags.unk9=true
		proj.speed_x=xvel
		proj.speed_y=yvel
		proj.speed_z=zvel
		unitoccupancy = dfhack.maps.getTileBlock(unitTarget.pos).occupancy[unitTarget.pos.x%16][unitTarget.pos.y%16]
		if not unitTarget.flags1.on_ground then 
				unitoccupancy.unit = false 
		else 
				unitoccupancy.unit_grounded = false 
		end
		unitTarget.flags1.projectile=true
		unitTarget.flags1.on_ground=false
		return true
	end
end

local function slam(unit)
	return propelUnit(unit,0,0,100000)
end

local function slamKill(unit)
	return propelUnit(unit,0,0,10000000)
end

local function fling(unit,direction,angle,power)
		local phi = (direction)*(math.pi/180)
		local theta = (90-angle)*(math.pi/180)
		local radius = power
		local yc = math.floor(radius * math.sin(theta) * math.cos(phi))
		local xc = math.floor(radius * math.sin(theta) * math.sin(phi))
		local zc = math.floor(radius * math.cos(theta))
		propelUnit(unit,xc,yc,zc)
end

local function rocksFall(pos,allowMeteor)
	local x = pos.x
	local y = pos.y
	local z=pos.z
	while true do
		local block = dfhack.maps.ensureTileBlock(x,y,z)
		if block then
			tiletype = block.tiletype[pos.x%16][pos.y%16]
			if tiletype == 219 or tiletype == 440 or tiletype == 265 then
				z = z-1
				createItem({type=0,index=0},{4,-1},0,{x=x,y=y,z=z})
				return true
			end
			z = z+1
		else
			if allowMeteor == true then
				z = z-1
				createItem({type=0,index=0},{4,-1},0,{x=x,y=y,z=z})
				return true
			else
				return false
			end
		end
	end
end

local function torment(unit)
	all_parts = df.creature_raw.find(unit.race).caste[unit.caste].body_info.body_parts
	part_id = 0--math.random(#all_parts-1)
	local bp=all_parts[part_id]
	local body=unit.body
	--body.components.body_part_status[part_id].missing=true
	local wid=body.wound_next_id
	body.wound_next_id=wid+1
	wound = {new=true,id=wid,
		parts={
		{new=true,body_part_id=part_id,pain = 1200, nausea = 1200, dizziness = 1200, paralysis = 1200}
		}}
	body.wounds:insert("#",wound)
	return true
end

local function thoughtIsNegative(thought)
	return df.unit_thought_type.attrs[thought.type].value:sub(1,1)=='-' and df.unit_thought_type[thought.type]~='LackChairs'
end

local function removeBadThoughts(unit)
	success = false
	if unit then
		if dfhack.units.isCitizen(unit) then
			for i=#unit.status.recent_events-1,0,-1 do
				thought = unit.status.recent_events[i]
				if thoughtIsNegative(thought) then
					unit.status.recent_events:erase(i)
					success = true
				end
			end
		end
	end
	return success
end

local function cleanUnit(unit)
	success = false
	if unit then
		for i=#unit.body.spatters-1,0,-1 do
			spatter = unit.body.spatters[i]
			unit.body.spatters:erase(i)
			success = true
		end
	end
	return success
end

local function disarm(unit)
	success = false
	inventory = unit.inventory
	for p=#inventory-1, 0, -1 do
		item = inventory[p].item
		for g = #item.general_refs-1, 0, -1 do
			if getmetatable(item.general_refs[g]) == 'general_ref_unit_holderst' then
				item.general_refs:erase(g)
			end
		end
		inventory:erase(p)
		item.flags.in_inventory = false
		item.flags.on_ground = true
		dfhack.items.moveToGround(item,u.pos)
		success = true
	end
	return success
end

local function tameAnimal(unit)
	unit.flags1.tame = true
	unit.training_level = df.animal_training_level.WellTrained
	mo.make_own(unit)
end

-- Remove the invader marks from an unit at the cost of a weird entity description
local function pacify(unit)
	if not unit then return false end

	mo.make_own(unit)
	mo.make_citizen(unit)
	-- Taking down all the hostility flags
	unit.flags1.marauder = false
	unit.flags1.active_invader = false
	unit.flags1.hidden_in_ambush = false
	unit.flags1.hidden_ambusher = false
	unit.flags1.invades = false
	unit.flags1.coward = false
	unit.flags1.invader_origin = false
	unit.flags2.underworld = false
	unit.flags2.visitor_uninvited = false
	unit.invasion_id = -1
	unit.relations.group_leader_id = -1
	unit.relations.last_attacker_id = -1

	-- Replace the enemy links with "former prisoner"
	hf = utils.binsearch(df.global.world.history.figures, unit.hist_figure_id, 'id')
	for k, v in ipairs(hf.entity_links) do
		if 
			df.histfig_entity_link_enemyst:is_instance(v) and 
			(v.entity_id == df.global.ui.civ_id or v.entity_id == df.global.ui.group_id) 
		then
			newLink = df.histfig_entity_link_former_prisonerst:new()
			newLink.entity_id = v.entity_id
			newLink.link_strength = v.link_strength
			hf.entity_links[k] = newLink
			v:delete()

			
		end
	end

	-- Make DF forget about the calculated enemies (ported from fix/loyaltycascade)
	if not (unit.enemy.enemy_status_slot == -1) then
		i = unit.enemy.enemy_status_slot
		unit.enemy.enemy_status_slot = -1
	end

end

local function smite(unit,sphere,power)
	success = false
	if power == nil then power = 1 end
	if unit == nil or sphere == nil then return end
	
	pos = unit.pos
	
	if sphere == 'WATER'
	or sphere == 'BOUNDARIES'
	or sphere == 'COASTS'
	or sphere == 'OCEANS'
	or sphere == 'LAKES'
	or sphere == 'RIVERS'
	or sphere == 'RAIN'
	then
		str = math.floor(power/20)
		success = eruption('water',pos,str..','..str..','..str,7)
	elseif sphere == 'MOUNTAINS'
	or sphere == 'CAVERNS'
	or sphere == 'MINERALS'
	then
		success = rocksFall(unit)
	elseif sphere == 'FIRE'
	or sphere == 'SUN'
	then
		targetPart = math.random(#unit.status2.body_part_temperature)-1
		if unit.status2.body_part_temperature[targetPart].whole < 10250 then unit.status2.body_part_temperature[targetPart].whole = 10250 end
		unit.status2.body_part_temperature[targetPart].whole = unit.status2.body_part_temperature[targetPart].whole + power
		success = true
	elseif sphere == 'VOLCANOS'
	then
		success = eruption('magma',pos,power..','..power..','..power,7)
	elseif sphere == 'WIND'
	or sphere == 'STORMS'
	then
		success = fling(unit,math.random(360),math.random(90),10000 * power)
	elseif sphere == 'CHAOS'
	or sphere == 'WAR'
	then
		unit.mood = 7 -- berserk
		success = true
	elseif sphere == 'MISERY'
	then
		unit.mood = 5 -- melancholy
		success = true
	elseif sphere == 'TORTURE'
	then
		success = torment(unit)
	else
		propelUnit(unit,0,0,10000 * power)
	end
	
end

local function blessing(unit,sphere,power)

	local success = false
	
	if sphere == 'STRENGTH'
	then
		unit.body.physical_attrs.STRENGTH.value=unit.body.physical_attrs.STRENGTH.value + power
		success = true
	elseif sphere == 'DANCE'
	then
		unit.status.current_soul.mental_attrs.KINESTHETIC_SENSE.value = unit.status.current_soul.mental_attrs.KINESTHETIC_SENSE.value + power
		success = true
	elseif sphere == 'HAPPINESS'
	or sphere == 'REVELRY'
	then
		removeBadThoughts(unit)
		success = true
	elseif sphere == 'HEALING'
	then
		fullHeal(unit)
		success = true
	end
	return success
end

--Blessing (do small good things)
--Curse (do small bad things)
--Sign (do small neutral things)
--Gift (grant a rare gift)
--Rescue (perform a major act to save from danger)


eventful.onUnitDeath.bla=function(u_id)
	local unit = df.unit.find(u_id)
	local pos = unit.pos
	for index,god in pairs(pantheon) do
		if math.random(100) < god.strength/100 then -- this needs adjustment
			sphere = god.spheres[math.random(#god.spheres)]
			
		end
	end
end
eventful.onItemCreated.bla=function(i_id)
	for index,god in pairs(pantheon) do
		if math.random(100) < god.strength/100 then -- this needs adjustment
			sphere = god.spheres[math.random(#god.spheres)]
			
			duplicate = 0
			improve = 0
			
			local item = df.item.find(i_id)
			local pos = item.pos
			local material = dfhack.matinfo.decode(item)
			local item_type = item:getType()
			local item_subtype = item:getSubtype()
			local item_string = df.item_type[item_type]:lower()
			local matflags = material.material.flags
			
			if (sphere == 'MINERALS' and item_string == 'boulder' and matflags.IS_STONE)
			or (sphere == 'METALS' and item_string == 'bar' and matflags.IS_METAL)
			or (sphere == 'TREES' and item_string == 'wood' and matflags.WOOD)
			or (sphere == 'JEWELS' and (item_string == 'smallgem' or item_string == 'rough'))
			or (sphere == 'FORTRESSES' and item_string == 'blocks')
			then
				duplicate = 1
			end
			
			is_jewelry = false
			is_sculpture = false
			is_finished_good = false
			is_clothing = false
			is_armor = false
			
			if item_string == 'crown'
			or item_string == 'ring'
			or item_string == 'earring'
			or item_string == 'bracelet'
			or item_string == 'amulet'
			then
				is_jewelry = true
			elseif item_string == 'figurine'
			or item_string == 'statue'
			then
				is_sculpture = true
			elseif item_string == 'armor'
			or item_string == 'pants'
			or item_string == 'shoes'
			or item_string == 'helm'
			or item_string == 'gloves'
			then
				is_clothing = true
				if item:getEffectiveArmorLevel() > 0 then
					is_armor = true
				end
			end
			
			if is_jewelry == true
			or item_string == 'figurine'
			or item_string == 'scepter'
			or item_string == 'goblet'
			or item_string == 'instrument'
			or item_string == 'toy'
			or item_string == 'totem'
			or item_string == 'gem'
			then
				is_finished_good = true
			end
			
			if (sphere == 'BEAUTY' and is_finished_good == true)
			or (sphere == 'CRAFTS' and is_finished_good == true)
			or (sphere == 'LABOR' and is_finished_good == true)
			or (sphere == 'CREATION' and is_finished_good == true)
			or (sphere == 'ART' and is_finished_good == true)
			or (sphere == 'PAINTING' and is_finished_good == true)
			or ((sphere == 'WAR' or sphere == 'FORTRESSES') and is_armor == true)
			or (sphere == 'WAR' and item_string == 'weapon')
			or (sphere == 'MINERALS' and matflags.IS_STONE)
			or (sphere == 'METALS' and matflags.IS_METAL)
			or (sphere == 'TREES' and matflags.WOOD)
			then
				improve = 1
			end
			
			if ((sphere == 'MUSIC' or sphere == 'SONG')  and item_string == 'instrument')
			then
				improve = 2
			end
			
			if (sphere == 'JEWELS' and item_string == 'gem')
			then
				improve = 3
			end
			
			if duplicate > 0 then
				if debugMode == true then print('duplicated item: '..item_string) end
				createItem(material,{item_type,item_subtype},duplicate,pos)
			end
			
			if improve > 0 then
				if debugMode == true then print('improved item: '..item_string) end
				
				if item:getQuality() < 5 then
					item:setQuality((item:getQuality() + improve))
				end
				if item:getQuality() > 5 then
					item:setQuality(5)
				end
			end
			
		end
	end
end
eventful.enableEvent(eventful.eventType.UNIT_DEATH,5)
eventful.enableEvent(eventful.eventType.ITEM_CREATED,5)

function dailyEffect(god)
	if math.random(100) < god.strength/100 then -- this needs adjustment
		sphere = god.spheres[math.random(#god.spheres)]
		success = false
		
		power = god.strength/100
		
		area = nil
		
		if sphere == 'WEATHER'
		or sphere == 'LIGHTNING'
		or sphere == 'RAIN'
		or sphere == 'RAINBOWS'
		or sphere == 'STORMS'
		or sphere == 'THUNDER'
		or sphere == 'WIND'
		or sphere == 'SUN'
		then
			area = 'surface'
		elseif sphere == 'CAVERNS'
		or sphere == 'MOUNTAINS'
		or sphere == 'EARTH'
		or sphere == 'METALS'
		or sphere == 'MINERALS'
		or sphere == 'JEWELS'
		then
			area = 'subterranean'
		elseif sphere == 'LIGHT'
		or sphere == 'DAY'
		or sphere == 'DAWN'
		then
			area = 'light'
		elseif sphere == 'DARKNESS'
		or sphere == 'NIGHT'
		or sphere == 'DUSK'
		then
			area = 'dark'
		end
		
		if sphere == 'RAIN'
		or sphere == 'RAINBOWS'
		then
			setWeather('rain')
		elseif sphere == 'SUN'
		then
			setWeather('clear')
		end
		
		if sphere == 'PLANTS' or sphere == 'AGRICULTURE'
		then
			for i = 0, #df.global.world.plants.shrub_wet-1, 1 do
				df.global.world.plants.shrub_wet[i].grow_counter = df.global.world.plants.shrub_wet[i].grow_counter + 10000*power
			end
		elseif sphere == 'TREES'
		then
			for i = 0, #df.global.world.plants.tree_wet-1, 1 do
				df.global.world.plants.tree_wet[i].grow_counter = df.global.world.plants.tree_wet[i].grow_counter + 10000*power
			end
		elseif sphere == 'ANIMALS'
		then
			animal = getRandomUnit("wild",area)
			if animal ~= nil then
				tameAnimal(animal)
			end
		elseif sphere == 'EARTH' or sphere == 'NATURE' or sphere == 'RAIN'
		then
			for i = 0, #df.global.world.plants.shrub_wet-1, 1 do
				df.global.world.plants.shrub_wet[i].grow_counter = df.global.world.plants.shrub_wet[i].grow_counter + 3000*power
			end
			for i = 0, #df.global.world.plants.tree_wet-1, 1 do
				df.global.world.plants.tree_wet[i].grow_counter = df.global.world.plants.tree_wet[i].grow_counter + 3000*power
			end
		end
		if sphere == 'NATURE' and math.random(3) == 1 then
			animal = getRandomUnit("wild",area)
			if animal ~= nil then
				tameAnimal(animal)
			end
		end
		
		enemy = getRandomUnit("enemy",area)
		
		if enemy ~= nil then
			success = smite(enemy,sphere,power)
		end
		
		if sphere == 'BIRTH'
		or sphere == 'CHILDREN'
		or sphere == 'FERTILITY'
		or sphere == 'FAMILY'
		then
			citizen = getRandomUnit(nil,area,"pregnant")
			if citizen ~= nil then
				citizen.relations.pregnancy_timer = math.ceil(citizen.relations.pregnancy_timer/4)
			end
		end
		
		if success == false then
			citizen = getRandomUnit("citizen",area)
			if citizen ~= nil then
				success = blessing(citizen,sphere,power)
			end
		end
		
	end
end

local last_check = -1

function update()
	if last_check ~= df.global.cur_season_tick then 
		last_check = df.global.cur_season_tick
		if math.floor(df.global.cur_season_tick/120)==df.global.cur_season_tick/120 then -- once a day
			for index,god in pairs(pantheon) do
				setDeityData(god,-1)
				dailyEffect(god)
			end
			if math.floor(df.global.cur_season_tick/840)==df.global.cur_season_tick/840 then -- once a week
				if math.floor(df.global.cur_season_tick/3360)==df.global.cur_season_tick/3360 then -- once a month
					loadPantheon()
					if df.global.cur_season_tick == 0 then -- once a season
						if df.global.cur_year_tick == 0 then -- once a year
						end
					end
				end
			end
		end
	end
	dfhack.timeout(5,"ticks",function() update() end)
end

dfhack.onStateChange.load = function(code)
	local registered_reactions
	if code==SC_MAP_LOADED then
		--registered_reactions = {}
		for i,reaction in ipairs(df.global.world.raws.reactions) do
			if string.starts(reaction.code,'LUA_HOOK_PANTHEON_CONSECRATE') then
				eventful.registerReaction(reaction.code,consecrate)
				registered_reactions = true
			elseif string.starts(reaction.code,'LUA_HOOK_PANTHEON_SERVICE') then
				eventful.registerReaction(reaction.code,service)
				registered_reactions = true
			end
		end
		if registered_reactions then
			loadPantheon()
			print('Pantheon: Loaded.')
			update()
		end
	elseif code==SC_MAP_UNLOADED then
	end
end

-- if dfhack.init has already been run, force it to think SC_WORLD_LOADED to that reactions get refreshed
if dfhack.isMapLoaded() then dfhack.onStateChange.load(SC_MAP_LOADED) end

--[[
Just some vague possibilities

AGRICULTURE - affects crop yields, animal birth rates, and rain

NATURE - affects rain, sun, water, weather, animals, and plants
ANIMALS - affects animal behavior
PLANTS - affects crops, herbalism, and trees
TREES - affects trees

WEATHER
WIND
RAIN - affects rainfall, fertility, plant growth, and trees
RAINBOWS - affects rainfall and thoughts about rain
LIGHTNING - affects rainfall events
THUNDER - affects rainfall events
STORMS - affects rainfall events

SKY
SUN
STARS
MOON
MIST

DAWN - affects behavior of night creatures
DAY - affects behavior of night creatures
DUSK - affects behavior of night creatures
TWILIGHT - affects behavior of night creatures
NIGHT - affects behavior of night creatures
LIGHT - affects behavior of night creatures and things above ground
DARKNESS - affects behavior of night creatures and things below ground
DREAMS - affects behavior of night creatures and sleep
NIGHTMARES - affects behavior of night creatures and sleep

WATER - affects all things relating to water
BOUNDARIES - ???
COASTS - affects fish yields, drowning, and ocean creature behavior
OCEANS - affects fish yields, drowning, and ocean creature behavior
LAKES - affects fish yields, drowning, and lake creature behavior
RIVERS - affects fish yields, drowning, and river creature behavior
FISH - affects fishing yields and water creature behavior
FISHING - affects fishing yields
HUNTING - affects hunting yields

MUCK - affects contaminants

BEAUTY - affects craft value
CRAFTS - affects craft value
LABOR - affects craft value
CREATION - affects birth and crafts
ART - affects craft, and to a small extent parties
PAINTING - affects craft, especially engravings

LOVE - affects marriage and friendships
MARRIAGE - affects marriage and fertility
FERTILITY - affects fertility of all creatures
PREGNANCY - affects fertility and birth of all creatures
BIRTH - affects birth and littersize of all creatures
YOUTH - affects behavior of children
CHILDREN - affects behavior of children
FAMILY - affects behavior of children and family bonds

DEATH - affects all causes of death
DISEASE - affects syndromes and contiminants
HEALING - affects recovery time
REBIRTH - affects recovery time
DEFORMITY - affects syndromes, transformations, and craft value
LONGEVITY - affects aging
SUICIDE - affects insanity

BLIGHT - affects plant yields and syndromes

CAVERNS - affects things found in caverns
MOUNTAINS - affects things found in mountains
EARTH - affects things found underground
METALS - affects metals
MINERALS - affects minerals
JEWELS - affects gems
SALT - oceans/caverns?

TRADE - affects trading
WEALTH - affects value of items

CHARITY - benefits for those in need
GENEROSITY - benefits for those in need
SACRIFICE - benefits for those in need
JEALOUSY - harm for those doing too well

TORTURE - affects impact of bad thoughts and pain
MISERY - affects impact of bad thoughts
CONSOLATION - affects impact of bad thoughts

HAPPINESS - affects impact of good thoughts, especially parties
REVELRY - affects benefit of parties and good thoughts in general
FESTIVALS - affects benefit of parties
DANCE - affects benefit of parties
SONG - affects benefit of parties and social behavior
MUSIC - affects benefit of parties and crafts
POETRY - affects social behavior and crafts
WRITING - affects social behavior and crafts
SPEECH - affects social behavior
PERSUASION - affects social behavior
INSPIRATION - affects crafts and social behavior
SILENCE - affects harm done by parties

SCHOLARSHIP - affects crafts and knowledge
WISDOM - affects crafts, knowledge, and social behavior

FORTRESSES - affects defense against enemies
CHAOS - affects crime, war, and insanity
WAR - affects morale in battle and wars
COURAGE - affects morale in battle
VALOR - affects morale in battle
VICTORY - affects morale in battle
PEACE - affects ending war

LOYALTY - affects betrayal
OATHS - affects oath keeping
LAWS - affects crimes and punishment
ORDER - affects crimes, punishment, and tantrums
FREEDOM - affects crimes and imprisonment
JUSTICE - affects crime and punishment
LUST - affects fertility and crime
DEPRAVITY - affects crime and fertility
MURDER - affects murders
THEFT - affects theft
DISCIPLINE - affects length of breaks and crime
DUTY - affects length of breaks and tantrums

TREACHERY - affects betrayal
TRICKERY - affects sneaking
LIES - affects lies
TRUTH - affects lies

FAME - ???
RUMOR - ???

FATE - affects luck
GAMBLING - affects luck
LUCK - affects luck
GAMES - affects luck

FIRE - affects fire, metals, sun, and magma
VOLCANOS - affects magma

FOOD - affects hunger levels

FORGIVENESS - affects revenge
REVENGE - affects revenge
MERCY - affects revenge

BALANCE - normalizes stats

THRALLDOM - affects undead behavior

TRAVELERS - affects caravans

HOSPITALITY - affects caravans

RULERSHIP - affects nobles

SEASONS - different effects based on seasons

STRENGTH - affects strength


Parent/child relationships (note that a sphere can have more than one parent):

     SPHERE_NATURE
        SPHERE_ANIMALS - pets to help you
           SPHERE_FISH - better fishing yields
        SPHERE_PLANTS - better gathering/farming
           SPHERE_TREES - faster-growing trees
     SPHERE_ART - 
        SPHERE_DANCE
        SPHERE_MUSIC
        SPHERE_PAINTING
        SPHERE_POETRY
        SPHERE_SONG
     SPHERE_BOUNDARIES
        SPHERE_COASTS
     SPHERE_COURAGE
        SPHERE_VALOR
     SPHERE_EARTH
        SPHERE_METALS
        SPHERE_MINERALS
        SPHERE_SALT
     SPHERE_WATER
        SPHERE_LAKES
        SPHERE_OCEANS
        SPHERE_RIVERS
        SPHERE_RAIN
     SPHERE_WEATHER
        SPHERE_LIGHTNING
        SPHERE_RAIN
        SPHERE_RAINBOWS
        SPHERE_STORMS
        SPHERE_THUNDER
        SPHERE_WIND
Friend relationships:

     SPHERE_AGRICULTURE - affects farming yields
        SPHERE_FOOD
        SPHERE_FERTILITY
        SPHERE_RAIN
     SPHERE_ANIMALS - affects animal behavior
        SPHERE_PLANTS
     SPHERE_ART - affects engravings
        SPHERE_INSPIRATION
        SPHERE_BEAUTY
     SPHERE_BEAUTY - affects ???
        SPHERE_ART
     SPHERE_BIRTH - affects littersize
        SPHERE_CHILDREN
        SPHERE_CREATION
        SPHERE_FAMILY
        SPHERE_MARRIAGE
        SPHERE_PREGNANCY
        SPHERE_REBIRTH
        SPHERE_YOUTH
     SPHERE_BLIGHT - affects disease resistance
        SPHERE_DISEASE
        SPHERE_DEATH
     SPHERE_CAVERNS - affects luck underground
        SPHERE_MOUNTAINS
        SPHERE_EARTH
     SPHERE_CHAOS - affects madness
        SPHERE_WAR
     SPHERE_CHARITY - affects luck of weaker creatures
        SPHERE_GENEROSITY
        SPHERE_SACRIFICE
     SPHERE_CHILDREN - affects luck of children
        SPHERE_BIRTH
        SPHERE_FAMILY
        SPHERE_YOUTH
        SPHERE_PREGNANCY
     SPHERE_COASTS - affects drowning
        SPHERE_LAKES
        SPHERE_OCEANS
     SPHERE_CRAFTS - affect craft quality
        SPHERE_CREATION
        SPHERE_LABOR
        SPHERE_METALS
     SPHERE_CREATION - affect new objects
        SPHERE_CRAFTS
        SPHERE_BIRTH
        SPHERE_PREGNANCY
        SPHERE_REBIRTH
     SPHERE_DANCE - affect agility at parties
        SPHERE_FESTIVALS
        SPHERE_MUSIC
        SPHERE_REVELRY
     SPHERE_DARKNESS - affect night creatures
        SPHERE_NIGHT
     SPHERE_DAWN - affect crespecular creaturees
        SPHERE_SUN
        SPHERE_TWILIGHT
     SPHERE_DAY - affect diurnal creatures
        SPHERE_LIGHT
        SPHERE_SUN
     SPHERE_DEATH - affect tendency for things to die
        SPHERE_BLIGHT
        SPHERE_DISEASE
        SPHERE_MURDER
        SPHERE_REBIRTH
        SPHERE_SUICIDE
        SPHERE_WAR
     SPHERE_DEFORMITY - affect ???
        SPHERE_DISEASE
     SPHERE_DEPRAVITY - affect criminal activity
        SPHERE_LUST
     SPHERE_DISCIPLINE - 
        SPHERE_LAWS
        SPHERE_ORDER
     SPHERE_DISEASE
        SPHERE_BLIGHT
        SPHERE_DEATH
        SPHERE_DEFORMITY
     SPHERE_DREAMS
        SPHERE_NIGHT
        SPHERE_NIGHTMARES
     SPHERE_DUSK
        SPHERE_TWILIGHT
     SPHERE_DUTY
        SPHERE_ORDER
     SPHERE_EARTH
        SPHERE_CAVERNS
        SPHERE_MOUNTAINS
        SPHERE_VOLCANOS
     SPHERE_FAMILY
        SPHERE_BIRTH
        SPHERE_CHILDREN
        SPHERE_MARRIAGE
        SPHERE_PREGNANCY
     SPHERE_FAME
        SPHERE_RUMORS
     SPHERE_FERTILITY
        SPHERE_AGRICULTURE
        SPHERE_FOOD
        SPHERE_RAIN
     SPHERE_FESTIVALS - affects happiness from parties
        SPHERE_DANCE
        SPHERE_MUSIC
        SPHERE_REVELRY
        SPHERE_SONG
     SPHERE_FIRE
        SPHERE_METALS
        SPHERE_SUN
        SPHERE_VOLCANOS
     SPHERE_FISH
        SPHERE_OCEANS
        SPHERE_LAKES
        SPHERE_RIVERS
        SPHERE_WATER
        SPHERE_FISHING
     SPHERE_FISHING
        SPHERE_FISH
        SPHERE_HUNTING
     SPHERE_FOOD
        SPHERE_AGRICULTURE
        SPHERE_FERTILITY
     SPHERE_FORGIVENESS
        SPHERE_MERCY
     SPHERE_FORTRESSES
        SPHERE_WAR
     SPHERE_GAMBLING
        SPHERE_GAMES
        SPHERE_LUCK
     SPHERE_GAMES
        SPHERE_GAMBLING
        SPHERE_LUCK
     SPHERE_GENEROSITY
        SPHERE_CHARITY
        SPHERE_SACRIFICE
     SPHERE_HAPPINESS
        SPHERE_REVELRY
     SPHERE_HUNTING
        SPHERE_FISHING
     SPHERE_INSPIRATION
        SPHERE_ART
        SPHERE_PAINTING
        SPHERE_POETRY
     SPHERE_JEWELS
        SPHERE_MINERALS
        SPHERE_WEALTH
     SPHERE_JUSTICE
        SPHERE_LAWS
     SPHERE_LABOR
        SPHERE_CRAFTS
     SPHERE_LAKES
        SPHERE_COASTS
        SPHERE_FISH
        SPHERE_OCEANS
        SPHERE_RIVERS
     SPHERE_LAWS
        SPHERE_DISCIPLINE
        SPHERE_JUSTICE
        SPHERE_OATHS
        SPHERE_ORDER
     SPHERE_LIES
        SPHERE_TREACHERY
        SPHERE_TRICKERY
     SPHERE_LIGHT
        SPHERE_DAY
        SPHERE_RAINBOWS
        SPHERE_SUN
     SPHERE_LIGHTNING
        SPHERE_RAIN
        SPHERE_STORMS
        SPHERE_THUNDER
     SPHERE_LONGEVITY
        SPHERE_YOUTH
     SPHERE_LOYALTY
        SPHERE_OATHS
     SPHERE_LUCK
        SPHERE_GAMBLING
        SPHERE_GAMES
     SPHERE_LUST
        SPHERE_DEPRAVITY
     SPHERE_MARRIAGE
        SPHERE_BIRTH
        SPHERE_FAMILY
        SPHERE_OATHS
        SPHERE_PREGNANCY
     SPHERE_MERCY
        SPHERE_FORGIVENESS
     SPHERE_METALS
        SPHERE_CRAFTS
        SPHERE_FIRE
        SPHERE_MINERALS
     SPHERE_MINERALS
        SPHERE_JEWELS
        SPHERE_METALS
     SPHERE_MISERY
        SPHERE_TORTURE
     SPHERE_MOON
        SPHERE_NIGHT
        SPHERE_SKY
     SPHERE_MOUNTAINS
        SPHERE_CAVERNS
        SPHERE_EARTH
        SPHERE_VOLCANOS
     SPHERE_MURDER
        SPHERE_DEATH
     SPHERE_MUSIC
        SPHERE_DANCE
        SPHERE_FESTIVALS
        SPHERE_REVELRY
        SPHERE_SONG
     SPHERE_NATURE
        SPHERE_RAIN
        SPHERE_SUN
        SPHERE_WATER
        SPHERE_WEATHER
     SPHERE_NIGHT
        SPHERE_DARKNESS
        SPHERE_DREAMS
        SPHERE_MOON
        SPHERE_NIGHTMARES
        SPHERE_STARS
     SPHERE_NIGHTMARES
        SPHERE_DREAMS
        SPHERE_NIGHT
     SPHERE_OATHS
        SPHERE_LAWS
        SPHERE_LOYALTY
        SPHERE_MARRIAGE
     SPHERE_OCEANS
        SPHERE_COASTS
        SPHERE_FISH
        SPHERE_LAKES
        SPHERE_RIVERS
        SPHERE_SALT
     SPHERE_ORDER
        SPHERE_DISCIPLINE
        SPHERE_DUTY
        SPHERE_LAWS
     SPHERE_PAINTING
        SPHERE_INSPIRATION
     SPHERE_PERSUASION
        SPHERE_POETRY
        SPHERE_SPEECH
     SPHERE_PLANTS
        SPHERE_ANIMALS
        SPHERE_RAIN
     SPHERE_POETRY
        SPHERE_INSPIRATION
        SPHERE_PERSUASION
        SPHERE_SONG
        SPHERE_WRITING
     SPHERE_PREGNANCY
        SPHERE_BIRTH
        SPHERE_CHILDREN
        SPHERE_CREATION
        SPHERE_FAMILY
        SPHERE_MARRIAGE
     SPHERE_RAIN
        SPHERE_AGRICULTURE
        SPHERE_FERTILITY
        SPHERE_LIGHTNING
        SPHERE_NATURE
        SPHERE_PLANTS
        SPHERE_RAINBOWS
        SPHERE_STORMS
        SPHERE_THUNDER
        SPHERE_TREES
     SPHERE_RAINBOWS
        SPHERE_LIGHT
        SPHERE_RAIN
        SPHERE_SKY
     SPHERE_REBIRTH
        SPHERE_BIRTH
        SPHERE_CREATION
        SPHERE_DEATH
     SPHERE_REVELRY
        SPHERE_DANCE
        SPHERE_FESTIVALS
        SPHERE_HAPPINESS
        SPHERE_MUSIC
        SPHERE_SONG
     SPHERE_RIVERS
        SPHERE_FISH
        SPHERE_LAKES
        SPHERE_OCEANS
     SPHERE_RUMORS
        SPHERE_FAME
     SPHERE_SACRIFICE
        SPHERE_CHARITY
        SPHERE_GENEROSITY
     SPHERE_SALT
        SPHERE_OCEANS
     SPHERE_SCHOLARSHIP
        SPHERE_WISDOM
        SPHERE_WRITING
     SPHERE_SKY
        SPHERE_MOON
        SPHERE_RAINBOWS
        SPHERE_SUN
        SPHERE_STARS
        SPHERE_WEATHER
        SPHERE_WIND
     SPHERE_SONG
        SPHERE_FESTIVALS
        SPHERE_MUSIC
        SPHERE_POETRY
        SPHERE_REVELRY
     SPHERE_SPEECH
        SPHERE_PERSUASION
     SPHERE_STARS
        SPHERE_NIGHT
        SPHERE_SKY
     SPHERE_STORMS
        SPHERE_LIGHTNING
        SPHERE_RAIN
        SPHERE_THUNDER
     SPHERE_SUICIDE
        SPHERE_DEATH
     SPHERE_SUN
        SPHERE_DAWN
        SPHERE_DAY
        SPHERE_FIRE
        SPHERE_LIGHT
        SPHERE_NATURE
        SPHERE_SKY
     SPHERE_THUNDER
        SPHERE_LIGHTNING
        SPHERE_RAIN
        SPHERE_STORMS
     SPHERE_TORTURE
        SPHERE_MISERY
     SPHERE_TRADE
        SPHERE_WEALTH
     SPHERE_TREACHERY
        SPHERE_LIES
        SPHERE_TRICKERY
     SPHERE_TREES
        SPHERE_RAIN
     SPHERE_TRICKERY
        SPHERE_LIES
        SPHERE_TREACHERY
     SPHERE_TWILIGHT
        SPHERE_DAWN
        SPHERE_DUSK
     SPHERE_VALOR
        SPHERE_WAR
     SPHERE_VICTORY
        SPHERE_WAR
     SPHERE_VOLCANOS
        SPHERE_EARTH
        SPHERE_FIRE
        SPHERE_MOUNTAINS
     SPHERE_WAR
        SPHERE_CHAOS
        SPHERE_DEATH
        SPHERE_FORTRESSES
        SPHERE_VALOR
        SPHERE_VICTORY
     SPHERE_WATER
        SPHERE_FISH
        SPHERE_NATURE
     SPHERE_WEALTH
        SPHERE_JEWELS
        SPHERE_TRADE
     SPHERE_WEATHER
        SPHERE_NATURE
        SPHERE_SKY
     SPHERE_WIND
        SPHERE_SKY
     SPHERE_WISDOM
        SPHERE_SCHOLARSHIP
     SPHERE_WRITING
        SPHERE_POETRY
        SPHERE_SCHOLARSHIP
     SPHERE_YOUTH
        SPHERE_BIRTH
        SPHERE_CHILDREN
        SPHERE_LONGEVITY
Preclude relationships:

     SPHERE_BEAUTY
        SPHERE_BLIGHT
        SPHERE_DEFORMITY
        SPHERE_DISEASE
        SPHERE_MUCK
     SPHERE_BLIGHT
        SPHERE_BEAUTY
        SPHERE_FOOD
        SPHERE_FERTILITY
        SPHERE_HEALING
     SPHERE_CHAOS
        SPHERE_DISCIPLINE
        SPHERE_ORDER
        SPHERE_LAWS
     SPHERE_CHARITY
        SPHERE_JEALOUSY
     SPHERE_CONSOLATION
        SPHERE_MISERY
     SPHERE_DARKNESS
        SPHERE_DAWN
        SPHERE_DAY
        SPHERE_LIGHT
        SPHERE_TWILIGHT
        SPHERE_SUN
     SPHERE_DAWN
        SPHERE_NIGHT
        SPHERE_DAY
        SPHERE_DARKNESS
     SPHERE_DAY
        SPHERE_DARKNESS
        SPHERE_NIGHT
        SPHERE_DAWN
        SPHERE_DUSK
        SPHERE_DREAMS
        SPHERE_NIGHTMARES
        SPHERE_TWILIGHT
     SPHERE_DEATH
        SPHERE_HEALING
        SPHERE_LONGEVITY
        SPHERE_YOUTH
     SPHERE_DEFORMITY
        SPHERE_BEAUTY
     SPHERE_DEPRAVITY
        SPHERE_LAWS
     SPHERE_DISCIPLINE
        SPHERE_CHAOS
     SPHERE_DISEASE
        SPHERE_BEAUTY
        SPHERE_HEALING
     SPHERE_DREAMS
        SPHERE_DAY
     SPHERE_DUSK
        SPHERE_NIGHT
        SPHERE_DAY
     SPHERE_FAME
        SPHERE_SILENCE
     SPHERE_FATE
        SPHERE_LUCK
     SPHERE_FERTILITY
        SPHERE_BLIGHT
     SPHERE_FESTIVALS
        SPHERE_MISERY
     SPHERE_FIRE
        SPHERE_WATER
        SPHERE_OCEANS
        SPHERE_LAKES
        SPHERE_RIVERS
     SPHERE_FOOD
        SPHERE_BLIGHT
     SPHERE_FORGIVENESS
        SPHERE_REVENGE
     SPHERE_FREEDOM
        SPHERE_ORDER
     SPHERE_HAPPINESS
        SPHERE_MISERY
     SPHERE_HEALING
        SPHERE_DISEASE
        SPHERE_BLIGHT
        SPHERE_DEATH
     SPHERE_JEALOUSY
        SPHERE_CHARITY
     SPHERE_LAKES
        SPHERE_FIRE
     SPHERE_LAWS
        SPHERE_CHAOS
        SPHERE_DEPRAVITY
        SPHERE_MURDER
        SPHERE_THEFT
     SPHERE_LIES
        SPHERE_TRUTH
     SPHERE_LIGHT
        SPHERE_DARKNESS
        SPHERE_TWILIGHT
     SPHERE_LONGEVITY
        SPHERE_DEATH
     SPHERE_LOYALTY
        SPHERE_TREACHERY
     SPHERE_LUCK
        SPHERE_FATE
     SPHERE_MERCY
        SPHERE_REVENGE
     SPHERE_MISERY
        SPHERE_CONSOLATION
        SPHERE_FESTIVALS
        SPHERE_REVELRY
        SPHERE_HAPPINESS
     SPHERE_MUCK
        SPHERE_BEAUTY
     SPHERE_MURDER
        SPHERE_LAWS
     SPHERE_MUSIC
        SPHERE_SILENCE
     SPHERE_NIGHT
        SPHERE_DAY
        SPHERE_DAWN
        SPHERE_DUSK
        SPHERE_TWILIGHT
     SPHERE_NIGHTMARES
        SPHERE_DAY
     SPHERE_OATHS
        SPHERE_TREACHERY
     SPHERE_OCEANS
        SPHERE_FIRE
     SPHERE_ORDER
        SPHERE_CHAOS
        SPHERE_FREEDOM
     SPHERE_REVELRY
        SPHERE_MISERY
     SPHERE_REVENGE
        SPHERE_FORGIVENESS
        SPHERE_MERCY
     SPHERE_RIVERS
        SPHERE_FIRE
     SPHERE_SACRIFICE
        SPHERE_WEALTH
     SPHERE_SILENCE
        SPHERE_FAME
        SPHERE_MUSIC
     SPHERE_SUN
        SPHERE_DARKNESS
     SPHERE_THEFT
        SPHERE_LAWS
        SPHERE_TRADE
     SPHERE_TRADE
        SPHERE_THEFT
     SPHERE_TREACHERY
        SPHERE_LOYALTY
        SPHERE_OATHS
     SPHERE_TRICKERY
        SPHERE_TRUTH
     SPHERE_TRUTH
        SPHERE_LIES
        SPHERE_TRICKERY
     SPHERE_TWILIGHT
        SPHERE_LIGHT
        SPHERE_DARKNESS
        SPHERE_DAY
        SPHERE_NIGHT
     SPHERE_WATER
        SPHERE_FIRE
     SPHERE_WEALTH
        SPHERE_SACRIFICE
     SPHERE_YOUTH
        SPHERE_DEATH
]]--
 
local function makeAvatar(god)
	fig = god.histfig
	
	local argPos
 
	if #args>3 then
		argPos={}
		argPos.x=args[4]
		argPos.y=args[5]
		argPos.z=args[6]
	end
	
	unit = PlaceUnit(fig.race,fig.caste,fig.name.first_name,argPos) --Creature (ID), caste (number), name, x,y,z , civ_id(-1 for enemy, optional) for spawn.
	
	histfig = fig
	unit.hist_figure_id = histfig.id
	unit.name.first_name = histfig.name.first_name
	unit.name.language = histfig.name.language
	for i=0,#histfig.name.words-1,1 do
		unit.name.words[i] = histfig.name.words[i]
	end
	for i=0,#histfig.name.parts_of_speech-1,1 do
		unit.name.parts_of_speech[i] = histfig.name.parts_of_speech[i]
	end
end

for index,god in pairs(pantheon) do
	--printall(god)
	--makeAvatar(god)
end

    local pos=position or copyall(df.global.cursor)
    if pos.x==-30000 then
        qerror("Select a location")
    end
	
	local unit=dfhack.gui.getSelectedUnit()
	
		

	--storm('smoke',pos,10,15,nil,100)
	--eruption('magma',pos,'1,1,100',7)
	