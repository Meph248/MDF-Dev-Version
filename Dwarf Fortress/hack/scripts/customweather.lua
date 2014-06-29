--customweather.lua v1.0
--[[
customweather - cause custom flows to be spawned on the map, simulating weather
	type - the type of flow to spawn
		miasma
		mist
		mist2
		dust
		lavamist
		smoke
		dragonfire
		firebreath
		web
		undirectedgas
		undirectedvapor
		oceanwave
		seafoam
	number - the number of flows to spawn at each time step
		#
		NOTE: These will be randomized across the entire map
	size - the size of the flows to spawn
		#
	frequency - how often (in in-game ticks) to trigger the flows
		#
		NOTE: Setting this too small will have noticeable impact on your fps, I suggest >500
	duration - how long for the weather to last
		#
		This means that the total number of flows that will be spawned is (duration/frequency)*number
	(OPTIONAL) INORGANIC_TOKEN - the inorganic the flow should be made from
		Any inorganic token
		NOTE: This only applies to some of the types of flows, you can’t, for instance, make an IRON dragonfire
EXAMPLE: customweather firebreath 50 25 1000 7200
--]]

args={...}

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

function weather3(stype,number,itype,strength,frequency)
	if weathercontinue then
		dfhack.timeout(frequency,'ticks',weather(stype,number,itype,strength,frequency))
	else
		return
	end
end

function weather2(cbid)
	return function (stopweather)
		weathercontinue = false
	end
end

function weather(stype,number,itype,strength,frequency)
	return function (startweather)
		local i
		local rando = dfhack.random.new()
		local snum = flowtypes[stype]
		local inum = 0
		if itype ~= 0 then
			inum = dfhack.matinfo.find(itype).index
		end

		local mapx, mapy, mapz = dfhack.maps.getTileSize()
		local xmin = 2
		local xmax = mapx - 1
		local ymin = 2
		local ymax = mapy - 1

		local dx = xmax - xmin
		local dy = ymax - ymin
		local pos = {}
		pos.x = 0
		pos.y = 0
		pos.z = 0

		for i = 1, number, 1 do

			local rollx = rando:random(dx)
			local rolly = rando:random(dy)

			pos.x = rollx
			pos.y = rolly
			pos.z = 20
		
			local j = 0
			while not dfhack.maps.ensureTileBlock(pos.x,pos.y,pos.z+j).designation[pos.x%16][pos.y%16].outside do
				j = j + 1
			end
			pos.z = pos.z + j
			dfhack.maps.spawnFlow(pos,snum,0,inum,strength)
		end
		weather3(stype,number,itype,strength,frequency)
	end
end

local stype = args[1]
local number = tonumber(args[2])
local strength = tonumber(args[3])
local duration = tonumber(args[5])
local frequency = tonumber(args[4])
local itype = 0
if #args == 6 then
	itype = args[6]
end
local test = 'abc'
weathercontinue = true

dfhack.timeout(1,'ticks',weather(stype,number,itype,strength,frequency))
dfhack.timeout(duration,'ticks',weather2(test))
