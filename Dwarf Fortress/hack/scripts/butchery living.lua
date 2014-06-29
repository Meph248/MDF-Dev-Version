--Calculates butchering results. Alpha version. Target a living creature.

unit=dfhack.gui.getSelectedUnit()
if unit==nil then
	 print ("No unit under cursor!  Aborting!")
	 return
	 end

print(unit.name.first_name, df.global.world.raws.creatures.all[unit.race].creature_id)
print("Creature size (base, current): ", unit.body.size_info.size_base, unit.body.size_info.size_cur)
totalvol=0
totalbone=0
missingparts=0
testrecord={}


for partnum,v in pairs(unit.body.body_plan.body_parts) do
for layernum, vv in pairs(v.layers) do
--START MAIN LOOP

partsize = math.floor(unit.body.size_info.size_base * v.relsize / unit.body.body_plan.total_relsize)
modpartfraction= vv.part_fraction
partname = v.name_singular[0].value
layername = vv.layer_name

if layername == "FAT" then
	--currently can't link to or check tissue flags, so can't see if custom tissue resizes based on stored energy
	modpartfraction = unit.counters2.stored_fat * modpartfraction / 2500 / 100
end

if layername == "MUSCLE" then
	--should update to consider strength bonus due to curses etc.
	modpartfraction = unit.body.physical_attrs.STRENGTH.value * modpartfraction / 1000
end


volume = math.floor(partsize * modpartfraction / v.fraction_total)
totalvol=totalvol+volume
finalresult = math.floor(volume/2500)

if volume < 26 and (partsize < 26 or vv.flags.CONNECTS==false) then
	--this is an approximation of the actual game code
	finalresult=0
else
	if finalresult < 1 then
		finalresult=1
	end
end

--is layer or part missing? in actual code this was checked earlier?
if unit.body.components.body_part_status[partnum].missing==true then
	finalresult=0
	missingparts=1
end
if unit.body.components.layer_status[vv.layer_id].gone==true then
	finalresult=0
	missingparts=1
end

if layername == "BONE" and v.flags.TOTEMABLE==false then
	totalbone=totalbone+finalresult
end

if testrecord[layername]==nil then
	if finalresult>0 then
		testrecord[layername]=finalresult
	end
else
	testrecord[layername]=testrecord[layername]+finalresult
end

--END MAIN LOOP
end
end

print(" ")
printall(testrecord)
print("Bone (minus skull):", totalbone)
if missingparts==1 then
print("BODY IS MISSING SOME PARTS OR LAYERS (i.e. combat damage)")
end
print(" ")