--projectile.lua v1.0
--[[
projectile - create a projectile (boulder, ammo, or weapon), either from above moving downwards or from one point to another
	origin - how to determine the projectiles origin
		location***** - base the origin on a specific location
			x/y/z - the x, y, and z coordinates of the target
			object - the object to create
				BOULDER - creates a boulder
				WEAPON/WEAPON_SUBTYPE - creates a specific weapon
				AMMO/AMMO_SUBTYPE - creates a specific ammo
			INORGANIC_TOKEN - what the projectile should be made from
				Any inorganic token
			firing type - how you want the projectile fired
				fall - drops from the air above the target location
					#/# - number of projectiles to fall/height from which they start
			EXAMPLE: projectile location 123/132/168 AMMO/ITEM_AMMO_BOLTS COPPER fall 1/10
				shoot**,****** - moves from origin to target location
					#/#/#/#/# - number of projectiles to shoot/velocity of projectiles/hit rate of projectiles/furthest distance to hit/minimum distance to hit
					x/y/z - the x, y, and z coordinates of the origin
			EXAMPLE: projectile location 123/132/168 WEAPON/ITEM_WEAPON_SPEAR STEEL shoot 1/20/50/10/1 133/132/168
		unit - base the origin on a specific unit
			ID # - the target units id number
				\UNIT_ID - when triggering with a syndrome
				\WORKER_ID - when triggering with a reaction
			object - the object to create
				BOULDER - creates a boulder
				WEAPON/WEAPON_SUBTYPE - creates a specific weapon
				AMMO/AMMO_SUBTYPE - creates a specific ammo
			INORGANIC_TOKEN - what the projectile should be made from
				Any inorganic token
			firing type - how you want the projectile fired
				fall - drops from the air above the target location
					#/# - number of projectiles to fall/height from which they start
			EXAMPLE: projectile location \UNIT_ID AMMO/ITEM_AMMO_BOLTS COPPER fall 1/10
				shoot**,****** - moves from origin to target location
					#/#/#/#/# - number of projectiles to shoot/velocity of projectiles/hit rate of projectiles/furthest distance to hit/minimum distance to hit
					ID # - the origin units id number
			EXAMPLE: projectile location \UNIT_ID WEAPON/ITEM_WEAPON_SPEAR STEEL shoot 1/20/50/10/1 488
--]]

args = {...}

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

function getMaterial(unit)
end

if args[1] == 'location' then
	local locSource = {x=split(args[2],'/')[1],y=split(args[2],'/')[2],z=split(args[2],'/')[3]}
	local locTarget = {x=split(args[2],'/')[1],y=split(args[2],'/')[2],z=split(args[2],'/')[3]}
	if #args == 7 then locSource = {x=split(args[7],'/')[1],y=split(args[7],'/')[2],z=split(args[7],'/')[3]} end
elseif args[1] == 'unit' then
	local locSource = df.unit.find(tonumber(args[2])).pos
	local locTarget = df.unit.find(tonumber(args[2])).pos
	if #args == 7 then locSource = df.unit.find(tonumber(args[7])).pos end
end
local object=args[3]
local ptype=args[5]
local mat = args[4]
local nums = args[6]
local numsa = split(nums,'/')
local numa = {1,20,10,20,2}
for i = 1,#numsa,1 do
	numa[i] = numsa[i]
end
--if #args == 5 then locSource = args[5] end

local number = numa[1]
local height = numa[2]
local vel = numa[2]
local hr = numa[3]
local ft = numa[4]
local md = numa[5]

if mat == 'ground' then
	mat_type,mat_index = getMaterial(unitSource)
else
	mat_type = dfhack.matinfo.find(mat).type
	mat_index = dfhack.matinfo.find(mat).index
end

for i = 1, number, 1 do
	if object == 'BOULDER' then
		item_index = df.item_type['BOULDER']
		item_subtype = -1
		item=df['item_boulderst']:new()
	elseif split(object,';')[1] == 'AMMO' then
		item_index = df.item_type['AMMO']
		item_subtype = -1
		for i=0,dfhack.items.getSubtypeCount(item_index)-1,1 do
			item_sub = dfhack.items.getSubtypeDef(item_index,i)
			if item_sub.id == split(object,';')[2] then item_subtype = item_sub.subtype end
		end
		if item_subtype == 'nil' then
			print("No item of that type found")
			return
		end
		item=df['item_ammost']:new()
	elseif split(object,';')[1] == 'WEAPON' then
		item_index = df.item_type['WEAPON']
		item_subtype = -1
		for i=0,dfhack.items.getSubtypeCount(item_index)-1,1 do
			item_sub = dfhack.items.getSubtypeDef(item_index,i)
			if item_sub.id == split(object,';')[2] then item_subtype = item_sub.subtype end
		end
		item=df['item_weaponst']:new()
	end

	item.id=df.global.item_next_id
	df.global.world.items.all:insert('#',item)
	df.global.item_next_id=df.global.item_next_id+1
	if object ~= 'BOULDER' then item:setSubtype(item_subtype) end
	item:setMaterial(mat_type)
	item:setMaterialIndex(mat_index)
	item:categorize(true)
	pos = {}
	if ptype == 'fall' then
		block = dfhack.maps.ensureTileBlock(locTarget.x,locTarget.y,locTarget.z)
		pos.x = locSource.x
		pos.y = locSource.y
		pos.z = locSource.z
		item.flags.removed=true
		dfhack.items.moveToGround(item,{x=pos.x,y=pos.y,z=pos.z})
		proj = dfhack.items.makeProjectile(item)
		proj.origin_pos.x=locTarget.x
		proj.origin_pos.y=locTarget.y
		proj.origin_pos.z=locTarget.z + height
		proj.prev_pos.x=locTarget.x
		proj.prev_pos.y=locTarget.y
		proj.prev_pos.z=locTarget.z + height
		proj.cur_pos.x=locTarget.x
		proj.cur_pos.y=locTarget.y
		proj.cur_pos.z=locTarget.z + height
		proj.flags.no_impact_destroy=false
		proj.flags.bouncing=true
		proj.flags.piercing=true
		proj.flags.parabolic=true
		proj.flags.unk9=true
		proj.flags.no_collide=true
	elseif ptype == 'shoot' then
		block = dfhack.maps.ensureTileBlock(locSource.x,locSource.y,locSource.z)
		pos.x = locSource.x
		pos.y = locSource.y
		pos.z = locSource.z
		item.flags.removed=true
		dfhack.items.moveToGround(item,{x=pos.x,y=pos.y,z=pos.z})
		proj = dfhack.items.makeProjectile(item)
		proj.origin_pos.x=locSource.x
		proj.origin_pos.y=locSource.y
		proj.origin_pos.z=locSource.z
		proj.prev_pos.x=locSource.x
		proj.prev_pos.y=locSource.y
		proj.prev_pos.z=locSource.z
		proj.cur_pos.x=locSource.x
		proj.cur_pos.y=locSource.y
		proj.cur_pos.z=locSource.z
		proj.target_pos.x=locTarget.x
		proj.target_pos.y=locTarget.y
		proj.target_pos.z=locTarget.z
		proj.flags.no_impact_destroy=false
		proj.flags.bouncing=false
		proj.flags.piercing=false
		proj.flags.parabolic=false
		proj.flags.unk9=false
		proj.flags.no_collide=false
	-- Need to figure out these numbers!!!
		proj.distance_flown=0 -- Self explanatory
		proj.fall_threshold=ft -- Seems to be able to hit units further away with larger numbers
		proj.min_hit_distance=md -- Seems to be unable to hit units closer than this value
		proj.min_ground_distance=ft-1 -- No idea
		proj.fall_counter=0 -- No idea
		proj.fall_delay=0 -- No idea
		proj.hit_rating=hr -- I think this is how likely it is to hit a unit (or to go where it should maybe?)
		proj.unk22 = vel
	end
	proj.speed_x=0
	proj.speed_y=0
	proj.speed_z=0
end


