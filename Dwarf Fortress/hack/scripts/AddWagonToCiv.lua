--comment


local function insertPet(entity,creature,caste)
	local exists=false
	for k,v in pairs(df.global.world.entities.all) do
		--ENTITY TYPES
		--Civilization	0
		--SiteGovernment	1
		--VesselCrew	2
		--MigratingGroup	3
		--NomadicGroup	4
		--Religion	5
		--MilitaryUnit	6
		--Outcast	7
		if v.type==0 and v.entity_raw.code==entity then --exclude bandits
			--print(k)
			--printall(v.resources.animals)
			for kk,vv in pairs(v.resources.animals.wagon_races) do
				--print(kk,vv,v.resources.animals.wagon_castes[kk])
				local checkrace = df.creature_raw.find(vv)
				local checkcaste = checkrace.caste[v.resources.animals.wagon_castes[kk]]
				--print(checkrace.creature_id, checkcaste.caste_id)
				if checkrace.creature_id == creature and checkcaste.caste_id == caste then exists=true end
			end
			if exists==true then
				print("ERROR- civilization ",entity," has creature ", creature, caste)
			else
				--the civ doesn't have the creature as a pet
				--add the creature as a pet
				local racenum=-1
				local castenum=-1
				for kk,vv in pairs(df.global.world.raws.creatures.all) do
					--print(vv.creature_id)
					if vv.creature_id==creature then 
						racenum=kk
						--print(kk)
						--printall(vv.caste)
						for kkk,vvv in pairs(vv.caste) do
							--print(vvv.caste_id)
							if vvv.caste_id==caste then castenum=kkk end
						end
						break
					end
				end
				if racenum > -1 and castenum > -1 then
					--print("success!!")
					--print(v)
					v.resources.animals.wagon_races:insert('#',racenum)
					v.resources.animals.wagon_castes:insert('#',castenum)
					print("Inserted ", creature, caste, " in civ ",k, entity)
				else
					print(creature, caste, " not found in raws")
				end
			end
		end
		exists=false
	end
end


-- dwarves
insertPet("MOUNTAIN","EQUIPMENT_WAGON","WAGON")

--elves
--- elves dont use wooden wagons

--humans
insertPet("PLAINS","EQUIPMENT_WAGON","WAGON")

--gnomes
insertPet("GNOMES","EQUIPMENT_WAGON","WAGON")

--succubi
insertPet("DECADENCE","EQUIPMENT_WAGON","WAGON")

--warlocks
insertPet("WARLOCK","EQUIPMENT_WAGON","WAGON")

--orcs
insertPet("TAIGA","EQUIPMENT_WAGON","WAGON")

--kobolds
insertPet("KOBOLD_CAMP","EQUIPMENT_WAGON","WAGON")

--frostgiants
insertPet("FROST_GIANT","EQUIPMENT_WAGON","WAGON")

--goblins
insertPet("EVIL","EQUIPMENT_WAGON","WAGON")

--drow
insertPet("DROW","EQUIPMENT_WAGON","WAGON")

--automatons
insertPet("AUTOMATON","EQUIPMENT_WAGON","WAGON")
