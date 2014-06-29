--propel.lua v1.0
--[[
propel - cause a unit to be propelled as a projectile with a certain velocity
	type - the method for computing units velocity
		random - throws the unit in a random direction
		fixed - throws the unit in a fixed direction
		relative**,****** - throws the unit in a direction relative to the origin unit
	ID # - the target units id number
		\UNIT_ID - when triggering with a syndrome
		\WORKER_ID - when triggering with a reaction
	strength - the force to propel the unit in x, y, and z
		#/#/#
			Equation for random = random[-1,1]*strength
			Equation for fixed = strength
			Equation for relative = strength*(targetpos - sourcepos)/abs(targetpos-sourcepos)
	(OPTIONAL) ID # - the origin units id number, required for the relative propel type
EXAMPLE: propel random \UNIT_ID 50/50/0
--]]

args={...}

local function split(str, pat)
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

local function propel(ptype,unitTarget,strength,unitSource)
	local strengtha = split(strength,'/')
	local sx = tonumber(strengtha[1])
	local sy = tonumber(strengtha[2])
	local sz = tonumber(strengtha[3])
	local dx = 1
	local dy = 1
	local dz = 1
	local rando = dfhack.random.new()
	
	if unitSource ~= 0 then
		if unitTarget.pos.x - unitSource.pos.x ~= 0 then
			dx = (unitTarget.pos.x - unitSource.pos.x)/math.abs(unitTarget.pos.x - unitSource.pos.x)
		else
			dx = rando:random(3) - 1
		end
		if unitTarget.pos.y - unitSource.pos.y ~= 0  then
			dy = (unitTarget.pos.y - unitSource.pos.y)/math.abs(unitTarget.pos.y - unitSource.pos.y)
		else
			dy = rando:random(3) - 1
		end
		if unitTarget.pos.z - unitSource.pos.z ~= 0 then
			dz = (unitTarget.pos.z - unitSource.pos.z)/math.abs(unitTarget.pos.z - unitSource.pos.z)
		else
			dz = rando:random(3) - 1
		end
	end
	
	local count=0
	local l = df.global.world.proj_list
	local lastlist=l
	l=l.next
	while l do
		count=count+1
		if l.next==nil then
			lastlist=l
		end
		l = l.next
	end

	if ptype == 'random' then
		rollx = rando:unitrandom()*sx
		rolly = rando:unitrandom()*sy
		rollz = rando:unitrandom()*sz
		bsize = unitTarget.body.size_info.size_cur
		resultx = math.floor(rollx)
		resulty = math.floor(rolly)
		resultz = math.floor(rollz)
	elseif ptype == 'fixed' then
		resultx = sx
		resulty = sy
		resultz = sz
	elseif ptype == 'relative' then
		resultx = sx*dx
		resulty = sy*dy
		resultz = sz*dz
	else
		print('Not a valid type')
	end

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
	proj.speed_x=resultx
	proj.speed_y=resulty
	proj.speed_z=resultz
	unitoccupancy = dfhack.maps.ensureTileBlock(unitTarget.pos).occupancy[unitTarget.pos.x%16][unitTarget.pos.y%16]
	if not unitTarget.flags1.on_ground then 
		unitoccupancy.unit = false 
	else 
		unitoccupancy.unit_grounded = false 
	end
	unitTarget.flags1.projectile=true
	unitTarget.flags1.on_ground=false
end

local ptype = args[1]
local unit = df.unit.find(tonumber(args[2]))
local strength = args[3]
local unitSource = 0
if #args = 4 then unitSource = df.unit.find(tonumber(args[4])) end

propel(ptype,unit,strength,unitSource)
