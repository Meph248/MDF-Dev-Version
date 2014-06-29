--counters.lua v1.0
--[[
counters - a stand alone version of the counters feature included in the wrapper
	ID # - the units id number
		\UNIT_ID - when triggering with a syndrome
		\WORKER_ID - when triggering with a reaction
	COUNTER_TYPE - any string value, the counter will be saved as this type
	increment - amount for the counter to change
		# - can be both positive and negative
	style - the way to check the counter
		minimum - once the value of the counter has surpassed a certain amount, the counter will trigger the script. the counter is then reset to zero
		percentage - the script has a chance of triggering each time the counter is increased, with a 100% chance once it reaches a certain amount. the counter is reset to zero on triggering
	cap - level of triggering for the counter
		#
		NOTE: Once it hits the cap (or is triggered earlier by percentage) the counter will reset to 0
	script and arguments - the script to trigger when the counter is reached
		In the form script@arg1;arg2;arg3
		SPECIAL TOKEN: !UNIT - replaces with the unit id specified in the counters script
EXAMPLE: counters \UNIT_ID PRAY 1 minimum 100 changetraits@SELF_DISCIPLINE;!UNIT;fixed;10
--]]

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

function counters(unit,array)
	tempa = array
	keys = tostring(unit.id)
	types = tempa[1]
	ints = tonumber(tempa[2])
	style = tempa[3]
	n = tonumber(tempa[4])
	v = 0
	skey = ''
	si = 0
	pers,status = dfhack.persistent.get(keys..'_counters_1')
	num = 1
	match = false
	if not pers then
		dfhack.persistent.save({key=keys..'_counters_1',value=types,ints={ints,0,0,0,0,0,1}})
		v = ints
		skey = keys..'_counters_1'
		si=1
	else
		if pers.ints[7] <= 6 then
			local valuea = split(pers.value,'_')
			for i,x in ipairs(valuea) do
				if x == types then 
					pers.ints[i] = pers.ints[i] + ints
					v = pers.ints[i]
					skey = keys..'_counters_1'
					si = i
					match = true
				end
			end
			if not match then
				if pers.ints[7] < 6 then
					pers.value = pers.value .. '_' .. types
					pers.ints[7] = pers.ints[7] + 1
					pers.ints[pers.ints[7]] = ints
					v = ints
					skey = keys..'_counters_1'
					si = pers.ints[7]
					dfhack.persistent.save({key=pers.key,value=pers.value,ints=pers.ints})
				elseif pers.ints[7] == 6 then
					pers.ints[7] = 7
					dfhack.persistent.save({key=keys .. '_counters_2', value=types,ints={ints,0,0,0,0,0,0}})
					v = ints
					skey = keys..'_counters_2'
					si = 1
				end
			end
		else
			num = math.floor(pers.ints[7]/7)+1
			local valuea = split(pers.value,'_')
			for i,x in ipairs(valuea) do
				if x == types then
					pers.ints[i] = pers.ints[i] + ints
					v = pers.ints[i]
					skey = keys..'_counters_1'
					si = i
					match = true
				end
			end
			if not match then
				for j = 2, num, 1 do
					keysa = keys .. '_counters_' .. tostring(j)
					persa,status = dfhack.persistent.get(keysa)
					local valuea = split(persa.value,'_')
					for i,x in ipairs(valuea) do
						if x == types then
							persa.ints[i] = persa.ints[i] + ints
							v = persa.ints[i]
							skey = keysa
							si = i
							dfhack.persistent.save({key=persa.key,value=persa.value,ints=persa.ints})
							match = true
						end
					end
				end
			end
			if not match then
				pers.ints[7] = pers.ints[7] + 1
				if math.floor(pers.ints[7]/7) == pers.ints[7]/7 then
					keysa = keys..'_counters_'..tostring(num+1)
					dfhack.persistent.save({key=keysa, value=types,ints={ints,0,0,0,0,0,0}})
					v = ints
					skey = keysa
					si = 1
				else
					persa.value = persa.value..'_'..types
					persa.ints[pers.ints[7]-(num-1)*7+1] = persa.ints[pers.ints[7]-(num-1)*7+1] + ints
					v = persa.ints[pers.ints[7]-(num-1)*7+1]
					skey = keysa
					si = pers.ints[7]-(num-1)*7+1
					dfhack.persistent.save({key=persa.key,value=persa.value,ints=persa.ints})
				end
			end
		end
		dfhack.persistent.save({key=pers.key,value=pers.value,ints=pers.ints})
	end


	if style == 'minimum' then
		print(v,n,skey,si)
		if tonumber(v) >= n and n >= 0 then
			pers,status=dfhack.persistent.get(skey)
			pers.ints[si] = 0
			dfhack.persistent.save({key=skey,value=pers.value,ints=pers.ints})
			return true
		end
	elseif style == 'percent' then
		rando = dfhack.random.new()
		roll = rando:drandom()
		if roll <= v/n and n >= 0 then
			pers,status=dfhack.persistent.get(skey)
			pers.ints[si] = 0
			dfhack.persistent.save({key=skey,value=pers.value,ints=pers.ints})
			return true
		end
	end

	return false
end

trigger = counters(arg[1],{arg[2],arg[3],arg[4],arg[5]})
if trigger then
	local script = split(arg[6],'@')[1]
	local sargsa = split(split(arg[6],'@')[2],';')
	for i,v in ipairs(sargsa) do
		if v == '!UNIT' then sargsa[i] = arg[1] end
	end
	dfhack.run_script(script,table.unpack(sargsa))
end
