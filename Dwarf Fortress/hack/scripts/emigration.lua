--Allows dwarves to emigrate from the fortress if their mood is low enough.  Use a numeric parameter between 1 and 100 to set the chance of this happening.  Defaults to 1.

--check about once per caravan for each unit (this is not exact, since it is based on probabilities)
--prob = args[1]
--Start with happiness level.  Multiply it by 2 if the merchant or diplomat is foreign.  Multiply it by 2 if it is a diplomat.  Multiply it by 5 if leaving for the wild.
--Desertchance = prob/happiness.  This is the probability, as a percentage, that they will leave.

args = {...}
prob = 10
if args[1] == '0' or args[1] == 'disable' or args[1] == nil then
	prob = 0
else
	prob = args[1]
end

function isMember(u)
	if u.race == df.global.ui.race_id
	and u.civ_id == df.global.ui.civ_id
	and not dfhack.units.isDead(u)
	and not dfhack.units.isOpposedToLife(u)
	and not u.flags1.merchant 
	and not u.flags1.diplomat
	then
		return true
	else return false end
end

function desert(u,method,civ,accompany)
	if u then
		if civ == nil then civ = -1 else u.civ_id = civ end
		if method == nil or method == 'wild' then u.civ_id=-1 u.flags1.forest=true u.animal.leave_countdown=2 end
		if method == 'merchant' then u.flags1.merchant = true end
		if method == 'diplomat' then u.flags1.diplomat = true end
		if method == 'invader' then u.flags1.active_invader = true end
		if method == 'beast' then u.flags2.visitor_uninvited = true end
		
		u.relations.following = nil
		if method == 'beast' then u.civ_id=-1 u.relations.following = df.unit.find(civ) end
		
		local hasSpouse = false
		local children = 0
		local pets = 0
		local spouse_noun = 'spouse'
		local spouse_name = ''
		local child_noun = 'child'
		local child_name = ''
		local pet_noun = 'pet'
		local pet_name = ''
		local pron = 'its'
		if u.sex == 0 then pron = 'her' elseif u.sex == 1 then pron = 'his' end
		
		--Also the spouse, kids and pets
		allUnits = df.global.world.units.active
		local r
		
		for i=#allUnits-1,0,-1 do	-- search list in reverse
			r = allUnits[i]
			if dfhack.units.isCitizen(r) 
			and not dfhack.units.isDead(r)
			and r.flags1.merchant == false 
			and r.flags1.diplomat == false 
			and r.flags1.forest == false
			and r.flags1.active_invader == false then
				if r.relations.spouse_id == u.id then
					desert(r,method,civ,true)
					r.relations.following = u
					hasSpouse = true
					if r.sex == 0 then spouse_noun = 'wife' elseif u.sex == 1 then spouse_noun = 'husband' end
					spouse_name = dfhack.TranslateName(r.name)
				end
				if r.profession == 103 then
					if r.relations.mother_id == u.id or r.relations.father_id == u.id then
						desert(r,method,civ,true)
						r.relations.following = u
						if children == 0 then
							if r.sex == 0 then child_noun = 'daughter' elseif u.sex == 1 then child_noun = 'son' end
							child_name = dfhack.TranslateName(r.name)
						else
							if (child_noun == 'daughter' or child_noun == 'daughters') and r.sex == 0 then child_noun = 'daughters'
							elseif (child_noun == 'son' or child_noun == 'sons') and r.sex == 1 then child_noun = 'sons'
							else child_noun = 'children' end
						end
						children = children + 1
					end
				end
				if r.relations.pet_owner_id == u.id then
					desert(r,method,civ,true)
					r.relations.following = u
					if pets == 0 then
						pet_noun = df.global.world.raws.creatures.all[r.race].name[0]
						pet_name = dfhack.TranslateName(r.name)
					else
						if df.global.world.raws.creatures.all[r.race].name[0] == pet_noun or df.global.world.raws.creatures.all[r.race].name[1] == pet_noun then pet_noun = df.global.world.raws.creatures.all[r.race].name[1]
						else pet_noun = 'pets' end
					end
					pets = pets + 1
				end
			end
		end
		
		if hasSpouse then spouse_noun = pron .. " " .. spouse_noun .. " " .. spouse_name
		else spouse_noun = "" end
		if children == 0 then child_noun = ""
		elseif children == 1 then child_noun = pron .. " " .. child_noun .. " " .. child_name
		elseif children > 1 then child_noun = pron .. " " .. children .. " " .. child_noun end
		if pets == 0 then pet_noun = ""
		elseif pets == 1 then pet_noun = pron .. " " .. pet_noun .. " " .. pet_name
		elseif pets > 1 then pet_noun = pron .. " " .. pets .. " " .. pet_noun end
		
		if pets > 0 then
			spouse_noun = ", " .. spouse_noun
			child_noun = ", " .. child_noun
			pet_noun = " and" .. pet_noun
		elseif children > 0 then
			spouse_noun = ", " .. spouse_noun
			child_noun = " and " .. child_noun
		elseif hasSpouse == true then
			spouse_noun = " and " .. spouse_noun
		end
		
		if hasSpouse == false then spouse_noun = "" end
		if children == 0 then child_noun = "" end
		if pets == 0 then pet_noun = "" end
		
		if hasSpouse == false and children == 0 and pets == 0 then has = " has" else has = " have" end
		
		local line = dfhack.TranslateName(u.name) .. spouse_noun .. child_noun .. pet_noun -- Urist, his wife Catten, his son Bomrek, and his 6 dogs
		
		local actionLine = ""
		
		if method == nil or method == 'wild' then actionLine = has .. " abandoned the settlement in search of a better life." end
		if method == 'merchant' then actionLine = has .. " joined the merchants." end
		if method == 'diplomat' then actionLine = has .. " left with the diplomat." end
		if method == 'invader' then actionLine = has .. " turned traitor!" end
		if method == 'beast' then actionLine = has .. " accepted the great beast as their savior!" end
		
		line = line..actionLine
		
		if not accompany == true then
			if method == 'invader' or method == 'beast' then
				dfhack.gui.showAnnouncement(line, COLOR_RED, true)
			else
				dfhack.gui.showAnnouncement(line, COLOR_WHITE)
			end
		end
	end
end

function canLeave(unit,method)
	
	if unit.flags1.caged or unit.flags1.chained then return false end -- Cannot leave: physically bound
	
	if dfhack.units.getNoblePositions(unit) ~= nil then return false end -- Cannot leave: noble
	
	for _, skill in pairs(unit.status.current_soul.skills) do 
		local rating = skill.rating
		if rating > 14 then
			return false -- Cannot leave: legendary
		end
	end
	
	--if unit.job.current_job ~= nil then return false end -- Cannot leave: busy
	
	if unit.military.squad_id ~= -1 then return false end -- Cannot leave: military
	
	return true
	
end

function isLeaving(unit)
	dest = unit.path.dest
	if dest.x == 0 or dest.y == 0 or dest.x == df.global.world.map.x_count or dest.y == df.global.world.map.y_count then
		return true
	else return false end
end

function desireToStay(unit,method,civ_id)
	value = unit.status.happiness
	if (method == 'merchant' or method == 'diplomat') then
		if civ_id ~= unit.civ_id then value = value
		else value = value * 2 end
	end
	if method == 'diplomat' then value = value*2 end
	if method == 'wild' then value = value*5 end
	if method == 'invader' then value = value*10 end
	if method == 'beast' then value = value*10 end
	return value
end


function checkForDeserters(method,civ_id)
	allUnits = df.global.world.units.active
	local u
	if prob ~= 0 then
		for i=#allUnits-1,0,-1 do	-- search list in reverse
			if math.random (1000) == 1 then -- about once every 3000 season ticks.  That should be one check per caravan, on average.
				u = allUnits[i]
				if dfhack.units.isCitizen(u)
				and dfhack.units.isSane(u)
				and u.profession ~= 103
				and not dfhack.units.isDead(u) then
					if canLeave(u,method) == true then
						local can_leave = true
						local stay = desireToStay(u,method,civ_id)
						if u.relations.spouse_id ~= -1 then
							spouse = df.unit.find(u.relations.spouse_id)
							if not dfhack.units.isDead(spouse) then
								if canLeave(spouse,method) then
									spouse_stay = desireToStay(spouse,method,civ_id)
									
									assert1 = 100 --should be assertiveness of this unit
									assert2 = 100 --should be assertiveness of spouse
									twm = 1/(assert1+assert2)
									weight1 = assert1*twm
									weight2 = assert2*twm
									
									stay = (stay*weight1) + (spouse_stay*weight2)
								else
									can_leave = false
								end
							end
						end
						if stay < 1 then stay = 1 end -- no divide by zero
						local desertChance = prob/stay
						if math.random(100) < desertChance and can_leave == true then
							desert(u,method)
						end
					end
				end
			end
		end
	end
end



local timer = 0
local tick = df.global.cur_season_tick

local function event_loop()
	local units = df.global.world.units.active
	
	local merchant = false
	local diplomat = false
	local invader = false
	local beast = false
	local merchant_civ_ids = {}
	local diplomat_civ_ids = {}
	local invader_civ_ids = {}
	
	for i=0, #units-1 do
		local unit = units[i]
		if dfhack.units.isSane(unit)
		and not dfhack.units.isDead(unit) 
		and not dfhack.units.isOpposedToLife(unit)
		and not unit.flags1.tame
		then
			if unit.flags1.active_invader and isLeaving(unit) == false and unit.profession ~= 103 then
				invader = true
				invader_civ_ids[unit.civ_id]=unit.civ_id
			end
			if unit.flags1.merchant and isLeaving(unit) == false and unit.profession ~= 103 then
				merchant = true
				merchant_civ_ids[unit.civ_id]=unit.civ_id
			end
			if unit.flags1.diplomat and isLeaving(unit) == false and unit.profession ~= 103 then
				diplomat = true
				diplomat_civ_ids[unit.civ_id]=unit.civ_id
			end
			if unit.flags2.visitor_uninvited and isLeaving(unit) == false and unit.profession ~= 103 then
				beast = true
				beast_ids[unit.id]=unit.id
			end
		end
	end
	if merchant == true then
		for _, civ_id in pairs(merchant_civ_ids) do 
			checkForDeserters('merchant', civ_id)
		end
	elseif diplomat == true then
		for _, civ_id in pairs(diplomat_civ_ids) do 
			checkForDeserters('diplomat', civ_id)
		end
	elseif invader == true then
		for _, civ_id in pairs(invader_civ_ids) do 
			--checkForDeserters('invader', civ_id) --Bugged, so disabled for now
		end
	elseif beast == true then
		for _, civ_id in pairs(beast_ids) do 
			--checkForDeserters('beast', civ_id) --Bugged, so disabled for now
		end
	elseif math.random(100) == 1 then
		checkForDeserters('wild', -1)
	end
	dfhack.timeout(25, 'ticks', event_loop) --about 3 season ticks
end

dfhack.onStateChange.loadEmigration = function(code)
	if code==SC_MAP_LOADED then
		if prob == 0 then
			print("Emigration disabled.")
		else
			print("Emigration enabled with value " .. args[1])
			event_loop()
		end
	end
end

if dfhack.isMapLoaded() then 
	dfhack.onStateChange.loadEmigration(SC_MAP_LOADED)
end

