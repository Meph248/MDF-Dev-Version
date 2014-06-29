arg={...}

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

function getAttrValue(unit,attr,mental)
	if unit.curse.attr_change then
		if mental then
			return (unit.status.current_soul.mental_attrs[attr].value+unit.curse.attr_change.ment_att_add[attr])*unit.curse.attr_change.ment_att_perc[attr]/100
		else
			return (unit.body.physical_attrs[attr].value+unit.curse.attr_change.phys_att_add[attr])*unit.curse.attr_change.phys_att_perc[attr]/100
		end
	else
		if mental then
			return unit.status.current_soul[attr].value
		else
			return unit.body.physical_attrs[attr].value
		end
	end
end

function getSelf()
	local a = df.global.world.status.announcements
	local unitList = df.global.world.units.active
	local self = unit
	for i = #a - 1, 0, -1 do
		if tonumber(a[i].type) == 146 then
			for i = #unitList - 1, 0, -1 do
				if string.find(a[i].text,unitList[i].name.first_name) ~= nil then return unitList[i] end
			end
		end
	end
end

function checkDistance(unitTarget,array,target)
	local rtype = split(arrau.';')[1]
	local rarray = split(arrau,';')[2]
	local rx = tonumber(split(rarray,'/')[1])
	local ry = tonumber(split(rarray,'/')[2])
	local rz = tonumber(split(rarray,'/')[3])
	local unumber = 2

	local selected,targetList,announcement = {true},{unitTarget},{''}
	if rx*ry*rz > 0 then
		local unitList = df.global.world.units.active
		local mapx, mapy, mapz = dfhack.maps.getTileSize()

		for i = 0, #unitList - 1, 1 do
			local unit = unitList[i]
			local xmin = unitTarget.pos.x - rx
			local xmax = unitTarget.pos.x + rx
			local ymin = unitTarget.pos.y - ry
			local ymax = unitTarget.pos.y + ry
			local zmin = unitTarget.pos.z - rz
			local zmax = unitTarget.pos.z + rz
			if xmin < 1 then xmin = 1 end
			if ymin < 1 then ymin = 1 end
			if zmin < 1 then zmin = 1 end
			if xmax > mapx then xmax = mapx-1 end
			if ymax > mapy then ymax = mapy-1 end
			if zmax > mapz then zmax = mapz-1 end

			if unit.pos.x >= xmin or unit.pos.x <= xmax or unit.pos.y >= ymin or unit.pos.y <= ymax or unit.pos.z >= zmin or unit.pos.z <= zmax then
				if target == 'enemy' then
					if unit.civ_id ~= unitTarget.civ_id then
						targetList[unumber] = unit
						selected[unumber] = true
						announcement[unumber] = ''
					end
				elseif target == 'civ' then
					if unit.civ_id == unitTarget.civ_id then
						targetList[unumber] = unit
						selected[unumber] = true
						announcement[unumber] = ''
					end
				elseif target == 'all' then
					targetList[unumber] = unit
					selected[unumber] = true
					announcement[unumber] = ''
				else
					targetList[unumber] = unit
					selected[unumber] = false
					announcement[unumber] = ''
				end
			unumber = unumber + 1
			end
		end
	end
	return selected,targetList,announcement
end

function checkAttributes(unit,array,mental)
	local rtempa,itempa,r,i,required,immune = {},{},1,1,false,false
	local rtext = 'Targeting failed, ' .. tostring(unit.name.first_name) .. "'s attributes are too low."
	local itext = 'Targeting failed, ' .. tostring(unit.name.first_name) .. "'s attributes are too high."
	local tempa = split(array,',')
	for _,x in ipairs(tempa) do
		local utemp = getAttrValue(unit,split(x,';')[2],mental)
		if split(x,';')[1] == 'min' then
			if tonumber(split(x,';')[3]) > utemp then
				rtempa[r] = true
			else
				rtempa[r] = false
			end
			r = r + 1
		elseif split(x,';')[1] == 'max' then
			if tonumber(split(x,';')[3]) < utemp then
				itempa[r] = true
			else
				itempa[r] = false
			end
			i = i + 1
		end
	end
	for _,x in ipairs(rtempa) do
		if x then required = true end
	end
	for _,x in ipairs(itempa) do
		if x then immune = true end
	end
	if required and not immune then return false,itext end
	if required and immune then return true,'NONE' end
	if not required and immune then return false,rtext end
	if not required and not immune then return false,rtext end
end

function checkTraits(unit,array)
	local rtempa,itempa,r,i,required,immune = {},{},1,1,false,false
	local rtext = 'Targeting failed, ' .. tostring(unit.name.first_name) .. "'s traits are too low."
	local itext = 'Targeting failed, ' .. tostring(unit.name.first_name) .. "'s traits are too high."
	local tempa,utempa = split(array,','),unit.status.current_soul.traits
	for _,x in ipairs(tempa) do
		for z,y in pairs(utempa) do
			if split(x,';')[2] == z then
				if split(x,';')[1] == 'min' then
					if tonumber(split(x,';')[3]) > y then
						rtempa[r] = true
					else
						rtempa[r] = false
					end
					r = r + 1
				elseif split(x,';')[1] == 'max' then
					if tonumber(split(x,';')[3]) < y then
						itempa[r] = true
					else
						itempa[r] = false
					end
					i = i + 1
				end
			end
		end
	end
	for _,x in ipairs(rtempa) do
		if x then required = true end
	end
	for _,x in ipairs(itempa) do
		if x then immune = true end
	end
	if required and not immune then return false,itext end
	if required and immune then return true,'NONE' end
	if not required and immune then return false,rtext end
	if not required and not immune then return false,rtext end
end

function checkEntity(unit,array)
	local rtempa,itempa,r,i,required,immune = {},{},1,1,false,false
	local rtext = 'Targeting failed, ' .. tostring(unit.name.first_name) .. ' is not a member of a required entity.'
	local itext = 'Targeting failed, ' .. tostring(unit.name.first_name) .. ' is a member of an immune entity.'
	local tempa,utemp = split(array,','),'NONE'--NEED TO GET UNIT ENTITY!!!!
	for _,x in ipairs(tempa) do
		if split(x,';')[1] == 'required' then
			if split(x,';')[2] == utemp then
				rtempa[r] = true
			else
				rtempa[r] = false
			end
			r = r + 1
		elseif split(x,';')[1] == 'immune' then
			if split(x,';')[2] == utemp then
				itempa[r] = true
			else
				itempa[r] = false
			end
			i = i + 1
		end
	end
	for _,x in ipairs(rtempa) do
		if x then required = true end
	end
	for _,x in ipairs(itempa) do
		if x then immune = true end
	end
	if required and not immune then return true,'NONE' end
	if required and immune then return false,itext end
	if not required and immune then return false,itext end
	if not required and not immune then return false,rtext end
end

function checkSkills(unit,array)
	local rtempa,itempa,r,i,required,immune = {},{},1,1,false,false
	local rtext = 'Targeting failed, ' .. tostring(unit.name.first_name) .. "'s skills are too low."
	local itext = 'Targeting failed, ' .. tostring(unit.name.first_name) .. "'s skills are too high."
	local tempa = split(array,',')
	for _,x in ipairs(tempa) do
		local utemp = dfhack.units.getEffectiveSkill(unit,df.job_skill[split(x,';')[2]])
		if split(x,';')[1] == 'min' then
			if tonumber(split(age,';')[3]) > utemp then
				rtempa[r] = true
			else
				rtempa[r] = false
			end
			r = r + 1
		elseif split(x,';')[1] == 'max' then
			if tonumber(split(age,';')[3]) < utemp then
				itempa[i] = true
			else
				itempa[i] = false
			end
			i = i + 1
		end
	end
	for _,x in ipairs(rtempa) do
		if x then required = true end
	end
	for _,x in ipairs(itempa) do
		if x then immune = true end
	end
	if required and not immune then return false,itext end
	if required and immune then return true,'NONE' end
	if not required and immune then return false,rtext end
	if not required and not immune then return false,rtext end
end

function checkAge(unit,array)
	local rtempa,itempa,r,i,required,immune = {},{},1,1,false,false
	local rtext = 'Targeting failed, ' .. tostring(unit.name.first_name) .. ' is too young.'
	local itext = 'Targeting failed, ' .. tostring(unit.name.first_name) .. ' is too old.'
	local tempa,utemp = split(array,','),dfhack.units.getAge(unit)
	for _,x in ipairs(tempa) do
		if split(x,';')[1] == 'min' then
			if tonumber(split(x,';')[2]) > utemp then
				rtempa[r] = true
			else
				rtempa[r] = false
			end
			r = r + 1
		elseif split(x,';')[1] == 'max' then
			if tonumber(split(x,';')[2]) < utemp then
				itempa[i] = true
			else
				itempa[i] = false
			end
			i = i + 1
		end
	end
	for _,x in ipairs(rtempa) do
		if x then required = true end
	end
	for _,x in ipairs(itempa) do
		if x then immune = true end
	end
	if required and not immune then return false,itext end
	if required and immune then return true,'NONE' end
	if not required and immune then return false,rtext end
	if not required and not immune then return false,rtext end
end

function checkSpeed(unit,array)
	local rtempa,itempa,r,i,required,immune = {},{},1,1,false,false
	local rtext = 'Targeting failed, ' .. tostring(unit.name.first_name) .. ' is too slow.'
	local itext = 'Targeting failed, ' .. tostring(unit.name.first_name) .. ' is too fast.'
	local tempa,utemp = split(array,','),dfhack.units.computeMovementSpeed(unit)
	for _,x in ipairs(tempa) do
		if split(x,';')[1] == 'min' then
			if tonumber(split(x,';')[2]) > utemp then
				rtempa[r] = true
			else
				rtempa[r] = false
			end
			r = r + 1
		elseif split(x,';')[1] == 'max' then
			if tonumber(split(x,';')[2]) < utemp then
				itempa[i] = true
			else
				itempa[i] = false
			end
			i = i + 1
		end
	end
	for _,x in ipairs(rtempa) do
		if x then required = true end
	end
	for _,x in ipairs(itempa) do
		if x then immune = true end
	end
	if required and not immune then return false,itext end
	if required and immune then return true,'NONE' end
	if not required and immune then return false,rtext end
	if not required and not immune then return false,rtext end
end

function checkProfession(unit,array)
	local rtempa,itempa,r,i,required,immune = {},{},1,1,false,false
	local rtext = 'Targeting failed, ' .. tostring(unit.name.first_name) .. ' is not the required profession.'
	local itext = 'Targeting failed, ' .. tostring(unit.name.first_name) .. ' is an immune profession.'
	local tempa,utemp = split(array,','),unit.profession
	for _,x in ipairs(professiona) do
		if split(x,';')[1] == 'required' then
			if df.profession[split(x,';')[2]] == uprofession then
				rtempa[r] = true
			else
				rtempa[r] = false
			end
			r = r + 1
		elseif split(x,';')[1] == 'immune' then
			if df.profession[split(x,';')[2]] == uprofession then
				itempa[i] = true
			else
				itempa[i] = false
			end
			i = i + 1
		end
	end
	for _,x in ipairs(rtempa) do
		if x then required = true end
	end
	for _,x in ipairs(itempa) do
		if x then immune = true end
	end
	if required and not immune then return true,'NONE' end
	if required and immune then return false,itext end
	if not required and immune then return false,itext end
	if not required and not immune then return false,rtext end
end

function checkNoble(unit,array)
	local rtempa,itempa,r,i,required,immune = {},{},1,1,false,false
	local rtext = 'Targeting failed, ' .. tostring(unit.name.first_name) .. ' does not hold the required position.'
	local itext = 'Targeting failed, ' .. tostring(unit.name.first_name) .. ' is holding an immune position.'
	local tempa,utempa = split(array,','),dfhack.units.getNoblePositions(unit)
	for _,x in ipairs(tempa) do
		for _,y in ipairs(utempa) do
			if split(x,';')[1] == 'required' then
				if split(x,';')[2] == y.position.code then
					rtempa[r] = true
				else
					rtempa[r] = false
				end
				r = r + 1
			elseif split(x,';')[1] == 'immune' then
				if split(x,';')[2] == y.position.code then
					itempa[i] = true
				else
					itempa[i] = false
				end
				i = i + 1
			end
		end
	end
	for _,x in ipairs(rtempa) do
		if x then required = true end
	end
	for _,x in ipairs(itempa) do
		if x then immune = true end
	end
	if required and not immune then return true,'NONE' end
	if required and immune then return false,itext end
	if not required and immune then return false,itext end
	if not required and not immune then return false,rtext end
end

function checkTypes(unit,class,creature,syndrome,token,immune)
	local unitraws = df.creature_raw.find(unit.race)
	local casteraws = unitraws.caste[unit.caste]
	local unitracename = unitraws.creature_id
	local castename = casteraws.caste_id
	local unitclasses = casteraws.creature_class
	local syndromes = df.global.world.raws.syndromes.all
	local actives = unit.syndromes.active
	local flags1 = unitraws.flags
	local flags2 = casteraws.flags
	local tokens = {}
	for k,v in pairs(flags1) do
		tokens[k] = v
	end
	for k,v in pairs(flags2) do
		tokens[k] = v
	end
	local tempa,ttempa,i,t,yes,no = {},{},1,1,false,false
	local yestext = 'Targeting failed, ' .. tostring(unit.name.first_name) .. ' is not an allowed type.'
	local notext = 'Targeting failed, ' .. tostring(unit.name.first_name) .. ' is an immune type.' 

	if class ~= 'NONE' then
		local classa = split(class,',')
		for _,unitclass in ipairs(unitclasses) do
			for _,x in ipairs(classa) do
				if x == unitclass.value then
					tempa[i] = true
				else
					tempa[i] = false
				end
				i = i + 1
			end
		end
	end
	if creature ~= 'NONE' then
		local creaturea = split(creature,',')
		for _,x in ipairs(creaturea) do
			local xsplit = split(x,';')
			print(xsplit[1],xsplit[2],unitracename,castename)
			if xsplit[1] == unitracename and xsplit[2] == castename then
				tempa[i] = true
			else
				tempa[i] = false
			end
			i = i + 1
		end
	end
	if syndrome ~= 'NONE' then
		local syndromea = split(syndrome,',')
		for _,x in ipairs(actives) do
			local synclass=syndromes[x.type].syn_class
			for _,y in ipairs(synclass) do
				for _,z in ipairs(syndromea) do
					if z == y.value then
						tempa[i] = true
					else
						tempa[i] = false
					end
					i = i + 1
				end
			end
		end
	end
	if token ~= 'NONE' then
		local tokena = split(token,',')
		for _,x in ipairs(tokena) do
			ttempa[t] = tokens[x]
			t = t + 1							
		end
	end

	for _,x in ipairs(tempa) do
		if immune then
			if x then no = true end
		else
			if x then yes = true end
		end
	end
	for _,x in ipairs(ttempa) do
		if immune then
			if x then no = true end
		else
			if not x then 
				yes = false
				break
			else
				yes = true
			end
		end
	end
	if immune then
		if no then return false,notext end
	else
		if not yes then return false,yestext end
	end
	return true,'NONE'
end

function isSelected(unitTarget,args)

-- Identify casting unit
	local unitSelf = getSelf()

	local value = {radius = '-1,-1,-1',target = 'all',chain = 0,
	aclass = 'NONE',acreature = 'NONE',asyndrome = 'NONE',atoken = 'NONE',
	iclass = 'NONE',icreature = 'NONE',isyndrome = 'NONE',itoken = 'NONE',
	physical = 'NONE',mental = 'NONE',skills = 'NONE',traits = 'NONE',age = 'NONE',speed = 'NONE',
	noble = 'NONE',profession = 'NONE',entity = 'NONE',
	reflect = 'NONE',silence = 'NONE',
	self = false,verbose = false,los = true
	}

-- Arguments Analysis	
	local temp = 'NONE'
	for i = 1, #args, 1 do
		if string.match(args[i],'@') ~= nil then
			temp = split(args[i],'@')
			value[temp[1]] = temp[2]
		end
	end

	local output = {
	caster = unitSelf,
	verbose = value['verbose'],
	}

-- Self Check	
	if value['self'] then
		unitTarget = unitSelf
	end

-- Silence Check
	if value['silence'] ~= 'NONE' then
		local syndromes = df.global.world.raws.syndromes.all
		local silencea = split(silence,',')
		local sactives = unitSelf.syndromes.active
		for _,x in ipairs(sactives) do
			local ssynclass=syndromes[x.type].syn_class
			for _,y in ipairs(ssynclass) do
				for _,z in ipairs(silencea) do
					if z == y.value then
						output['selected'] = {false}
						output['targets'] = {'NONE'}
						output['announcement'] = {'Casting failed, ' .. tostring(unitSelf.name.first_name) .. ' is prevented from using the interaction.'}
						return output 
					end
				end
			end
		end
	end

-- Distance Check
	local selected,targetList,announcement = checkDistance(unitTarget,value['radius'],value['target'])	

-- Target Checks
	for i = 1, #targetList, 1 do
		local unitCheck = targetList[i]

-- Reflect Check
		if value['reflect'] ~= 'NONE' then
			local syndromes = df.global.world.raws.syndromes.all
			local reflecta = split(reflect,',')
			local actives = unitCheck.syndromes.active
			for _,x in ipairs(actives) do
				local rsynclass=syndromes[x.type].syn_class
				for _,y in ipairs(rsynclass) do
					for _,z in ipairs(reflecta) do
						if z == y.value then 
							targetList[i] = unitSelf
							announcement[i] = tostring(unitCheck.name.first_name) .. ' reflects the interaction back towards ' .. tostring(unitSelf.name.first_name) .. '.'
							unitCheck = unitSelf
						end
					end
				end
			end
		end

-- Age Check
		if value['age'] ~= 'NONE' and selected[i] then
			selected[i],announcement[i] = checkAge(unitCheck,value['age'])
		end

-- Speed Check
		if value['speed'] ~= 'NONE' and selected[i] then
			selected[i],announcement[i] = checkSpeed(unitCheck,value['speed'])
		end

-- Physical Attributes Check
		if value['physical'] ~= 'NONE' and selected[i] then
			selected[i],announcement[i] = checkAttributes(unitCheck,value['physical'],false)
		end

-- Mental Attributes Check
		if value['mental'] ~= 'NONE' and selected[i] then
			selected[i],announcement[i] = checkAttributes(unitCheck,value['mental'],true)
		end

-- Skill Level Check
		if value['skills'] ~= 'NONE' and selected[i] then
			selected[i],announcement[i] = checkSkills(unitCheck,value['skills'])
		end

-- Trait Check
		if value['traits'] ~= 'NONE' and selected[i] then
			selected[i],announcement[i] = checkTraits(unitCheck,value['traits'])
		end

-- Noble Check
		if value['noble'] ~= 'NONE' and selected[i] then
			selected[i],announcement[i] = checkNoble(unitCheck,value['noble'])
		end

-- Profession Check
		if value['profession'] ~= 'NONE' and selected[i] then
			selected[i],announcement[i] = checkProfession(unitCheck,value['profession'])
		end

-- Entity Check
		if value['entity'] ~= 'NONE' and selected[i] then
			selected[i],announcement[i] = checkEntity(unitCheck,value['entity'])
		end

-- Immune Check
		if (value['iclass'] ~= 'NONE' or value['icreature'] ~= 'NONE' or value['isyndrome'] ~= 'NONE' or value['itoken'] ~= 'NONE') and selected[i] then
			selected[i],announcement[i] = checkTypes(unitCheck,value['iclass'],value['icreature'],value['isyndrome'],value['itoken'],true)
		end

-- Required Check	
		if (value['aclass'] ~= 'NONE' or value['acreature'] ~= 'NONE' or value['asyndrome'] ~= 'NONE' or value['atoken'] ~= 'NONE') and selected[i] then
			selected[i],announcement[i] = checkTypes(unitCheck,value['aclass'],value['acreature'],value['asyndrome'],value['atoken'],true)
		end

	end

	return selected,targetList,unitSelf,value['verbose'],announcement
end

local script = {chain=0,script='NONE',args='NONE'}
local temp = 'NONE'
for i = 1, #arg, 1 do
	if string.match(arg[i],'@') ~= nil then
		temp = split(arg[i],'@')
		script[temp[1]] = temp[2]
	end
end

for count = 0, tonumber(script['chain']), 1 do
	local unit = df.unit.find(arg[1])
	if count > 0 then unit = targetList[math.random(1,#targetList)
	local selected,targetList,unitSelf,verbose,announcement = isSelected(unit,arg)

	local scripta = split(script['script'],',')
	local argsa = split(script['args'],',')
	for i,x in ipairs(scripta) do
		for j,y in ipairs(targetList) do
			if selected[j] then
				local sargsa = split(argsa[i],';')
				for k,z in ipairs(sargsa) do
					if z == 'UNIT' then sargsa[k] = y.id end
					if z == 'LOCATION' then sargsa[k] = y.pos end
					if z == 'SELF' then sargsa[k] = unitSelf.id end
				end
				if #sargsa == 1 then dfhack.run_script(x,sargsa[1]) end
				if #sargsa == 2 then dfhack.run_script(x,sargsa[1],sargsa[2]) end
				if #sargsa == 3 then dfhack.run_script(x,sargsa[1],sargsa[2],sargsa[3]) end
				if #sargsa == 4 then dfhack.run_script(x,sargsa[1],sargsa[2],sargsa[3],sargsa[4]) end
				if #sargsa == 5 then dfhack.run_script(x,sargsa[1],sargsa[2],sargsa[3],sargsa[4],sargsa[5]) end
				if #sargsa == 6 then dfhack.run_script(x,sargsa[1],sargsa[2],sargsa[3],sargsa[4],sargsa[5],sargsa[6]) end
				if #sargsa == 7 then dfhack.run_script(x,sargsa[1],sargsa[2],sargsa[3],sargsa[4],sargsa[5],sargsa[6],sargsa[7]) end
				if #sargsa == 8 then dfhack.run_script(x,sargsa[1],sargsa[2],sargsa[3],sargsa[4],sargsa[5],sargsa[6],sargsa[7],sargsa[8]) end
				if #sargsa == 9 then dfhack.run_script(x,sargsa[1],sargsa[2],sargsa[3],sargsa[4],sargsa[5],sargsa[6],sargsa[7],sargsa[8],sargsa[9]) end
				if #sargsa == 10 then dfhack.run_script(x,sargsa[1],sargsa[2],sargsa[3],sargsa[4],sargsa[5],sargsa[6],sargsa[7],sargsa[8],sargsa[9],sargsa[10]) end
			end
		end
	end
end

