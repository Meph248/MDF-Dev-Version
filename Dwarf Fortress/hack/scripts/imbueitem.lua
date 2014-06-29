--imbueitem.lua v1.0
--[[
imbueitem -  change the material of a weapon, ammo, or armor for a set time
	ID # - the units id number
		\UNIT_ID - when triggering with a syndrome
		\WORKER_ID - when triggering with a reaction
	item - the type of item you wish to imbue
		weapon
		armor
		helm
		shoes
		shield
		glove
		pants
		ammo
	INORGANIC_TOKEN - the material to imbue the item
		Any inorganic token
	(OPTIONAL) duration - sets a specified length of time for the item to be imbued (in in-game ‘ticks’)
		DEFAULT: 0 - imbuement will last forever
EXAMPLE: imbueitem \UNIT_ID weapon MOONLIGHT 3600
--]]

args = {...}

function createcallback(item,stype,sindex)
	return function (resetweapon)
		item.mat_type = stype
		item.mat_index = sindex
	end
end

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
local mat = args[3]
local dur = tonumber(args[4])
local mat_type = dfhack.matinfo.find(mat).type
local mat_index = dfhack.matinfo.find(mat).index

local inv = unit.inventory
local items = {}
local j = 1
for i = 0, #inv - 1, 1 do
	if v:is_instance(inv[i].item) then
		items[j] = i
		j = j+1
	end
end

if #items == 0 then 
	print('No necessary item equiped')
	return
end

for i,x in ipairs(items) do
	local sitem = inv[x].item
	local stype = sitem.mat_type
	local sindex = sitem.mat_index
	sitem.mat_type = mat_type
	sitem.mat_index = mat_index

	if dur ~= 0 then
		dfhack.timeout(dur,'ticks',createcallback(sitem,stype,sindex))
	end
end
