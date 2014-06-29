--improveitem.lua v1.0
--[[
improveitem - used to improve item quality, using interactions
	ID # - the units id number
		\UNIT_ID - when triggering with a syndrome
		\WORKER_ID - when triggering with a reaction
	item - the type of item you wish to upgrade
		weapon
		armor
		helm
		shoes
		shield
		glove
		pants
		ammo
	location - where the items should be changed
		equipped - target's items which match type and ID are changed
		all - all items which match type and ID are changed
		random - a random item which matches type and ID is changed
	item to change - which items to change
		ITEM_ID - the id of the items you want to change
		ALL - all items that match location (note that specifying all ALL will target all items of the given type)
	method - how to change the items
		upgrade - changes item id from BLAH_BLAH_BLAH_1 to BLAH_BLAH_BLAH_2
		downgrade - changes item id from BLAH_BLAH_BLAH_2 to BLAH_BLAH_BLAH_1
		# - changes item id to given ITEM_ID
	(OPTIONAL) duration - sets a specified length of time for the changes to last (in in-game ‘ticks’)
		#
			DEFAULT: 0 - value changes will be permanent
--]]

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

function createcallback(x,sid)
	return function(resetitem)
		x:setQuality(sid)
	end
end

function itemSubtypes(item) -- Taken from Putnam's itemSyndrome
   local subtypedItemTypes =
    {
    ARMOR = df.item_armorst,
    WEAPON = df.item_weaponst,
    HELM = df.item_helmst,
    SHOES = df.item_shoesst,
    SHIELD = df.item_shieldst,
    GLOVES = df.item_glovest,
    PANTS = df.item_pantsst,
    TOOL = df.item_toolst,
    SIEGEAMMO = df.item_siegeammost,
    AMMO = df.item_ammost,
    TRAPCOMP = df.item_trapcompst,
    INSTRUMENT = df.item_instrumentst,
    TOY = df.item_toyst}
    for x,v in pairs(subtypedItemTypes) do
        if v:is_instance(item) then 
			return df.item_type[x]
		end
    end
    return false
end

function upgradeitem(args)
	local unit = df.unit.find(tonumber(args[1]))
	local t = args[2]
	if t == 'weapon' then v = df.item_weaponst end
	if t == 'armor' then v = df.item_armorst end
	if t == 'helm' then v = df.item_helmst end
	if t == 'shoes' then v = df.item_shoesst end
	if t == 'shield' then v = df.item_shieldst end
	if t == 'glove' then v = df.item_glovest end
	if t == 'pants' then v = df.item_pantsst end
	if t == 'ammo' then v = df.item_ammost end

	local dur = 0
	if #args == 6 then dur = tonumber(args[6]) end
	
	local sitems = {}
	if args[3] == 'equipped' then
-- Upgrade only the input items with preserve reagent
		local inv = unit.inventory
		local j = 1
		for i,x in ipairs(inv) do
			if (v:is_instance(x.item) and (x.item.subtype.id == args[4] or args[4] == 'ALL')) then
				sitems[j] = x.item
				j = j+1
			end
		end
	elseif args[3] == 'all' then
-- Upgrade all items of the same type as input
		local itemList = df.global.world.items.all
		local k = 0
		for i,x in ipairs(itemList) do
			if (v:is_instance(x) and (x.subtype.id == args[4] or args[4] == 'ALL')) then 
				sitems[k] = itemList[i] 
				k = k + 1
			end
		end
	else
-- Randomly upgrade one specific item
		local itemList = df.global.world.items.all
		local k = 0
		for i,x in ipairs(itemList) do
			if (v:is_instance(x) and (x.subtype.id == args[4] or args[4] == 'ALL')) then 
				sitems[k] = itemList[i] 
				k = k + 1
			end
		end
		local rando = dfhack.random.new()
		sitems = {sitems[rando:random(#sitems)]}
	end

	if args[5] == 'upgrade' then
-- Increase items number by one
		for _,x in ipairs(sitems) do
			sid = x.quality
			x:setQuality(sid+1)
			if dur > 0 then dfhack.timeout(dur,'ticks',createcallback(x,sid)) end
		end
	elseif args[5] == 'downgrade' then
-- Decrease items number by one
		for _,x in ipairs(sitems) do
			sid = x.quality
			x:setQuality(sid-1)
			if dur > 0 then dfhack.timeout(dur,'ticks',createcallback(x,sid)) end
		end
	else
-- Change item to new item
		for _,x in ipairs(sitems) do
			sid = x.quality
			x:setQuality(tonumber(args[5]))
			if dur > 0 then dfhack.timeout(dur,'ticks',createcallback(x,sid)) end
		end
	end
end

arg = {...}
upgradeitem(arg)
