--Enables various machines.

--[[
machina (variables for each machina) { 
building_id,
machines(array of machine ids connected),
powerNeeded
powerOutput
powerMax
current_power
}
]]--

--## INITIAL VARIABLE CALLS ##--

args={...}
local debugMode = false
local deb=args[1]
if deb == 'd' then
	debugMode = true
end

local eventful = require 'plugins.eventful'
local utils = require 'utils'
local script=require('gui/script')

local machineCurrentPower = {} --table of all machines power, associated with machine index)
local machineNeededPower = {} --(table of all machines power needed, associated with machine index)
local machineSurplusPower = {} --(table of all machines power, not counting machina)
local machineRequestTotal = {} --(table of total machina requirements from each machine)
local machineMachinaConnected = {}

local previousMachines = {}

local machina_exists = false --A variable to determine if a machina exists.  If not, this script doesn't need to update every frame.
local machina_found = false


local machinas = {} --(table of all active machina)

local registered_inorganics = {} --(table of all inorganic raws used by machina)

local factory_reactions = {} --(table of all automated factory reactions)

local mustUpdateList = true

local alreadyUpdated = false

local prefix = "DFHACK_MACHINA_" --The prefix that will precede all building names and inorganic names

local gCode = 0

local firstCall = true


--TimeWarp stuff
eventNow = false
seasonNow = false
timestream = 0
timeForward = 0
timeBackward = 0
if df.global.cur_season_tick < 3360 then
	month = 1
elseif df.global.cur_season_tick < 6720 then
	month = 2
else
	month = 3
end

function getMachinaSettings(building)
	local pv = gCode..'_'..building.id..'_machina'
	local settings = dfhack.persistent.get(pv)
	if settings == nil then
		if debugMode == true then print(pv..' not found.  Creating reference for settings...') end
		dfhack.persistent.save({key=pv})
		settings = dfhack.persistent.get(pv)
		settings:save()
	end
	return settings
end

function saveMachinaSettings()
	for i=1,#machinas,1 do
		machina = machinas[i]
		if machina ~= nil then
			settings = getMachinaSettings(machina.building)
			settings = machina.settings
			settings:save()
		end
	end
end

function boolGate(machina)
	local code = machina.building_code
	local inputs = {}
	local outputs = {}
	local hasPoweredInput = false
	local hasUnpoweredInput = false
	machina.gear_positions = {}
	machina.gear_positions = getGearPositions(machina)
	for i=1,#machina.gear_positions,1 do
		pos=machina.gear_positions[i]
		cb = dfhack.buildings.findAtTile(pos)
		if isConnectedMachine(pos,cb, machina) then
			table.insert(inputs, cb)
		elseif getmetatable(cb) == "building_gear_assemblyst"
		or getmetatable(cb) == "building_doorst" 
		or getmetatable(cb) == "building_hatchst" 
		or getmetatable(cb) == "building_grate_wallst" 
		or getmetatable(cb) == "building_grate_floorst" 
		or getmetatable(cb) == "building_bars_verticalst" 
		or getmetatable(cb) == "building_bars_floorst" 
		or getmetatable(cb) == "building_floodgatest"
		or getmetatable(cb) == "building_weaponst"
		or getmetatable(cb) == "building_bridgest" then
			if debugMode == true then print(code.." output: "..getmetatable(cb)) end
			table.insert(outputs, cb)
		end
	end
	if #inputs == 0 or #outputs == 0 then
		--Then there's no point, so do nothing
		if debugMode == true then print(code.." has no connections.") end
	else
		for i=1,#inputs,1 do
			input = inputs[i]
			if isPoweredBuilding(input) == true then hasPoweredInput = true if debugMode == true then print(code.." has a powered input.") end
			elseif isPoweredBuilding(input) == false then hasUnpoweredInput = true if debugMode == true then print(code.." has an unpowered input.") end
			else end
			if hasPoweredInput == true and hasUnpoweredInput == true then break end
		end
		--Now do the evaluation...
		if hasPoweredInput == false and hasUnpoweredInput == false then --no valid input - do nothing
		else
			local code = machina.building_code
			local command = -1 -- 1 is true, 0 is false
			if string.starts(code,prefix..'BOOLEAN_NOT') then
				if hasPoweredInput == true and hasUnpoweredInput == false then command = 0 
				elseif hasPoweredInput == false and hasUnpoweredInput == true then command = 1 end
			elseif string.starts(code,prefix..'BOOLEAN_AND') then
				if hasPoweredInput == true and hasUnpoweredInput == false then command = 1 else command = 0 end
			elseif string.starts(code,prefix..'BOOLEAN_OR') then
				if hasPoweredInput == true then command = 1 else command = 0 end
			elseif string.starts(code,prefix..'BOOLEAN_NAND') then
				if hasUnpoweredInput == true then command = 1 else command = 0 end
			elseif string.starts(code,prefix..'BOOLEAN_NOR') then
				if hasUnpoweredInput == true and hasPoweredInput == false then command = 1 else command = 0 end
			elseif string.starts(code,prefix..'BOOLEAN_XOR') then
				if hasPoweredInput == true and hasUnpoweredInput == true then command = 1 else command = 0 end
			elseif string.starts(code,prefix..'BOOLEAN_XNOR') then
				if (hasPoweredInput == true and hasUnpoweredInput == false) or (hasPoweredInput == false and hasUnpoweredInput == true) then command = 0 else command = 1 end
			elseif string.starts(code,prefix..'BOOLEAN_DEUS') then
				command = 0
			end
			
			if command == 0 then
				if debugMode == true then print(code.." evaluated to FALSE.") end
			elseif command == 1 then
				if debugMode == true then print(code.." evaluated to TRUE.") end
			end
			
			--Now alter the outputs.  Note: this may cause weird behavior if the same output is hooked to two boolean operators with different commands.
			if command ~= -1 then
				for i=1,#outputs,1 do
					output = outputs[i]
					if getmetatable(output) == "building_gear_assemblyst" then
						if command == 0 then
							if output.gear_flags.disengaged == false then
								if debugMode == true then print(code.." is disengaging: "..getmetatable(output)) end
								output:setTriggerState(1)
								output.gear_flags.disengaged = true
							end
						elseif command == 1 then
							if output.gear_flags.disengaged == true then
								if debugMode == true then print(code.." is engaging: "..getmetatable(output)) end
								output:setTriggerState(1)
								output.gear_flags.disengaged = false
							end
						end
					elseif getmetatable(output) == "building_doorst" 
					or getmetatable(output) == "building_hatchst" then
						output.door_flags.operated_by_mechanisms=true
						if command == 0 then
							if debugMode == true then print(code.." is closing: "..getmetatable(output)) end
							output.close_timer = 0
						elseif command == 1 then
							if debugMode == true then print(code.." is opening: "..getmetatable(output)) end
							output.close_timer = 1
						end
					elseif getmetatable(output) == "building_grate_wallst" 
					or getmetatable(output) == "building_grate_floorst" 
					or getmetatable(output) == "building_bars_verticalst" 
					or getmetatable(output) == "building_bars_floorst" 
					or getmetatable(output) == "building_floodgatest"
					or getmetatable(output) == "building_weaponst"
					or getmetatable(output) == "building_bridgest" then
						if command == 0 then
							if output.gate_flags.closed==false then
								if debugMode == true then print(code.." is closing: "..getmetatable(output)) end
								output.gate_flags.closing=true
								output.timer=1
							end
						elseif command == 1 then
							if output.gate_flags.closed==true then
								if debugMode == true then print(code.." is opening: "..getmetatable(output)) end
								output.gate_flags.opening=true
								output.timer=1
							end
						end
					end
				end
			end
		end
	end
end



------------------------------------------------
--## DATA USED BY THE MACHINE SYSTEM ITSELF ##--
------------------------------------------------

function table.contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

function isMachina(building)
	if getmetatable(building) == "building_workshopst" or getmetatable(building) == "building_furnacest" then
		t = df.building_def.find(building.custom_type)
		if t ~= nil and t ~= -1 then
			if string.starts(t.code, prefix) then return t.code end
		end
	end
	return nil
end

function isMachineComponent(building)
	if getmetatable(cb) == "building_axle_horizontalst"
	or getmetatable(cb) == "building_gear_assemblyst"
	or getmetatable(cb) == "building_water_wheelst"
	or getmetatable(cb) == "building_windmillst"
	or getmetatable(cb) == "building_screw_pumpst" then
		return true
	else
		return false
	end
end

function getGearPositions(machina)
	local building = machina.building
	local stage=3--building.construction_stage
	local bx=building.x1
	local by=building.y1
	local z=building.z
	local tiles = {}
	t = df.building_def.find(building.custom_type)
	for tx=0,30,1 do
		for ty=0,30,1 do
			if t.tile[stage][tx][ty] == 15 or (bx+tx == building.centerx and by+ty == building.centery) then --Gear tile or center tile
				for cx=-1,1,1 do
					for cy=-1,1,1 do
						if cx ~= cy and cx ~= -cy then --Exclude diagonals and center
							pos = df.coord:new()
							pos.x = bx+tx+cx
							pos.y = by+ty+cy
							pos.z = z
							table.insert(tiles,pos)
						end
					end
				end
				posAbove = df.coord:new()
				posAbove.x = bx+tx
				posAbove.y = by+ty
				posAbove.z = z+1
				posBelow = df.coord:new()
				posBelow.x = bx+tx
				posBelow.y = by+ty
				posBelow.z = z-1
				table.insert(tiles,posAbove)
				table.insert(tiles,posBelow)
			end
		end
	end
	return tiles
end

function isConnectedMachine(pos,cb,machina)
	local building=machina.building
	if cb ~= nil and isMachineComponent(cb) then
		if cb.machine.machine_id ~= -1 then
			if (getmetatable(cb) == "building_axle_horizontalst"
			and ((cb.is_vertical == false and (pos.x < building.x1 or pos.x > building.x2)) or (cb.is_vertical == true and (pos.y < building.y1 or pos.y > building.y2))))
			or (getmetatable(cb) == "building_axle_verticalst" and cb.z ~= building.z)
			or (getmetatable(cb) == "building_gear_assemblyst" and cb.gear_flags.disengaged == false and not string.starts(machina.building_code,prefix..'BOOLEAN')) -- boolean machina do not recieve power from gears, but they do interact with them even when disengaged.
			or (getmetatable(cb) == "building_water_wheelst"
			and ((cb.is_vertical == false and cb.x1 == pos.x-1) or (cb.is_vertical == true and cb.y1 == pos.y-1)))
			or (getmetatable(cb) == "building_windmillst" and cb.z == building.z+1)
			or (getmetatable(cb) == "building_screw_pumpst") then
				return true
			else return false end
		else return false end
	else return false end
end

function getConnectedMachines(machina)
	local machines = {}
	for i=1,#machina.gear_positions,1 do
		pos=machina.gear_positions[i]
		cb = dfhack.buildings.findAtTile(pos)
		if isConnectedMachine(pos,cb,machina) and not table.contains(machines, cb.machine.machine_id) then
			table.insert(machines, cb.machine.machine_id)
		end
	end
	return machines
end

function addMachina(building)
	machinaCode = isMachina(building)
	if machinaCode ~= nil then -- Only machina buildings can be read here.
		machina = {}
		table.insert(machinas, machina)
		machina.building = building
		machina.building_id = building.id
		machina.building_code = machinaCode
		machina.machines = {}
		machina.min_power = 10 --should come from raw
		machina.out_power = 0 --should come from raw
		if string.starts(machinaCode,prefix..'BOOLEAN') then machina.max_power = 1 else
		machina.max_power = 100 end --should come from raw
		machina.cur_power = 0
		machina.gear_positions = getGearPositions(machina)
		machina.machines = getConnectedMachines(machina)
		machina.settings = getMachinaSettings(building)
		machina_found = true
		
		--Cart Loader spots
		if string.starts(machina.building_code,prefix..'LOADER') then
			local pos = {}
			pos.x = building.centerx
			pos.y = building.centery
			pos.z = building.z
			machina.outputBlocks = {
							{x = pos.x, y = pos.y + 1, z = pos.z},
							{x = pos.x + 1, y = pos.y, z = pos.z},
							{x = pos.x, y = pos.y - 1, z = pos.z},
							{x = pos.x - 1, y = pos.y, z = pos.z}
						}
		end
		
		--Factory connections
		if string.starts(machina.building_code,prefix..'FACTORY') or string.starts(machina.building_code,prefix..'CATAPULT') or string.starts(machina.building_code,prefix..'DRILLING_RIG') then
		
			local factory_type = ""
	
			if string.starts(machina.building_code,prefix..'FACTORY_STONECUTTER') then factory_type = "STONECUTTER"
			elseif string.starts(machina.building_code,prefix..'FACTORY_WOODCUTTER') then factory_type = "WOODCUTTER"
			elseif string.starts(machina.building_code,prefix..'FACTORY_BONECUTTER') then factory_type = "BONECUTTER"
			elseif string.starts(machina.building_code,prefix..'FACTORY_FURNITURE') then factory_type = "FURNITURE"
			elseif string.starts(machina.building_code,prefix..'FACTORY_SORTER') then factory_type = "SORTER"
			elseif string.starts(machina.building_code,prefix..'FACTORY_JEWELER') then factory_type = "JEWELER"
			elseif string.starts(machina.building_code,prefix..'FACTORY_CLOTHIER') then factory_type = "CLOTHIER"
			elseif string.starts(machina.building_code,prefix..'FACTORY_GRINDER') then factory_type = "GRINDER"
			elseif string.starts(machina.building_code,prefix..'FACTORY_IMPROVEMENTS') then factory_type = "IMPROVEMENTS"
			elseif string.starts(machina.building_code,prefix..'FACTORY_FOOD') then factory_type = "FOOD"
			elseif string.starts(machina.building_code,prefix..'FACTORY_BUTCHER') then factory_type = "BUTCHER"
			elseif string.starts(machina.building_code,prefix..'FACTORY_SMELTER') then factory_type = "SMELTER"
			elseif string.starts(machina.building_code,prefix..'FACTORY_FORGE') then factory_type = "FORGE"
			end
			
			--First get the input and output positions
			local pos = {}
			pos.x = building.centerx
			pos.y = building.centery
			pos.z = building.z
			inputBlocks = {}
			outputBlocks = {}
			mainOutputBlocks = {}
			secondaryOutputBlocks = {}
			checkPositions = {
							{x = pos.x, y = pos.y + 2, z = pos.z},
							{x = pos.x + 2, y = pos.y, z = pos.z},
							{x = pos.x, y = pos.y - 2, z = pos.z},
							{x = pos.x - 2, y = pos.y, z = pos.z}
						}
			outputPositions = {
							{x = pos.x, y = pos.y + 3, z = pos.z},
							{x = pos.x + 3, y = pos.y, z = pos.z},
							{x = pos.x, y = pos.y - 3, z = pos.z},
							{x = pos.x - 3, y = pos.y, z = pos.z}
						}
			
			table.insert(inputBlocks,pos) -- to take input directly from the building center
			for i = 1, #checkPositions, 1 do
				cpos = checkPositions[i]
				cb = dfhack.buildings.findAtTile(cpos)
				if cb ~= nil then
				
					local cbIsInput = false
					
					if getmetatable(cb) == "building_workshopst" then
						t = df.building_def.find(cb.custom_type)
						if t ~= nil and t ~= -1 then
							if string.starts(t.code, prefix..'INPUT') then 
								cbIsInput = true
							end
						end
					elseif getmetatable(cb) == "building_trapst" then
						cbIsInput = true
					end
					
					if cbIsInput == true then
						table.insert(inputBlocks,cpos)
						--Find the opposing output, if it exists
						local opi = (i+2)%4 -- Opposing Position Index
						if opi == 0 then opi = 4 end
						opos = checkPositions[opi]
						ocb = dfhack.buildings.findAtTile(opos)
						if ocb ~= nil then
							if getmetatable(ocb) == "building_workshopst" then
								ot = df.building_def.find(ocb.custom_type)
								if ot ~= nil and ot ~= -1 then
									if string.starts(ot.code, prefix..'OUTPUT') then 
										table.insert(mainOutputBlocks,outputPositions[opi])
									end
								end
							end
						end
					else
						local cbIsOutput = false
						if getmetatable(cb) == "building_workshopst" then
							t = df.building_def.find(cb.custom_type)
							if t ~= nil and t ~= -1 then
								if string.starts(t.code, prefix..'OUTPUT') then 
									cbIsOutput = true
								end
							end
						end
						if cbIsOutput == true then
							cpos = outputPositions[i]
							table.insert(outputBlocks,cpos) 
						end
					end
				end
			end
			if #outputBlocks == 1 then
				mainOutputBlocks = outputBlocks
				secondaryOutputBlocks = outputBlocks
			elseif #mainOutputBlocks == 0 then
				mainOutputBlocks = outputBlocks
				secondaryOutputBlocks = outputBlocks
			else
				--fill the secondary output block table by checking up on which output blocks are main ones
				for i = 1, #outputBlocks, 1 do
					cpos = outputBlocks[i]
					isMain = false
					for j = 1, #mainOutputBlocks, 1 do
						mpos = mainOutputBlocks[j]
						if cpos.x == mpos.x and cpos.y == mpos.y and cpos.z == mpos.z then
							isMain = true
							break
						end
					end
					if isMain == true then
					else
						table.insert(secondaryOutputBlocks,cpos)
					end
				end
			end
			
			machina.factory_type = factory_type
			machina.inputBlocks = inputBlocks
			machina.outputBlocks = outputBlocks
			machina.mainOutputBlocks = mainOutputBlocks
			machina.secondaryOutputBlocks = secondaryOutputBlocks
			
			for z=0, #machina.inputBlocks-1, 1 do
				local pos = machina.inputBlocks[z]
				if pos ~= nil then
					inputBlock = dfhack.maps.ensureTileBlock(pos.x,pos.y,pos.z)
					inputBlock.designation[pos.x%16][pos.y%16].traffic = 3
				end
			end
		end
		
		
		if machina_exists == false then -- updates are not running
			if debugMode == true then
				print("Machina detected.  Starting machina updates.")
			end
			machina_exists = true
			dfhack.timeout(1,"ticks",function() update() end)
		end
	end
end

function removeMachina(building)
	building_id = building.id
	for i=1,#machinas,1 do
		machina = machinas[i]
		if machina.building_id == building_id then
			table.remove(machinas, machina)
		end
	end
end

function isPoweredBuilding(building)
	if building.machine.machine_id ~= -1 then
		for i=0,#df.global.world.machines.all-1,1 do
			machine = df.global.world.machines.all[i]
			machine_id = machine.id
			if machine_id == building.machine.machine_id then
				if machine.flags.active == true then
					return true
				else
					return false
				end
			end
		end
	end
	return nil
end

function storeMachines()
	previousMachines = {}
	for i=0,#df.global.world.machines.all-1,1 do
		machine=df.global.world.machines.all[i]
		previousMachines[i]=machine.id
	end
end


function updateMachinaList()
	if debugMode == true then print('Updating machina list...') end
	print('Updating')
	machina_found = false
	machinas = {}
	machineCurrentPower = {}
	machineNeededPower = {}
	machineSurplusPower = {}
	machineRequestTotal = {}
	machineMachinaConnected = {}
	previousMachines={}

	for i=0,#df.global.world.buildings.all-1,1 do
		building = df.global.world.buildings.all[i]
		addMachina(building)
	end
	if machina_found == false then
		if debugMode == true then print('No machina found.') end
		machina_exists = false
	else
		updateMachinaConnections()
	end
end

function updateMachinaConnections()
	if debugMode == true then print('Updating machina connections...') end
	for i=1,#machinas,1 do
		machina = machinas[i]
		if machina ~= nil then
			machina.machines = getConnectedMachines(machina)
			machina.cur_power = 0
			if debugMode == true then print('Connections for ('..machina.building_code..') found: '..#machina.machines) end
		end
	end
	updateMachinaPower()
end

function updateMachinaPower()
	if debugMode == true then print('Updating machina power...') end
	--force all machines to update as regular, if possible
	machineCurrentPower = {}
	machineNeededPower = {}
	machineSurplusPower = {}
	machineRequestTotal = {} -- unlike others, this is based on the machine's id, not its index.

	for i=1,#machinas,1 do
		machina = machinas[i]
		if machina ~= nil then
			for m=1,#machina.machines,1 do -- This was added with insert, so the array begins with 1.
				machine_id = machina.machines[m]
				--machine.needed_power += machina.min_power *(if updated)
				if machineRequestTotal[machine_id] == nil then machineRequestTotal[machine_id] = 0 end
				machineRequestTotal[machine_id] = machineRequestTotal[machine_id] + machina.max_power
			end
		end
	end

	--Allocate power
	for i=0,#df.global.world.machines.all-1,1 do
		machine = df.global.world.machines.all[i]
		machine_id = machine.id
		machineCurrentPower[i] = machine.cur_power
		machineNeededPower[i] = machine.min_power
		machineSurplusPower[i] = machine.cur_power - machine.min_power
		machineMachinaConnected[i] = {}
		
		if machineRequestTotal[machine_id] == nil then machineRequestTotal[machine_id] = 0 end
		local requestTotal = machineRequestTotal[machine_id]

		if machineSurplusPower[i] > 0 then
			for maId=1,#machinas,1 do
				machina = machinas[maId]
				if machina ~= nil then
					for meId=1,#machina.machines,1 do
						if machina.machines[meId] == machine_id then
							percentRequested = machina.max_power / requestTotal
							powerGranted = percentRequested*machineSurplusPower[i]
							machina.cur_power = machina.cur_power + powerGranted
							if debugMode == true then print('Power allocated to ('..machina.building_code..'): '..machina.cur_power) end
						end
					end
				end
			end
		end
	end
	
	--Boolean Gates
	for i=1,#machinas,1 do
		machina = machinas[i]
		if machina ~= nil then
			local code = machina.building_code
			if string.starts(code,prefix..'BOOLEAN') then
				boolGate(machina)
			end
		end
	end
	
	--TimeWarp stuff
	timechange = 0
	eventNow = false
	seasonNow = false
	if df.global.cur_season_tick < 3360 then
		month = 1
	elseif df.global.cur_season_tick < 6720 then
		month = 2
	else
		month = 3
	end
	
	storeMachines()
	--alreadyUpdated = true
end

eventful.onBuildingCreatedDestroyed.machina=function(building_id)
	mustUpdateList = true
	if machina_exists == false then
		dfhack.timeout(1,"ticks",function() update() end)
	end
end

function getMachinaByBuildingId(id)
	for i=1,#machinas,1 do
		if machinas[i].building.id == id then return machinas[i] end
	end
	return nil
end

function getBuildingById(id)
	for i=0,#df.global.world.buildings.all-1,1 do
		if df.global.world.buildings.all[i].id == id then return df.global.world.buildings.all[i] end
	end
	return nil
end

function getMachineById(id)
	for i=0,#df.global.world.machines.all-1,1 do
		if df.global.world.machines.all[i].id == id then return df.global.world.machines.all[i] end
	end
	return nil
end

function update()
	if mustUpdateList == true then
		updateMachinaList()
		mustUpdateList = false
	end
	if machina_exists == true then
		needsConnectionUpdating = false
		needsPowerUpdating = false
		
		if not alreadyUpdated then
			local currentMachines = #df.global.world.machines.all-1
			if currentMachines == -1 then currentMachines = 0 end
			if #previousMachines ~= currentMachines then
				needsConnectionUpdating = true
				if debugMode == true then
					print("Machine number changed from "..#previousMachines.." to "..currentMachines.."  Updating connections...")
				end
				storeMachines() --?
			else
				for i=0,#previousMachines-1,1 do
					machine = df.global.world.machines.all[i]
					machine_id = machine.id
					if previousMachines[i] ~= machine.id then
						needsConnectionUpdating = true
						if debugMode == true then
							print("Machine id changed.  Updating connections...")
						end
						break
					end
					if machine.cur_power ~= machineCurrentPower[i] or machine.min_power ~= machineNeededPower[i] then
						needsPowerUpdating = true -- because a power level has changed
						if debugMode == true then
							print("Machine power changed.  Updating power levels...")
						end
						break
					end
				end
			end
		end

		if needsConnectionUpdating == true then updateMachinaConnections()
		elseif needsPowerUpdating == true then updateMachinaPower()
		end
		
		timewarps = {}
		
		--for TimeWarp
		timestream = 0
		timex = -30000
		timey = -30000
		timez = -30000
		timeforward = 0
		timebackward = 0
		timetorque = 0
		timeweight = 0
		
		--Actual update
		for i=1,#machinas,1 do
			machina = machinas[i]
			if machina.cur_power > 0 then
				if alreadyUpdated == true and debugMode == true then 
					print("Machina "..i.." ("..machina.building_code..") powered: "..machina.cur_power) 
				end
				building = machina.building
				if building ~= nil and building.construction_stage == 3 then
					--Run the script for powered machines.
					local code = machina.building_code
					if string.starts(code,prefix..'DRILLING_RIG') then
						drillPump(machina,machina.cur_power)
					elseif string.starts(code,prefix..'SEISMOGRAPH') then
						scanArea(machina,machina.cur_power)
					elseif string.starts(code,prefix..'CATAPULT') then
						catapultAutoFire(machina,machina.cur_power)
					elseif string.starts(code,prefix..'MIST') then
						generateMist(machina,machina.cur_power)
					elseif string.starts(code,prefix..'STATUE') then
						statueValue(building,machina.cur_power)
					elseif string.starts(code,prefix..'ATTRACT') then
						attractCreatures(machina,machina.cur_power)
					elseif string.starts(code,prefix..'REPEL') then
						repelCreatures(machina,machina.cur_power)
					elseif string.starts(code,prefix..'TESLA') then
						teslaCoil(machina,machina.cur_power)
					elseif string.starts(code,prefix..'FACTORY') then
						factoryOperate(machina,machina.cur_power)
					elseif string.starts(code,prefix..'LOADER') then
						loaderOperate(machina,machina.cur_power)
					elseif string.starts(code,prefix..'TIMEWARP') then
						table.insert(timewarps,machina)
						--TimeWarp
						local building = machina.building
						local settings = machina.settings
						local power = machina.cur_power
						
						if settings.ints[1] == -1 then
							timeForward = timeForward + power
						else
							timeBackward = timeBackward + power
						end
						
						timetorque = timetorque + power
					end
				end
			end
		end
		
		alreadyUpdated = false
		
		--TimeWarp stuff
		
		timeMoving = false
		
		if df.global.cur_year > 0 then
			mult = 10000
			if timeForward > mult then 
				local num = math.floor(timeForward/mult)			
				timeForward = timeForward - (mult*num)
				timestream = timestream + num
				timeMoving = true
			end
			if timeBackward > mult then 
				local num = math.floor(timeBackward/mult)			
				timeBackward = timeBackward - (mult*num)
				timestream = timestream - num
				timeMoving = true
			end
		end
		
		eventFound = false
		for i=0,#df.global.timed_events-1,1 do
			event=df.global.timed_events[i]
			if event.season == df.global.cur_season and event.season_ticks <= df.global.cur_season_tick then
				if eventNow == false then
					--df.global.cur_season_tick=event.season_ticks
					event.season_ticks = df.global.cur_season_tick
					eventNow = true
				end
				eventFound = true
			end
		end
		if eventFound == false then eventNow = false end
		
		if df.global.cur_season_tick >= 3359 and df.global.cur_season_tick < 6719 and month == 1 then
			seasonNow = true
			month = 2
			if df.global.cur_season_tick > 3359 then
				df.global.cur_season_tick = 3360
			end
		elseif df.global.cur_season_tick >= 6719 and df.global.cur_season_tick < 10079 and month == 2 then
			seasonNow = true
			month = 3
			if df.global.cur_season_tick > 6719 then
				df.global.cur_season_tick = 6720
			end
		elseif df.global.cur_season_tick >= 10079 then
			seasonNow = true
			month = 1
			if df.global.cur_season_tick > 10080 then
				df.global.cur_season_tick = 10079
			end
		else
			seasonNow = false
		end
		
		if df.global.cur_year > 0 then
			if timeMoving == true then
				
				if df.global.cur_season_tick < 0 then
					df.global.cur_season_tick = df.global.cur_season_tick + 10080
					df.global.cur_season = df.global.cur_season-1
					eventNow = true
				end
				if df.global.cur_season < 0 then
					df.global.cur_season = df.global.cur_season + 4
					df.global.cur_year_tick = df.global.cur_year_tick + 403200
					df.global.cur_year = df.global.cur_year - 1
					eventNow = true
				end
				
				allUnits = df.global.world.units.active
				for i=#allUnits-1,0,-1 do	-- search list in reverse
					u = allUnits[i]
					timeSlip(u,timewarps)
				end
				
				if (eventNow == false and seasonNow == false) or timestream < 0 then
					--df.global.cur_year_tick=df.global.cur_year_tick + 10
					--df.global.cur_season_tick=(math.floor(df.global.cur_year_tick/10))-((df.global.cur_season)*100800)
					
					if timestream >= 0 then
						df.global.cur_season_tick=df.global.cur_season_tick + timestream
					else
						df.global.cur_season_tick=df.global.cur_season_tick
						--df.global.cur_year_tick=df.global.cur_year_tick
					end
					
					newYearTick = (df.global.cur_season_tick*10)+((df.global.cur_season)*100800)
					if df.global.cur_year_tick < newYearTick - 1200 or timestream < 0 then
						df.global.cur_year_tick = newYearTick
					end
				end
			end
		end
		timestream = 0
		
		dfhack.timeout(1,"ticks",function() update() end)
	else
		if debugMode == true then 
			print("No machinas exist.  Stopping machina updates.") 
		end
	end
end

function timeSlip(u,timewarps,hit)
	local multfactor = 0.1
	local rand = 0
	
	if u.flags1.dead == false then
		rand = math.random(10)
	else
		rand = math.random(10) -- math.random(1000)
	end
	if hit then rand = 1 end
	if rand == 1 then
		--Hit by a time discharge.  Calculate effect strength...
		
		local tf = 0
		local tb = 0
		
		for i=1,#timewarps,1 do
			machina = timewarps[i]
			local building = machina.building
			local settings = machina.settings
			local power = machina.cur_power
			
			local distance = math.floor(math.sqrt((u.pos.x - building.centerx)^2 + (u.pos.y - building.centery)^2 + (u.pos.z - building.z)^2))
			
			if distance < 1 then distance = 1 end
			
			if settings.ints[1] == -1 then
				tf = tf + math.floor(power/(distance^2))
			else
				tb = tb + math.floor(power/(distance^2))
			end
		end
		
		local energy = math.floor((tf + tb)*multfactor)
		local flow = math.floor((tf - tb)*multfactor)
		local torque = energy - math.abs(flow)
		
		rand = math.random(10)
		
		if energy > rand or hit then
			--print(dfhack.TranslateName(u.name)..' hit by time discharge - energy: '..energy..', flow: '..flow..', torque: '..torque)
			
			if u.flags1.dead == false and u.idle_area.z > -1 and not (u.idle_area.x == u.pos.x and u.idle_area.y == u.pos.y and u.idle_area.z == u.pos.z) then hasIdleArea = true else hasIdleArea = false end
			if u.flags1.dead == false and u.path.dest.z > -1 and not (u.path.dest.x == u.pos.x and u.path.dest.y == u.pos.y and u.path.dest.z == u.pos.z) then hasDest = true else hasDest = false end
			
			moved = false
			
			if u.flags1.dead == true or (hasDest == true and hasIdleArea == true) then canClone = true else canClone = false end
			
			if flow < 0 then
				if hasDest == true then
					--rush to the end of the path
					fixAge(u,0,torque,canClone)
					u.pos:assign(u.path.dest)
					moved = true
				else
				--be born earlier and die of old age
					fixAge(u,math.floor(flow),torque,canClone)
				end
			elseif flow > 0 then
				if hasIdleArea == true then
					fixAge(u,0,torque,canClone)
					u.pos:assign(u.idle_area)
					moved = true
				else
					fixAge(u,math.floor(flow),torque,canClone)
				end
			else
				fixAge(u,0,torque,canClone)
			end
			
			if moved == true then
				timeSlip(u,timewarps,true)
			end
		end
	end		

end

dfhack.onStateChange.loadMachina = function(code)
	if code==SC_MAP_LOADED then
		gCode = df.global.world.world_data.active_site[0].id
		factory_reactions = {}
		--Load all reactions
		for i,reaction in ipairs(df.global.world.raws.reactions) do
			if string.starts(reaction.code,'LUA_HOOK_MACHINA_ASSIST') then
				eventful.registerReaction(reaction.code,drillDown)
				registered_reactions = true
			elseif string.starts(reaction.code,'LUA_HOOK_MACHINA_CHECK') then
				eventful.registerReaction(reaction.code,checkPower)
				registered_reactions = true
			elseif string.starts(reaction.code,'LUA_HOOK_MACHINA_CALL_CARAVAN') then
				eventful.registerReaction(reaction.code,callCaravan)
				registered_reactions = true
			elseif string.starts(reaction.code,'LUA_HOOK_MACHINA_DRILLING_RIG_DOWN') then
				eventful.registerReaction(reaction.code,drillDown)
				registered_reactions = true
			elseif string.starts(reaction.code,'LUA_HOOK_MACHINA_DRILLING_RIG_UP') then
				eventful.registerReaction(reaction.code,drillUp)
				registered_reactions = true
			elseif string.starts(reaction.code,'LUA_HOOK_MACHINA_DRILLING_RIG_PUMP') then
				eventful.registerReaction(reaction.code,drillPumpManual)
				registered_reactions = true
			elseif string.starts(reaction.code,'LUA_HOOK_MACHINA_CATAPULT_ADJUST') then
				eventful.registerReaction(reaction.code,catapultAdjust)
				registered_reactions = true
			elseif string.starts(reaction.code,'LUA_HOOK_MACHINA_CATAPULT_FIRE_UNIT') then
				eventful.registerReaction(reaction.code,catapultFireUnit)
				registered_reactions = true
			elseif string.starts(reaction.code,'LUA_HOOK_MACHINA_CATAPULT_FIRE') then
				eventful.registerReaction(reaction.code,catapultFireItem)
				registered_reactions = true
			elseif string.starts(reaction.code,'LUA_HOOK_MACHINA_FACTORY_ADJUST') then
				eventful.registerReaction(reaction.code,factoryAdjust)
				registered_reactions = true
			elseif string.starts(reaction.code,'LUA_HOOK_MACHINA_INPUT_ADJUST') then
				eventful.registerReaction(reaction.code,factoryInputAdjust)
				registered_reactions = true
			elseif string.starts(reaction.code,'LUA_HOOK_MACHINA_OUTPUT_ADJUST') then
				eventful.registerReaction(reaction.code,factoryOutputAdjust)
				registered_reactions = true
			elseif string.starts(reaction.code,'LUA_HOOK_MACHINA_INPUT_LOAD') then
				eventful.registerReaction(reaction.code,factoryInputLoad)
				registered_reactions = true
			elseif string.starts(reaction.code,'LUA_HOOK_MACHINA_CHARGE_CAPACITOR') then
				eventful.registerReaction(reaction.code,chargeCapacitor)
				registered_reactions = true
			elseif string.starts(reaction.code,'LUA_HOOK_MACHINA_TIMEWARP_ADJUST') then
				eventful.registerReaction(reaction.code,timewarpAdjust)
				registered_reactions = true
			elseif string.starts(reaction.code,prefix..'FACTORY') then -- Special automatic factory reactions
				table.insert(factory_reactions,reaction)
			end
		end
		
		firstCall = true
		machina_exists = false
		alreadyUpdated = false
		print('Machina: Loaded.')
		
		updateMachinaList()
	else
	end
end




------------------------------------------
--## DATA USED BY INDIVIDUAL MACHINES #$--
------------------------------------------

--Noisy machinery

function add_thought(unit, code)
    for _,v in ipairs(unit.status.recent_events) do
        if v.type == code then
            v.age = 0
            return
        end
    end

    unit.status.recent_events:insert('#', { new = true, type = code })
end

function wake_unit(unit)
    local job = unit.job.current_job
    if not job or job.job_type ~= df.job_type.Sleep then
        return
    end

    if job.completion_timer > 0 then
        unit.counters.unconscious = 0
        add_thought(unit, df.unit_thought_type.SleepNoiseWake)
    elseif job.completion_timer < 0 then
        add_thought(unit, df.unit_thought_type.Tired)
    end

    job.pos:assign(unit.pos)

    job.completion_timer = 0

    unit.path.dest:assign(unit.pos)
    unit.path.path.x:resize(0)
    unit.path.path.y:resize(0)
    unit.path.path.z:resize(0)

    unit.counters.job_counter = 0
end

function makeNoise(building,radius)
	bx = building.centerx
	by = building.centery
	bz = building.z
	for _,v in ipairs(df.global.world.units.active) do
		if not job or job.job_type ~= df.job_type.Sleep then
		else
			local x,y,z = dfhack.units.getPosition(v)
			if x and dfhack.units.isCitizen(v) and 
				v.pos.x <= bx + radius and
				v.pos.x >= bx - radius and
				v.pos.y <= by + radius and
				v.pos.y >= by - radius and
				v.pos.z <= bz + radius and
				v.pos.z >= bz - radius then
				disturb = 0
				if 
				v.pos.x <= bx + radius/2 and
				v.pos.x >= bx - radius/2 and
				v.pos.y <= by + radius/2 and
				v.pos.y >= by - radius/2 and
				v.pos.z <= bz + radius/2 and
				v.pos.z >= bz - radius/2 then disturb = disturb +1 end
				if math.random(2) > 1 then disturb = disturb +1 end
				if math.random(4) > 1 then disturb = disturb +1 end
				if disturb == 1 then
					add_thought(unit, df.unit_thought_type.SleepNoise)
				elseif disturb == 2 then
					add_thought(unit, df.unit_thought_type.SleepNoiseMajor)
				elseif disturb == 3 then
					wake_unit(v)
				end
			end
		end
	end
end

--Power readout

function checkPower(reaction,unit,job,input_items,input_reagents,output_items,call_native)
	local building = dfhack.buildings.findAtTile(unit.pos)
	local machina = getMachinaByBuildingId(building.id)
	local power = machina.cur_power
	local buildingname = "machine"
	if power == 0 then
		dfhack.gui.showAnnouncement( "The "..buildingname.." is not powered." , COLOR_RED, true)
	else
		dfhack.gui.showAnnouncement( "The "..buildingname.." has a power level of: "..power.."." , COLOR_WHITE, true)
	end
end

--Friction Machine

function chargeCapacitor(reaction,unit,job,input_items,input_reagents,output_items,call_native)
	local building = dfhack.buildings.findAtTile(unit.pos)
	local machina = getMachinaByBuildingId(building.id)
	local power = machina.cur_power
	if power >= 50 then
		input_items[0].flags.PRESERVE_REAGENT = false
		reaction.products[0].probability = 100
	else
		dfhack.gui.showAnnouncement( dfhack.TranslateName(unit.name).." cancels "..reaction.name..": Needs more power." , COLOR_RED, true)
	end
end

function ripPart(unit)
	--wound random part
	part_id = math.random(#unit.body.body_plan.body_parts)-1
	trg=unit
	body = trg.body
	
	
	local l = df.global.world.proj_list
	local lastlist=l
	l=l.next
	count = 0
	  while l do
		  count=count+1
			if l.next==nil then
					lastlist=l
			end
		  l = l.next
		end
 
	unitTarget=unit
 
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
	proj.speed_x=0
	proj.speed_y=0
	proj.speed_z=-math.random(1000000)
	unitoccupancy = dfhack.maps.getTileBlock(unitTarget.pos).occupancy[unitTarget.pos.x%16][unitTarget.pos.y%16]
	if not unitTarget.flags1.on_ground then 
			unitoccupancy.unit = false 
	else 
			unitoccupancy.unit_grounded = false 
	end
	unitTarget.flags1.projectile=true
	unitTarget.flags1.on_ground=false
end

function createItem(mat,itemType,quality,pos)
	if itemType[1] ~= -1 then
		local item=df['item_'..df.item_type[itemType[1]]:lower()..'st']:new()
		item.id=df.global.item_next_id
		df.global.world.items.all:insert('#',item)
		df.global.item_next_id=df.global.item_next_id+1
		if itemType[2]~=-1 then
			item:setSubtype(itemType[2])
		end
		item:setMaterial(mat.type)
		item:setMaterialIndex(mat.index)
		item:categorize(true)
		item.flags.removed=true
		item:setSharpness(1,0)
		item:setQuality(quality)
		item:setMakerRace(df.global.ui.race_id)
		dfhack.items.moveToGround(item,{x=pos.x,y=pos.y,z=pos.z})
		setForbiddenStatus(item)
		local building = dfhack.buildings.findAtTile(pos)
		if building == nil then
			ejectItem(nil,item,pos)
		end
		return item
	else
		return nil
	end
end

function ejectItem(building,item,pos)
	if item then
		-- remove from previous block
		if item.flags.on_ground then
			block = dfhack.maps.ensureTileBlock(item.pos.x,item.pos.y,item.pos.z)
			other_items = false
			for i = #block.items - 1, 0, -1 do
				if block.items[i] == item.id then
					--print("found item in block, removing it, index = " .. i .. "/" .. #block.items)
					block.items:erase(i)
				elseif not other_items then
					other_item = df.item.find(block.items[i])
					if other_item and other_item.pos.x == item.pos.x and other_item.pos.y == item.pos.y and other_item.pos.z == item.pos.z then
						other_items = true
					end
				end
			end
			if not other_items then
				block.occupancy[item.pos.x%16][item.pos.y%16].item=false
			end
		end
		itemid = item.id
		item.pos.x=pos.x
		item.pos.y=pos.y
		item.pos.z=pos.z
		item.flags.on_ground=true
		--dfhack.items.moveToGround(item,pos)
		item:moveToGround(pos.x,pos.y,pos.z)
		item.flags.in_building=false
		setForbiddenStatus(item)
		if building ~= nil then
			for i = 0, #item.general_refs - 1, 1 do
				if getmetatable(item.general_refs[i]) == 'general_ref_building_holderst' then
					item.general_refs:erase(i)
				end
			end
			for i = 0, #building.contained_items - 1, 1 do
				ic = building.contained_items[i].item
				if ic.id == itemid then
					building.contained_items:erase(i)
					break
				end
			end
		end
	end	
end

--Catapult

function catapultAdjust(reaction,unit,job,input_items,input_reagents,output_items,call_native)
	local building = dfhack.buildings.findAtTile(unit.pos)
	local machina = getMachinaByBuildingId(building.id)
	local settings = machina.settings
	if settings.ints[1] == -1 then -- initial settings
		settings.ints[1] = 0 -- direction
		settings.ints[2] = 45 -- angle
		settings.ints[3] = 100 -- distance/power
		settings.ints[4] = -1 -- -1 = power, 0 = distance
		settings.ints[5] = -1 -- -1 = not automatic, 0 = everyone triggers, 1 = enemy only
		settings.ints[6] = -1 -- -1 = don't fire items, 0 = fire items
		settings.ints[7] = 10000 -- cooldown
	end
	local script=require('gui/script')
    script.start(function()
        local amountok, amount
		amount = settings.ints[1]
        repeat amountok,amount=script.showInputPrompt('Adjust Direction','Select the direction in degrees (0-360)',COLOR_LIGHTGREEN, amount) until tonumber(amount) and tonumber(amount) >= 0 and tonumber(amount) <= 360
		settings.ints[1] = amount
		amount = settings.ints[2]
        repeat amountok,amount=script.showInputPrompt('Adjust Angle','Set the vertical angle (0-90)',COLOR_LIGHTGREEN, amount) until tonumber(amount) and tonumber(amount) >= 0 and tonumber(amount) <= 90
		settings.ints[2] = amount
		amount = settings.ints[3]
        repeat amountok,amount=script.showInputPrompt('Adjust Power','Set the power level (0-270)',COLOR_LIGHTGREEN, amount) until tonumber(amount) and tonumber(amount) >= 0 and tonumber(amount) <= 270000
		settings.ints[3] = amount
		local pSettings = getMachinaSettings(building)
		pSettings = settings
		pSettings:save()
	end)
end

function catapultFlingItem(item,settings)
	if item then
		building = dfhack.buildings.findAtTile(item.pos)
		local l = df.global.world.proj_list
		local lastlist=l
		l=l.next
		count = 0
		  while l do
			  count=count+1
				if l.next==nil then
						lastlist=l
				end
			  l = l.next
			end
		
		newlist = df.proj_list_link:new()
		lastlist.next=newlist
		newlist.prev=lastlist
		proj = df.proj_itemst:new()
		newlist.item=proj
		proj.link=newlist
		proj.id=df.global.proj_next_id
		df.global.proj_next_id=df.global.proj_next_id+1
		proj.item=item
		proj.origin_pos.x=item.pos.x
		proj.origin_pos.y=item.pos.y
		proj.origin_pos.z=item.pos.z
		proj.prev_pos.x=item.pos.x
		proj.prev_pos.y=item.pos.y
		proj.prev_pos.z=item.pos.z
		proj.cur_pos.x=item.pos.x
		proj.cur_pos.y=item.pos.y
		proj.cur_pos.z=item.pos.z
		proj.flags.no_impact_destroy=true
		proj.flags.piercing=true
		proj.flags.parabolic=true
		proj.flags.unk9=true
		
		local phi = (settings.ints[1])*(math.pi/180)
		local theta = (90-settings.ints[2])*(math.pi/180)
		local radius = settings.ints[3]*1000
		local yc = math.floor(radius * math.sin(theta) * math.cos(phi))
		local xc = math.floor(radius * math.sin(theta) * math.sin(phi))
		local zc = math.floor(radius * math.cos(theta))
		proj.speed_x=xc
		proj.speed_y=-yc
		proj.speed_z=zc
		
		itemoccupancy = dfhack.maps.getTileBlock(item.pos).occupancy[item.pos.x%16][item.pos.y%16]
		if not item.flags.on_ground then 
				itemoccupancy.item = false 
		else 
		end
		item.flags.on_ground=false
		
		if building ~= nil then
			for i = 0, #item.general_refs - 1, 1 do
				if getmetatable(item.general_refs[i]) == 'general_ref_building_holderst' then
					item.general_refs:erase(i)
				end
			end
			for i = 0, #building.contained_items - 1, 1 do
				ic = building.contained_items[i].item
				if ic.id == item.id then
					building.contained_items:erase(i)
					break
				end
			end
		end
	end
end

function catapultFlingUnit(unit,settings)
	if unit then
		local l = df.global.world.proj_list
		local lastlist=l
		l=l.next
		count = 0
		  while l do
			  count=count+1
				if l.next==nil then
						lastlist=l
				end
			  l = l.next
			end
	 
		unitTarget=unit
	 
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
		
		local phi = (settings.ints[1])*(math.pi/180)
		local theta = (90-settings.ints[2])*(math.pi/180)
		local radius = settings.ints[3]*1000
		local yc = math.floor(radius * math.sin(theta) * math.cos(phi))
		local xc = math.floor(radius * math.sin(theta) * math.sin(phi))
		local zc = math.floor(radius * math.cos(theta))
		--print(xc)
		--print(yc)
		--print(zc)
		proj.speed_x=xc
		proj.speed_y=-yc
		proj.speed_z=zc
		
		unitoccupancy = dfhack.maps.getTileBlock(unitTarget.pos).occupancy[unitTarget.pos.x%16][unitTarget.pos.y%16]
		if not unitTarget.flags1.on_ground then 
				unitoccupancy.unit = false 
		else 
				unitoccupancy.unit_grounded = false 
		end
		unitTarget.flags1.projectile=true
		unitTarget.flags1.on_ground=false
	end
end

function callCaravan(reaction,unit,job,input_items,input_reagents,output_items,call_native)
	alreadyComing = false
	entity = df.global.world.entities.all[df.global.ui.civ_id]
	for i=0, #df.global.timed_events-1, 1 do
		event = df.global.timed_events[i]
		if event.type == 0 and event.entity.id == entity.id then
			dfhack.gui.showAnnouncement( "A caravan is already on its way!", COLOR_RED, true)
			alreadyComing = true
			break
		end
	end
	if alreadyComing == false then
		if df.global.cur_season == 3 then season = 0 else
		season = df.global.cur_season + 1 end
		season_ticks = df.global.cur_season_tick
		if(df.global.timed_events:insert('#', { new = df.timed_event, type = 0, season = season, season_ticks = season_ticks, entity = entity } )) then
			dfhack.gui.showAnnouncement( "A caravan has departed for your settlement.  It should arrive next season.", COLOR_WHITE, true)
		else
			dfhack.gui.showAnnouncement( "You sent out a message, but there was no response...", COLOR_RED, true)
		end
	end
end

function catapultFireUnit(reaction,unit,job,input_items,input_reagents,output_items,call_native)
	local building = dfhack.buildings.findAtTile(unit.pos)
	local settings = getMachinaByBuildingId(building.id).settings
	if settings.ints[1] ~= -1 then	
		catapultFlingUnit(unit,settings)
	end
end

function catapultFireItem(reaction,unit,job,input_items,input_reagents,output_items,call_native)
	item = job[0]
	local building = dfhack.buildings.findAtTile(unit.pos)
	local settings = getMachinaByBuildingId(building.id).settings
	if settings.ints[1] ~= -1 then
		catapultFlingItem(item,settings)
	end
end

function catapultAutoFire(machina, power)
	local building = machina.building
	local settings = machina.settings
	
	local inputBlocks = machina.inputBlocks
	local outputBlocks = machina.outputBlocks
	local mainOutputBlocks = machina.mainOutputBlocks
	local secondaryOutputBlocks = machina.secondaryOutputBlocks
	
	if settings.ints[1] ~= -1 then
		if settings.ints[7] < 0 then
			settings.ints[7] = 10000
			local pos = {}
			pos.x = building.centerx
			pos.y = building.centery
			pos.z = building.z
			block = dfhack.maps.ensureTileBlock(pos.x,pos.y,pos.z)
			
			gotItem = false
			for b = 1, #inputBlocks, 1 do
				cpos = inputBlocks[b]
				block = dfhack.maps.ensureTileBlock(cpos.x,cpos.y,cpos.z)
				if block.occupancy[cpos.x%16][cpos.y%16].item == true then
					for i=#block.items-1,0,-1 do
						item=df.item.find(block.items[i])
						ipos=item.pos
						if ipos.x == cpos.x and ipos.y == cpos.y and ipos.z == cpos.z and item.flags.on_ground == true then
							item.flags.forbid = true
							dfhack.items.moveToGround(item,pos)
							
							catapultFlingItem(item,settings)
							gotItem = true
							break
						end
					end
				end
				if gotItem == false then
					--Try to get a creature
					if block.occupancy[cpos.x%16][cpos.y%16].unit == true or block.occupancy[cpos.x%16][cpos.y%16].unit_grounded == true then
						allUnits = df.global.world.units.active
						for i=#allUnits-1,0,-1 do	-- search list in reverse
							u = allUnits[i]
							if u.pos.x == cpos.x and u.pos.y == cpos.y and u.pos.z == cpos.z and u.flags1.dead == false and u.flags3.ghostly == false then
								u.pos.x = building.centerx
								u.pos.y = building.centery
								u.pos.z = building.z
								catapultFlingUnit(u,settings)
								break
							end
						end
					end
				end
			end
			factoryFlicker(building)
		else
			settings.ints[7] = settings.ints[7] - power
		end
	end
end

--Mist Generator

function generateMist(machina, power)
	local building = machina.building
	local settings = machina.settings
	if settings.ints[7] < 0 then
		settings.ints[7] = 10000
		local pos = {}
		pos.x = building.centerx
		pos.y = building.centery
		pos.z = building.z
		flowSize = 50
		baseBlock = dfhack.maps.ensureTileBlock(pos.x,pos.y,pos.z)
		liquidBlock = dfhack.maps.ensureTileBlock(pos.x,pos.y,pos.z-1)
		if liquidBlock.designation[pos.x%16][pos.y%16].flow_size > 1 then
			liquidBlock.designation[pos.x%16][pos.y%16].flow_size = liquidBlock.designation[pos.x%16][pos.y%16].flow_size - 1
			if liquidBlock.designation[pos.x%16][pos.y%16].liquid_type == true then
				dfhack.maps.spawnFlow(pos,4,0,0,flowSize) -- lava mist
			else
				dfhack.maps.spawnFlow(pos,2,0,0,flowSize) -- mist
			end
			
		end
	else
		settings.ints[7] = settings.ints[7] - power
	end
end

--Thunder Coil

teslaMat = -1

local function findInorganicWithName(matString)
	for inorganicID,material in ipairs(df.global.world.raws.inorganics) do
		if material.id == matString then return inorganicID end
	end
	return nil
end

function teslaCoil(machina, power)
	local building = machina.building
	local settings = machina.settings
	if settings.ints[7] < 0 then
		settings.ints[7] = 1000
		local pos = {}
		pos.x = building.centerx
		pos.y = building.centery
		pos.z = building.z
		
		local block = dfhack.maps.getTileBlock(pos.x,pos.y,pos.z)
		local theta = math.rad(math.random(360))
		local phi = math.rad(math.random(360))
		local radius = math.random(math.sqrt(power)) -- More power to the same machine decreases its efficiency, encouraging spreading machinery out more
		local xc = math.floor(radius * math.sin(theta) * math.cos(phi))
		local yc = math.floor(radius * math.sin(theta) * math.sin(phi))
		local zc = math.floor(radius * math.cos(theta))
		local xt = pos.x+xc
		local yt = pos.y+yc
		local zt = pos.z+0--zc
		block_target = nil
		block_target = dfhack.maps.ensureTileBlock(xt,yt,zt)
		if block_target then
			if teslaMat == -1 or teslaMat == nil then
				teslaMat = findInorganicWithName('TESLA_COIL')
			end
			flowSize = 50
			target = {}
			target.x = xt
			target.y = yt
			target.z = zt
			--dfhack.maps.spawnFlow(target,9,0,teslaMat,flowSize)
			dfhack.maps.spawnFlow(target,6,0,-1,10)
		end
		if math.random(20) == 1 then makeNoise(building,power/10) end
	else
		if power > 100 then
			settings.ints[7] = settings.ints[7] - power
		end
	end
end
--Animatronic Statue

--Druidic Device

function attractCreatures(machina, power)
	local building = machina.building
	local settings = machina.settings
	if settings.ints[7] < 0 then
		settings.ints[7] = 10000
		local pos = {}
		pos.x = building.centerx
		pos.y = building.centery
		pos.z = building.z
		allUnits = df.global.world.units.other.ANY_ANIMAL
		local u = allUnits[math.random(#allUnits-1)]
		unitRaw = df.global.world.raws.creatures.all[u.race]
		casteRaw = unitRaw.caste[u.caste]
		if u.flags2.roaming_wilderness_population_source
		and u.path.dest ~= pos
		and u.relations.following == nil
		and u.civ_id==-1
		and unitRaw.flags.LARGE_ROAMING
		and casteRaw.flags.NATURAL 
		and u.animal.leave_countdown > 0 then
			found = true
			petValue = casteRaw.misc.petvalue
			--if math.random(100) < (1/petValue)*power then
				u.path.dest = pos
			--end
		end
		factoryFlicker(building)
	else
		settings.ints[7] = settings.ints[7] - power
	end
end

--Infrasonic Organ

--Geologic Seismograph

function scanArea(machina, power)
	local building = machina.building
	local settings = machina.settings
	local powerValue = power
	if settings.ints[7] < 0 then
		settings.ints[7] = 10000
		local pos = {}
		pos.x = building.centerx
		pos.y = building.centery
		pos.z = building.z
		local x = 0
		local y = 0
		local z = 0
		local block = dfhack.maps.getTileBlock(pos.x,pos.y,pos.z)
		local theta = math.rad(math.random(360))
		local phi = math.rad(math.random(360))
		local radius = math.random(math.sqrt(powerValue)) -- More power to the same machine decreases its efficiency, encouraging spreading machinery out more
		local xc = math.floor(radius * math.sin(theta) * math.cos(phi))
		local yc = math.floor(radius * math.sin(theta) * math.sin(phi))
		local zc = math.floor(radius * math.cos(theta))
		local xt = pos.x+xc
		local yt = pos.y+yc
		local zt = pos.z+(zc/1) -- Divide by 2 to make the depths less easily penetrated
		block_target = nil
		block_target = dfhack.maps.ensureTileBlock(xt,yt,zt)
		if block_target then
			tiletype = block_target.tiletype[xt%16][yt%16]
			if tiletype == 219 or tiletype == 440 or tiletype == 265 then
				block_target.designation[xt%16][yt%16].hidden = false
			end
		end
		factoryFlicker(building)
		makeNoise(building,radius/2)
	else
		settings.ints[7] = settings.ints[7] - power
	end
end


--Drilling Rig

function drillDown(reaction,unit,job,input_items,input_reagents,output_items,call_native)
	pos = {}
	pos.x = unit.pos.x
	pos.y = unit.pos.y
	pos.z = unit.pos.z
	baseBlock = dfhack.maps.ensureTileBlock(pos.x,pos.y,pos.z)
	for depth=pos.z-1,0,-1 do
		local block = dfhack.maps.ensureTileBlock(pos.x,pos.y,depth)
		if block then
			if block.tiletype[pos.x%16][pos.y%16] ~= 495 then
				block.tiletype[pos.x%16][pos.y%16] = 495
				block.designation[pos.x%16][pos.y%16].hidden = false
				block.designation[(pos.x)%16][(pos.y-1)%16].hidden = false
				block.designation[(pos.x+1)%16][(pos.y-1)%16].hidden = false
				block.designation[(pos.x+1)%16][(pos.y)%16].hidden = false
				block.designation[(pos.x+1)%16][(pos.y+1)%16].hidden = false
				block.designation[(pos.x)%16][(pos.y+1)%16].hidden = false
				block.designation[(pos.x-1)%16][(pos.y+1)%16].hidden = false
				block.designation[(pos.x-1)%16][(pos.y)%16].hidden = false
				block.designation[(pos.x-1)%16][(pos.y-1)%16].hidden = false
				block.designation[pos.x%16][pos.y%16].flow_size = 0
				destroy_build = dfhack.buildings.findAtTile({x=pos.x,y=pos.y,z=depth})
				if destroy_build ~= nil then
					--
				end
				onebelow = dfhack.maps.ensureTileBlock(pos.x,pos.y,depth-1)
				if onebelow.designation[pos.x%16][pos.y%16].flow_size > 0 then
					if onebelow.designation[pos.x%16][pos.y%16].liquid_type == true then
						dfhack.gui.showAnnouncement( "The drill has encountered magma!", COLOR_RED, true)
					else
						dfhack.gui.showAnnouncement( "The drill has encountered water!", COLOR_BLUE, true)
					end
				end
				break
			end
		end
	end
	makeNoise(building,8)
end

function drillUp(reaction,unit,job,input_items,input_reagents,output_items,call_native)
	pos = {}
	pos.x = unit.pos.x
	pos.y = unit.pos.y
	pos.z = unit.pos.z
	baseBlock = dfhack.maps.ensureTileBlock(pos.x,pos.y,pos.z)
	if (dfhack.maps.ensureTileBlock(pos.x,pos.y,pos.z-1)).tiletype[pos.x%16][pos.y%16] ~= 495 then
		dfhack.gui.showAnnouncement( dfhack.TranslateName(unit.name).." cannot retract the drill any further.", COLOR_RED, true)
		reaction.products[0].probability = 0
	else
		for depth=pos.z-1,0,-1 do
			local block = dfhack.maps.ensureTileBlock(pos.x,pos.y,depth)
			if block then
				if block.tiletype[pos.x%16][pos.y%16] ~= 495 then
					drillBit = dfhack.maps.ensureTileBlock(pos.x,pos.y,depth+1)
					if block.tiletype[pos.x%16][pos.y%16] == 440 then -- solid regular rock below
						drillBit.tiletype[pos.x%16][pos.y%16] = 237 -- regular rock upward slope
					elseif block.tiletype[pos.x%16][pos.y%16] == 219 then -- solid event rock below
						drillBit.tiletype[pos.x%16][pos.y%16] = 240 -- event rock upward slope
					elseif block.tiletype[pos.x%16][pos.y%16] == 237 or block.tiletype[pos.x%16][pos.y%16] == 240 then -- upward slope below
						drillBit.tiletype[pos.x%16][pos.y%16] = 1 -- downward slope
					else
						drillBit.tiletype[pos.x%16][pos.y%16] = 32 -- open space
					end
					dfhack.maps.enableBlockUpdates(drillBit,true,true)
					break
				end
			end
		end
	end
	makeNoise(building,4)
end

function drillPump(machina, machinePower, manualPower)
	local building = machina.building
	local settings = machina.settings
	if manualPower == nil then manualPower = 0 end
	local pos = {}
	pos.x = building.centerx
	pos.y = building.centery
	pos.z = building.z
	local baseBlock = dfhack.maps.ensureTileBlock(pos.x,pos.y,pos.z)
	local underBaseBlock = dfhack.maps.ensureTileBlock(pos.x,pos.y,pos.z-1)
	local overflowing = false
	if settings.ints[7] > 100 then
		settings.ints[7] = 1
	else
		settings.ints[7] = settings.ints[7] + 1
	end
	local randomfactor = settings.ints[7] -- not actually random anymore
	local effectiveMachinePower = machinePower/randomfactor
	if underBaseBlock.designation[pos.x%16][pos.y%16].flow_size == 7 then
		overflowing = true
		manualPower = 0 -- makes sure you don't overflow due to manual power
	end
	effectivePower = effectiveMachinePower + manualPower
	for depth=pos.z-1,0,-1 do
		local block = dfhack.maps.ensureTileBlock(pos.x,pos.y,depth)
		--Check to make sure there's enough power
		if pos.z-depth < effectivePower/10 then
			if block then
				if block.tiletype[pos.x%16][pos.y%16] ~= 495 then
					--Reached the bottom
					settings.ints[7] = 1
					drillBit = dfhack.maps.ensureTileBlock(pos.x,pos.y,depth)
					gotItem = false
					--Try and suck up items
					local outputBlocks = machina.outputBlocks
					local mainOutputBlocks = machina.mainOutputBlocks
					local secondaryOutputBlocks = machina.secondaryOutputBlocks
					if #mainOutputBlocks ~= 0 then
						cpos = pos
						block = dfhack.maps.ensureTileBlock(cpos.x,cpos.y,depth)
						if drillBit.occupancy[pos.x%16][pos.y%16].item == true then
							for i=#drillBit.items-1,0,-1 do
								item=df.item.find(drillBit.items[i])
								if item then
									ipos=item.pos
									if ipos.x == pos.x and ipos.y == pos.y and ipos.z == depth and item.flags.on_ground == true then
										opos = outputBlocks[math.random(#outputBlocks)]
										ejectItem(building,item,{x=opos.x,y=opos.y,z=opos.z})
										gotItem = true
										break
									end
								end
							end
						end
					end
					if gotItem == false then
						--Try to get a creature
						if block.occupancy[pos.x%16][pos.y%16].unit == true or block.occupancy[pos.x%16][pos.y%16].unit_grounded == true then
							allUnits = df.global.world.units.active
							for i=#allUnits-1,0,-1 do	-- search list in reverse
								u = allUnits[i]
								if u.pos.x == cpos.x and u.pos.y == cpos.y and u.pos.z == depth and u.flags1.dead == false and u.flags3.ghostly == false then
									if dfhack.units.isDwarf(u) then
										dfhack.gui.showAnnouncement( dfhack.TranslateName(u.name).." has been caught in a machine!" , COLOR_MAGENTA, true)
									end
									ripPart(u)
									u.pos.x = pos.x
									u.pos.y = pos.y
									u.pos.z = pos.z
									break
								end
							end
						end
					end
					
					
					if drillBit.designation[pos.x%16][pos.y%16].flow_size > 3 then
						if overflowing == true then
							drillBit.designation[pos.x%16][pos.y%16].flow_size = drillBit.designation[pos.x%16][pos.y%16].flow_size - 1
							baseBlock.designation[pos.x%16][pos.y%16].flow_size = baseBlock.designation[pos.x%16][pos.y%16].flow_size + 1
							baseBlock.designation[pos.x%16][pos.y%16].liquid_type = drillBit.designation[pos.x%16][pos.y%16].liquid_type
						else
							drillBit.designation[pos.x%16][pos.y%16].flow_size = drillBit.designation[pos.x%16][pos.y%16].flow_size - 1
							underBaseBlock.designation[pos.x%16][pos.y%16].flow_size = underBaseBlock.designation[pos.x%16][pos.y%16].flow_size + 1
							underBaseBlock.designation[pos.x%16][pos.y%16].liquid_type = drillBit.designation[pos.x%16][pos.y%16].liquid_type
						end
						dfhack.maps.enableBlockUpdates(drillBit,true,true)
						dfhack.maps.enableBlockUpdates(baseBlock,true,true)
						dfhack.maps.enableBlockUpdates(underBaseBlock,true,true)
						return "ok"
					else
						return "no_liquid"
					end
					
					break
				end
			end
		else
			return "power_insufficient"
		end
	end
	makeNoise(building,machinePower/100)
end

function levelUp(unit, skillId, amount)
	max_skill = 20 
	
	local skill = df.unit_skill:new()
	local foundSkill = false
	
	for k, soulSkill in ipairs(unit.status.current_soul.skills) do
		if soulSkill.id == skillId then
			skill = soulSkill
			foundSkill = true
			break
		end
	end
 
	if foundSkill then
		-- Let's not train beyond the max skill
		if skill.rating >= max_skill then
			return false
		end
 
		skill.experience = skill.experience + amount
		if skill.experience > 100 * skill.rating + 500 then
			skill.experience = skill.experience - (100 * skill.rating + 500)
			skill.rating = skill.rating + 1
		end
	else
		skill.id = skillId
		skill.experience = amount
		skill.rating = 0
		unit.status.current_soul.skills:insert('#',skill)
	end
end

function getUnitSkill(skillId, unit)
	local skill = df.unit_skill:new()
	local foundSkill = false
 
	for k, soulSkill in ipairs(unit.status.current_soul.skills) do
		if soulSkill.id == skillId then
			skill = soulSkill
			foundSkill = true
			break
		end
	end
 
	return skill
end

function drillPumpManual(reaction,unit,job,input_items,input_reagents,output_items,call_native)
	local building = dfhack.buildings.findAtTile(unit.pos)
	local machina = getMachinaByBuildingId(building.id)
	local skill_id = 70 -- Pump operating
	local skillLevel = (getUnitSkill(skill_id, unit)).rating + 1
	machinePower = 0
	for i=1,#machinas,1 do
		machina = machinas[i]
		if machina ~= nil then
			if machina.building_id == building.id then
				machinePower = machina.cur_power
				break
			end
		end
	end
	manualPower = (skillLevel*10)
	result = drillPump(machina, machinePower, manualPower)
	if result == "no_liquid" then
		dfhack.gui.showAnnouncement( dfhack.TranslateName(unit.name).." was unable to bring up any liquids - no liquid.", COLOR_RED, true)
		--job.job_flags.item_lost = true -- Cancels the job if on repeat
	elseif result == "power_insufficient" then
		--job.job_flags.item_lost = true -- Cancels the job if on repeat
		levelUp(unit,skill_id,1)
	elseif result == "ok" then
		levelUp(unit,skill_id,1)
	end
end

--Factory

itemSizes = {
	{"bar",600,3},
	{"smallgem",20,0.3},
	{"blocks",600,4},
	{"rough",250,0.3},
	{"boulder",10000,16},
	{"wood",5000,8},
	{"door",3000,9},
	{"floodgate",3000,9},
	{"bed",3000,9},
	{"chair",3000,9},
	{"chain",500,4},
	{"flask",100,0.3},
	{"goblet",100,0.3},
	{"instrument",400,1},
	{"toy",100,1},
	{"window",2000},
	{"cage",3000,6},
	{"barrel",2000,9},
	{"bucket",300,1},
	{"animaltrap",300,3},
	{"table",3000,9},
	{"coffin",3000,9},
	{"statue",6000,9},
	{"corpse",1,1},
	{"weapon",-1,-1},
	{"armor",-1,-1},
	{"shoes",-1,-1},
	{"shield",-1,-1},
	{"helm",-1,-1},
	{"gloves",-1,-1},
	{"box",3000,9},--3000 for box, 100 for bag
	{"bin",3000,9},
	{"armorstand",1000,9},
	{"weaponrack",1000,9},
	{"cabinet",3000,9},
	{"figurine",100,0.3},
	{"amulet",50,0.3},
	{"scepter",300,0.3},
	{"ammo",1,0.04},
	{"crown",100,0.3},
	{"ring",5,0.3},
	{"earring",3,0.3},
	{"bracelet",20,0.3},
	{"gem",5,0.3}, -- What?  A large gem is smaller than a small gem?
	{"anvil",1000,9},
	{"corpsepiece",1,1},--var
	{"remains",1,1},--var
	{"meat",200,1},
	{"fish",1,1},--var
	{"fish_raw",1,1},--var
	{"vermin",1,1},--var
	{"pet",1,1},--var
	{"seeds",10,0.1},
	{"plant",100,0.3},
	{"skin_tanned",500,1},
	{"leaves",5,0.1},
	{"thread",30,1},--?
	{"cloth",20,1},--??
	{"totem",500,0.3},
	{"pants",-1,-1},
	{"backpack",500,1},
	{"quiver",300,1},
	{"catapultparts",2000,4},
	{"ballistaparts",2000,4},
	{"siegeammo",3000,9},
	{"ballistaarrowhead",1000,3},
	{"trapparts",2000,3},
	{"trapcomp",2000,3},
	{"drink",200,1},
	{"powder_misc",200,1},
	{"cheese",100,1},
	{"food",500,1},
	{"liquid_misc",60,1},
	{"coin",1,0.05}, -- Not actually sure
	{"glob",60,1},
	{"rock",200,1},
	{"pipe_section",3000,9},
	{"hatch_cover",1000,9},
	{"grate",1000,9},
	{"quern",3000,9},
	{"millstone",3000,9},
	{"splint",200,2},
	{"crutch",200,3},
	{"traction_bench",3000,9},
	{"orthopedic_cast",200,1},
	{"tool",-1,-1},--var
	{"slab",6000,9},
	{"egg",1,1},--var
	{"book",100,0},
}

function getRawStringItem(item)
    local type=item:getType()
    local attrs=df.item_type.attrs[type]
    if not attrs.is_rawable then return df.item_type[type]..":NO_SUBTYPE" end
    local subtype=item:getSubtype()
    return df.item_type[type]..":"..df['itemdef_'..df.item_type.attrs[type].caption..'st'].find(subtype).id
end

function damageFactory(building,damage)
	if math.random(100)<damage then
		cic = 0
		for i = 0, #building.contained_items-1, 1 do
			if building.contained_items[i].use_mode == 2 then
				cic = cic + 1
			end
		end
		i = math.random(cic)-1
		item = building.contained_items[i].item
		item.setWear(item,item.getWear(item)+1)
		if item.wear > 3 then
			destroyItemInBuilding(item,building)
		end
		makeNoise(building,damage)
	end
end

function getFactorySkill(machina)
	building = machina.building
	totalQuality = 0
	totalWear = 0
	partNumber = 0
	for i = 0, #building.contained_items - 1, 1 do
		ic = building.contained_items[i].item
		if ic:getType() == 66 or ic:getType() == 67 then -- only take mechanisms and trap components into account
			partNumber = partNumber + 1
			totalQuality = totalQuality + ic.quality
			totalWear = totalWear + ic.getWear(ic)
		end
	end
	if partNumber > 0 then
		averageQuality = math.floor(totalQuality / partNumber)
		averageWear = math.ceil(totalWear / partNumber)
		return {quality=averageQuality,wear=averageWear}
	else return {quality=0,wear=0}
	end
end

function setProductStatus(item,factorySkill,valid)
	quality = 0
	wear = 0
	if math.random(5) < factorySkill.quality then quality = quality + 1 end
	if math.random(10) < factorySkill.quality then quality = quality + 1 end
	if math.random(15) < factorySkill.quality then quality = quality + 1 end
	if math.random(20) < factorySkill.quality then quality = quality + 1 end
	if math.random(25) < factorySkill.quality and math.random(3) == 1 then quality = quality + 1 end
	item:setQuality(quality)
	if 1 < factorySkill.wear then wear = wear + 1 end
	if math.random(2) < factorySkill.wear then wear = wear + 1 end
	if math.random(3) < factorySkill.wear then wear = wear + 1 end
	if math.random(4) < factorySkill.wear then wear = wear + 1 end
	if math.random(5) < factorySkill.wear then wear = wear + 1 end
	item.setWear(item,wear)	
	if item.wear > 3 then
		destroyItemInBuilding(item,building)
	end
	
end
--[[
        (autostonecutter) boulders > blocks, other > no change (damage)
        (autowoodcutter) logs > blocks, other > no change (damage)
        (autosmelter) ore > bars, bars > no change, stone > slag, other > ash
        (autoforge) metal > items, stone > no change (damage), other > ash
        (autocrafter) blocks > items, bars > no change (damage), other > items (damage)
		
				smelter - Ore>Bars, Rock>Rock, Bars>Bars Organic>Ash
				forge - Bars>Items, Rock>Rock, Organic>Ash
				rock mill - Rock>Blocks, Large Items>Blocks, Small Items>Unchanged, Metal>Unchanged
				lumber mill - Wood>Blocks, Large Items>Blocks, Small Items>Unchanged, Metal>Unchanged
				assembler - Blocks>Items, Hard Mat>Items, Others>Unchanged or Decorations
				loom - Thread > Cloth, Others>Unchanged
				tailor - Cloth or Leather > Items, Soft Mat>Items, Others>Unchanged
				grinder - All Items > Powder
				gemcutter - Gems>Cut Gems, Rock>Cut Gems, Others>Unchanged
				decorator - Powder, Cut Gems, Bone/Horn/Tooth/Shell > Decoration, others>Decorated or Unchanged
				sorter (wood, stone, metal, blocks, bone, hard, soft, bags, thread, leather)
				chef - All Items > Meals
				cart loader
		
		not playing anything	
	   a slow, calming melody
	   a mild, swinging rhythm
	   a natural, easy tempo
	   a quick, energetic beat
	   a wild, invigorating tune
	   playing way too fast
]]--

function setForbiddenStatus(item)
	if item ~= nil then
		building = dfhack.buildings.findAtTile(item.pos)
		if building ~= nil then
			code=isMachina(building)
			if code ~= nil then
				if string.starts(code, prefix..'INPUT') or string.starts(code, prefix..'LOADER') then
				item.flags.forbid = true
				else
					item.flags.forbid = false
				end
			end
		else
			item.flags.forbid = false
		end
	end
end

function factoryFlicker(building)
	pos = {x=building.centerx,y=building.centery,z=building.z}
	dfhack.maps.spawnFlow(pos,1,0,0,5) -- mist
end




function loaderOperate(machina, power)
	local building = machina.building
	local settings = machina.settings
	if settings.ints[7] < 0 then
		settings.ints[7] = 10000
		inputBlock = dfhack.maps.ensureTileBlock(building.centerx,building.centery,building.z)
		if inputBlock.occupancy[building.centerx%16][building.centery%16].item == true or 
			inputBlock.occupancy[building.centerx%16][building.centery%16].unit == true or 
			inputBlock.occupancy[building.centerx%16][building.centery%16].unit_grounded == true then
			
			local outputBlocks = machina.outputBlocks
			for b=1, #outputBlocks, 1 do
				cpos = outputBlocks[b]
				block = dfhack.maps.ensureTileBlock(cpos.x,cpos.y,cpos.z)
				if block.occupancy[cpos.x%16][cpos.y%16].item == true then
					for c=#block.items-1,0,-1 do
						cart=df.item.find(block.items[c])
						if cart:isTrackCart() then
							if inputBlock.occupancy[building.centerx%16][building.centery%16].item == true then
								for i=#inputBlock.items-1,0,-1 do
									item=df.item.find(inputBlock.items[i])
									ipos=item.pos
									if ipos.x == building.centerx and ipos.y == building.centery and ipos.z == building.z and item.flags.on_ground == true then
										cart_capacity = cart.subtype.container_capacity
										totalvolume = 0
										cartrefs=cart.general_refs
										for r=0,#cartrefs-1,1 do
											if getmetatable(cartrefs[r])=="general_ref_contains_itemst" then
												containeditem = df.item.find(cartrefs[r].item_id)
												totalvolume = totalvolume + containeditem:getVolume()
											end
										end
										if totalvolume + item:getVolume() <= cart_capacity then
											dfhack.items.moveToContainer(item,cart)
											gotItem = true
											break
										end
									end
								end
							elseif cart.flags2.has_rider == false and (inputBlock.occupancy[building.centerx%16][building.centery%16].unit == true or inputBlock.occupancy[building.centerx%16][building.centery%16].unit_grounded == true) then
								allUnits = df.global.world.units.active
								for i=#allUnits-1,0,-1 do	-- search list in reverse
									u = allUnits[i]
									if u.pos.x == building.centerx and u.pos.y == building.centery and u.pos.z == building.z and u.flags1.dead == false and u.flags3.ghostly == false then
										
										--Stun the unit
										u.counters.unconscious = 250
										
										--toss the unit into the minecart!
										u.pos.x = cart.pos.x
										u.pos.y = cart.pos.y
										u.pos.z = cart.pos.z
										u.riding_item_id = cart.id
										--u.flags3.exit_vehicle1 = true
										cart.flags2.has_rider = true
										cartref = df.general_ref_unit_riderst:new()
										cartref.unit_id = u.id
										
										duplicate = false
										cartrefs=cart.general_refs
										for r=0,#cartrefs-1,1 do
											if getmetatable(cartrefs[r])=="general_ref_unit_riderst" then
												if cartrefs[r].unit_id == u.id then 
													duplicate = true
													break
												end
											end
										end
										if duplicate == false then
											cart.general_refs:insert('#',cartref)
											break
										end
									end
								end
							end
							factoryFlicker(building)
						end
					end
				end
			end
		end	
	else
		settings.ints[7] = settings.ints[7] - power
	end
end

function destroyItemInBuilding(item,building)
--Remove items from containers
	for r = #item.general_refs - 1, 0, -1 do
		if getmetatable(item.general_refs[r]) == 'general_ref_contains_itemst' then
			contained_item = df.item.find(item.general_refs[r].item_id)
			for r2 = #contained_item.general_refs-1, 0, -1 do
				if getmetatable(contained_item.general_refs[r2]) == 'general_ref_contained_in_itemst' then
					contained_item.general_refs:erase(r2)
					contained_item.flags.in_inventory = false
				end
			end
			contained_item:moveToGround(item.pos.x,item.pos.y,item.pos.z)
			item.general_refs:erase(r)
			dfhack.items.moveToBuilding(contained_item,building,0)
		elseif
			getmetatable(item.general_refs[r]) == 'general_ref_contains_unitst' then
			contained_unit = df.unit.find(item.general_refs[r].unit_id)
			for r2 = #contained_unit.general_refs-1, 0, -1 do
				if getmetatable(contained_unit.general_refs[r2]) == 'general_ref_contained_in_itemst' then
					contained_unit.general_refs:erase(r2)
					contained_unit.flags1.caged = false
				end
			end
			item.general_refs:erase(r)
			contained_unit.pos.x = item.pos.x
			contained_unit.pos.y = item.pos.y
			contained_unit.pos.z = item.pos.z
			contained_unit.flags3.scuttle = true
		end
	end
	item.flags.removed = true
	item.flags.garbage_collect = true
	item:uncategorize()
end

function factoryOperate(machina, power)
	local building = machina.building
	local settings = machina.settings
	
	local factory_type = machina.factory_type
	local inputBlocks = machina.inputBlocks
	local outputBlocks = machina.outputBlocks
	local mainOutputBlocks = machina.mainOutputBlocks
	local secondaryOutputBlocks = machina.secondaryOutputBlocks
	
	if true then -- placeholder
		if settings.ints[7] < 0 then -- cooldown
			settings.ints[7] = 10000
			
			--inputBlocks and outputBlocks should now have the location of all connected inputs and outputs.
			if #inputBlocks == 0 or #outputBlocks == 0 then
				--No input/output: do nothing
			else
				--First get the product
				product_type = settings.ints[1]
				product_subtype = settings.ints[2]
				if factory_type == "WOODCUTTER" or factory_type == "STONECUTTER" or factory_type == "BONECUTTER" then
					product_type = 2 -- blocks (may be changed to include more options in the future)
				elseif factory_type == "JEWELER" then
					if math.random(10) == 1 then product_type = 43 else product_type = 1 end -- large or small gems (may need more specifics in the future)
				elseif factory_type == "GRINDER" then
					product_type = 69 -- powder_misc
				elseif factory_type == "FOOD" then
					product_type = 71 -- food
				elseif factory_type == "BUTCHER" then
					product_type = 47 -- meat
				elseif factory_type == "SMELTER" then
					product_type = 0 -- bars
				end
				
				local did_special = false
				--Special reactions.  This only works properly with completely defined reagents and products i.e. Masterwork smelting.  Still needs improvement for proper rawability.
				if #building.contained_items > 0 then
					for r_id,reaction in ipairs(factory_reactions) do
						local building_ok = false
						local items_ok = false
						building_def = df.building_def.find(building.custom_type)
						for r=0, #reaction.building.type-1, 1 do
							if reaction.building.custom[r] == building_def.id then
								building_ok = true
								break
							end
						end
						if building_ok == true then
							items_ok = true
							items_used = {}
							for r=0, #reaction.reagents-1, 1 do
								local item_ok = false
								for i = 0, #building.contained_items-1, 1 do
									if building.contained_items[i].use_mode == 0 then
										local passItem = false
										local damagelevel = 0
										item = building.contained_items[i].item
										material = dfhack.matinfo.decode(item)
										if material ~= nil then
											local item_type = item:getType()
											local item_subtype = item:getSubtype()
											local item_size = item.getVolume(item)
											local matflags = material.material.flags
											
											if (reaction.reagents[r].item_type == item_type or reaction.reagents[r].item_type == -1)
											and (reaction.reagents[r].item_subtype == item_subtype or reaction.reagents[r].item_subtype == -1)
											and (reaction.reagents[r].mat_type == material.type or reaction.reagents[r].mat_type == -1)
											and (reaction.reagents[r].mat_index == material.index or reaction.reagents[r].mat_index == -1) then
												item_ok = true
												table.insert(items_used,item)
												break
											end
										end
									end
								end
								if item_ok == false then
									items_ok = false
								end
							end
						end
						if items_ok == true then
							for r=0, #reaction.products-1, 1 do
								prob = reaction.products[r].probability
								if math.random(100) <= prob then
									material = dfhack.matinfo.decode(reaction.products[r].mat_type,reaction.products[r].mat_index)
									opos = mainOutputBlocks[math.random(#mainOutputBlocks)]
									prob = reaction.products[r].probability
									if math.random(100) < prob then
										count = reaction.products[r].count
										dimension = reaction.products[r].product_dimension
										for c = 1, count, 1 do
											local product = createItem(material,{reaction.products[r].item_type,reaction.products[r].item_subtype},1,opos)
										end
									end
								end
							end
							for i_id,item in ipairs(items_used) do
								destroyItemInBuilding(item,building)
							end
							did_special = true
							break
						end
					end
				end
				
				if did_special == false then
					all_mats = {}
					
					if product_type ~= -1 and product_type ~= nil then
						
						hasInvalidMaterial = false
						
						product_name = df.item_type[product_type]:lower()
						product_size = itemSizes[product_type+1][2] -- size of the item
						product_mat_size = itemSizes[product_type+1][3]
						
						local fakeitem = nil
						if product_mat_size == -1 then
							fakeitem = df['item_'..product_name..'st']:new()
							fakeitem:setSubtype(product_subtype)
							product_mat_size = fakeitem.subtype.material_size
							product_size = fakeitem.getVolume(fakeitem)
						elseif product_mat_size == 0 then
							product_mat_size = 1
						end
						
						if product_type == 30 then
							--Determine if it's a box or bag here
						end
						--print("Attempting to produce "..product_name.." of size "..product_size)
						
					end
					
					--Then check each item in the building
					for i = 0, #building.contained_items-1, 1 do
						if i < #building.contained_items then
							if building.contained_items[i].use_mode == 0 then
					
								local passItem = false
								local damagelevel = 0
								item = building.contained_items[i].item
								
								material = dfhack.matinfo.decode(item)
								if material ~= nil then
									local valid = false
									local good = false
									local item_type = item:getType()
									local item_subtype = item:getSubtype()
									local item_size = item.getVolume(item)
									local matflags = material.material.flags
									local item_mat_size = itemSizes[item_type+1][3]
									if item_type == 0 then
										if matflags.IS_METAL then
											item_mat_size = item.dimension / 50
										else
											item_mat_size = 3
										end
									elseif item_mat_size == -1 then
										item_mat_size = item.subtype.material_size
									end
									--printall(matflags)
											
									wafers = false
									thread_metal = false
									if material.type == 0 then
										if material.inorganic.flags.WAFERS == true then wafers = true end
										if material.inorganic.flags.THREAD_METAL == true then thread_metal = true end
									end
									
									local matflags = dfhack.matinfo.decode(item).material.flags
									local itemname = df.item_type[item:getType()]:lower()
									local rots = false
									if matflags.ROTS and (itemname == 'corpsepiece' 
										or itemname == 'corpse'
										or itemname == 'remains') then
										rots = true
									end
									
									------------------------
									--Woodcutter/Stonecutter/Bonecutter (only makes blocks for now)
									------------------------
									if (factory_type == "WOODCUTTER" or factory_type == "STONECUTTER" or factory_type == "BONECUTTER") then
										if item_size > product_size then
											local make_products = false
											local valid = false
											if (factory_type == "WOODCUTTER" and matflags.WOOD == true)
											or (factory_type == "STONECUTTER" and matflags.IS_STONE == true)
											or (factory_type == "BONECUTTER" and (matflags.BONE == true or matflags.HORN == true or matflags.TOOTH == true or matflags.SHELL == true)) then
												if item_type == 5 or item_type == 4 or factory_type == "BONECUTTER" then
													good = true --Either a rock boulder in the stonecutter, a wooden log in the woodcutter, or any bone item in the bonecutter
												end
												make_products = true
											elseif matflags.IS_METAL == true then
												damagelevel = damagelevel+10
												passItem = true
											elseif matflags.ITEMS_HARD == false then -- soft items
												if rots == true then
													rot = item.rot_timer
													if rot ~= nil then
														item.rot_timer = rot + 100
														damagelevel = damagelevel+1
													end
												else
													damagelevel = damagelevel+1
													passItem = true
												end
											else -- hard items of the wrong type
												damagelevel = damagelevel+5
												make_products = true
												valid = true
											end
											if make_products == true then
												if good == false then
													 item_size = item_size/2
												end
												product_number = math.floor(item_size/product_size)
												for p=1,product_number,1 do
													opos = outputBlocks[math.random(#outputBlocks)]
													local product = createItem(material,{product_type,product_subtype},1,opos)
												end
												destroyItemInBuilding(item,building)
											end
										else
											passItem = true
										end
									end
									-----------
									--Furniture
									-----------
									if factory_type == "FURNITURE" then
										if matflags.IS_METAL == true and item_type ~= 2 then
											damagelevel = damagelevel+10
											passItem = true
										elseif matflags.ITEMS_HARD == true then -- for now, only hard materials can be used
											if item_type == 2 then
												good = true
											end
											valid = true
										elseif rots == true then
											damagelevel = damagelevel+1
											rot = item.rot_timer
											if rot ~= nil then
												item.rot_timer = rot + 100
											end
										else
											damagelevel = damagelevel+2
											passItem = true
										end
									end
									-----------
									--Clothier
									-----------
									if factory_type == "CLOTHIER" then
										if matflags.IS_METAL == true and thread_metal == false then
											damagelevel = damagelevel+10
											passItem = true
										elseif matflags.ITEMS_SOFT == true then
											good = true
											valid = true
										elseif matflags.ITEMS_HARD == true then
											damagelevel = damagelevel+5
											passItem = true
										elseif rots == true then
											damagelevel = damagelevel+1
											rot = item.rot_timer
											if rot ~= nil then
												item.rot_timer = rot + 100
											end
										else
											damagelevel = damagelevel+2
											passItem = true
										end
									end
									
									---------
									--Forge
									---------
									if factory_type == "FORGE" then
										if matflags.IS_METAL == true then
											if item_type == 0 then
												good = true
											end
											valid = true
										elseif matflags.IS_STONE == true then
											damagelevel = damagelevel+5
											passItem = true
										else -- Item is burned to ash
											product_mat = dfhack.matinfo.decode(9,0) -- ash
											opos = outputBlocks[math.random(#outputBlocks)]
											local product = createItem(product_mat,{product_type,product_subtype},1,opos)
											destroyItemInBuilding(item,building)
										end
									end
									
									---------
									--Smelter
									---------
									if factory_type == "SMELTER" then
										if matflags.IS_STONE == true then
											if item_type == 4 and #material.inorganic.metal_ore.mat_index > 0 then
												for ore=0, #material.inorganic.metal_ore.mat_index-1, 1 do
													ore_index = material.inorganic.metal_ore.mat_index[ore]
													ore_prob = material.inorganic.metal_ore.probability[ore]
													if math.random(100)<=ore_prob then
														product_number = 4
														for p=1,product_number,1 do
															product_mat = dfhack.matinfo.decode(0,ore_index)
															opos = outputBlocks[math.random(#outputBlocks)]
															local product = createItem(product_mat,{product_type,product_subtype},1,opos)
														end
													end
												end
												destroyItemInBuilding(item,building)
												good = true
											else
												passItem = true
											end
										elseif matflags.IS_METAL == true then -- Melt the item
											if item_mat_size == -1 then
												product_number = math.floor(item_size/(product_size/2))
											else
												if wafers == true then
													product_number = math.floor(item_mat_size)
												else
													product_number = math.floor(item_mat_size/3)
												end
												if product_number < 1 and item_mat_size >= 1 then
													product_number = 1
												end
											end
											for p=1,product_number,1 do
												opos = outputBlocks[math.random(#outputBlocks)]
												local product = createItem(material,{product_type,product_subtype},1,opos)
											end
											destroyItemInBuilding(item,building)
										else -- Item is burned to ash
											product_mat = dfhack.matinfo.decode(9,0) -- ash
											opos = outputBlocks[math.random(#outputBlocks)]
											local product = createItem(product_mat,{product_type,product_subtype},1,opos)
											destroyItemInBuilding(item,building)
										end
										
										
									end

									
									---------
									--Jeweler
									---------
									if factory_type == "JEWELER" then
									
										make_products = false
										if matflags.IS_STONE then
											if item_type == 3 then
												good = true
												valid = true
											elseif item_type == 4 then
												good = true
												valid = true
											end
											make_products = true
										elseif matflags.IS_METAL == true then
											damagelevel = damagelevel+10
											passItem = true
										else
											damagelevel = damagelevel+5
											passItem = true
										end
										if make_products == true then
											if good == false then
												 item_size = item_size/2
											end
											product_number = math.floor(item_size/product_size)
											for p=1,product_number,1 do
												opos = outputBlocks[math.random(#outputBlocks)]
												local product = createItem(material,{product_type,product_subtype},1,opos)
											end
											destroyItemInBuilding(item,building)
										end
									end
									
									---------
									--Grinder
									---------
									if factory_type == "GRINDER" then
										product_number = math.ceil((item_size/product_size)/100)
										millable = false
										if itemname == "plant" then
											if material.plant.material_defs.type_mill ~= 0 then
												millable = true
											end
										end
										if millable == true then
											mill_mat = dfhack.matinfo.decode(material.plant.material_defs.type_mill,material.plant.material_defs.idx_mill)
											for p=1,product_number,1 do
												opos = outputBlocks[math.random(#outputBlocks)]
												local product = createItem(mill_mat,{product_type,product_subtype},1,opos)
											end
											destroyItemInBuilding(item,building)
										elseif matflags.ITEMS_HARD == false and rots == true then -- soft items
											rot = item.rot_timer
											if rot ~= nil then
												item.rot_timer = rot + 100
												damagelevel = damagelevel+1
											end
										else
											for p=1,product_number,1 do
												opos = outputBlocks[math.random(#outputBlocks)]
												local product = createItem(material,{product_type,product_subtype},1,opos)
											end
											destroyItemInBuilding(item,building)
										end
									end
									
									-----------
									--Decorator
									-----------
									if factory_type == "IMPROVEMENTS" then
										local hold = false
										if 	itemname == "powder_misc" or
											itemname == "glob" or
											itemname == "bar" or
											itemname == "thread" or
											itemname == "cloth" or
											itemname == "skin_tanned" or
											((itemname == "corpsepiece" or itemname == "corpse" or itemname == "remains") and 
												(matflags.ITEMS_HARD or matflags.ITEMS_SOFT or matflags.BONE == true or matflags.HORN == true or matflags.TOOTH == true or matflags.SHELL == true))then
											if #building.contained_items < 30 then
												hold = true
											end
										else
											if true then --item:isImproved() == false then
												for imp = 0, #building.contained_items-1, 1 do
													if building.contained_items[imp].use_mode == 0 then
														imp_item = building.contained_items[imp].item
														imp_itemname = df.item_type[imp_item:getType()]:lower()
														local matflags = dfhack.matinfo.decode(imp_item).material.flags
														imp_mat = dfhack.matinfo.decode(imp_item)
														if 	imp_itemname == "powder_misc" or
															imp_itemname == "glob" or
															imp_itemname == "bar" or
															imp_itemname == "thread" or
															imp_itemname == "cloth" or
															imp_itemname == "skin_tanned" or
															((imp_itemname == "corpsepiece" or imp_itemname == "corpse" or imp_itemname == "remains") and 
																(matflags.ITEMS_HARD or matflags.ITEMS_SOFT or matflags.BONE == true or matflags.HORN == true or matflags.TOOTH == true or matflags.SHELL == true)) then
															if item:isImprovable(nil,imp_mat.type,imp_mat.index) then
																if matflags.IS_DYE == true then
																	for r = #item.improvements-1, 0, -1 do
																		if getmetatable(item.improvements[r]) == 'itemimprovement_threadst' then
																			item.improvements:erase(r)
																		end
																	end
																	improvement = df.itemimprovement_threadst:new()
																	i_mat = dfhack.matinfo.decode(item)
																	i_mat_type = i_mat.type
																	i_mat_index = i_mat.index
																	improvement.mat_type = i_mat_type
																	improvement.mat_index = i_mat_index
																	improvement.dye.mat_type = imp_mat.type
																	improvement.dye.mat_index = imp_mat.index
																else
																	improvement = df.itemimprovement_coveredst:new()
																	improvement.mat_type = imp_mat.type
																	improvement.mat_index = imp_mat.index
																end
																quality = 0
																if imp_mat.material.flags.ITEMS_HARD or imp_mat.material.flags.ITEMS_SOFT then
																	factorySkill = getFactorySkill(machina)
																	if math.random(5) < factorySkill.quality then quality = quality + 1 end
																	if math.random(10) < factorySkill.quality then quality = quality + 1 end
																	if math.random(15) < factorySkill.quality then quality = quality + 1 end
																	if math.random(20) < factorySkill.quality then quality = quality + 1 end
																	if math.random(25) < factorySkill.quality and math.random(3) == 1 then quality = quality + 1 end
																end
																improvement.quality = quality
																item.improvements:insert('#',improvement)
																
																destroyItemInBuilding(imp_item,building)
																break
															end
														end
													end
												end
											end
										end
										if hold == false then
											opos = outputBlocks[math.random(#outputBlocks)]
											ejectItem(building,item,{x=opos.x,y=opos.y,z=opos.z})
										end
										if #building.contained_items > 30 then
											for d = 0, #building.contained_items-1, 1 do
												if building.contained_items[d].use_mode == 0 then
													opos = outputBlocks[math.random(#outputBlocks)]
													ejectItem(building,item,{x=opos.x,y=opos.y,z=opos.z})
												end
											end
										end
									end
									
									---------
									--Butcher
									---------
									if factory_type == "BUTCHER" then
										for r = #item.general_refs-1, 0, -1 do
											if getmetatable(item.general_refs[r]) == 'general_ref_contains_unitst' then
												contained_unit = df.unit.find(item.general_refs[r].unit_id)
												for r2 = #contained_unit.general_refs-1, 0, -1 do
													if getmetatable(contained_unit.general_refs[r2]) == 'general_ref_contained_in_itemst' then
														contained_unit.general_refs:erase(r2)
														contained_unit.flags1.caged = false
													end
												end
												item.general_refs:erase(r)
												contained_unit.pos.x = item.pos.x
												contained_unit.pos.y = item.pos.y
												contained_unit.pos.z = item.pos.z
												contained_unit.flags3.scuttle = true
												for _, d in ipairs(df.global.world.deaths.all) do
													--printall(d)
													death_id=d.victim
													if contained_unit.id==death_id then
														d.death_cause = df.death_type.SLAUGHTER
													end
												end
											end
										end
										passItem = true;
									end

									---------
									--Sorter
									---------
									if factory_type == "SORTER" then
										match = true
										if settings.ints[1] ~= -1 then
											if item_type ~= settings.ints[1] then -- Need to get subtypes working
												match = false
											end
										end
										if settings.ints[3] ~= -1 then
											if material.type ~= settings.ints[3] or material.index ~= settings.ints[4] then
												match = false
											end
										end
										if match == true then
											if settings.ints[6] == -1 then
												opos = secondaryOutputBlocks[math.random(#secondaryOutputBlocks)]
											else
												opos = mainOutputBlocks[math.random(#mainOutputBlocks)]
											end
											ejectItem(building,item,{x=opos.x,y=opos.y,z=opos.z})
										else
											if settings.ints[6] == -1 then
												opos = mainOutputBlocks[math.random(#mainOutputBlocks)]
											else
												opos = secondaryOutputBlocks[math.random(#secondaryOutputBlocks)]
											end
											ejectItem(building,item,{x=opos.x,y=opos.y,z=opos.z})
										end
									end


									--End of factory types
									if good == true then valid = true end
									
									if valid == false then
										hasInvalidMaterial = true
									end
									
									if passItem == false and item.flags.removed == false and valid == true then -- Add the item to the material list
										if good == false then item_size = item_size/2 end -- split the item size in half if it is not the intended type
										duplicate_material = false
										for p = 1, #all_mats, 1 do
											this_mat = all_mats[p]
											if this_mat.material.type == material.type and this_mat.material.index == material.index then
												duplicate_material = true
												this_mat.size = this_mat.size + item_size
												this_mat.mat_size = this_mat.mat_size + item_mat_size
												break
											end
										end
										if duplicate_material == false then
											table.insert(all_mats,{material=material,size=item_size,mat_size=item_mat_size})
										end
									end
									--all_mats should now be an array of materials and sizes of all valid items remaining in the factory
									
								else --Error: Item has no material.  Eject the item unaltered.
									passItem = true
								end
								if passItem == true then -- pass the item outside unaltered
									opos = outputBlocks[math.random(#outputBlocks)]
									ejectItem(building,item,{x=opos.x,y=opos.y,z=opos.z})
								end
								if damagelevel > 0 then
									damageFactory(building,damagelevel)
								end
							end
						end
					end
					
					--If the factory combines items, now do the item combining thing
					if factory_type == "FURNITURE" or factory_type == "FORGE" or factory_type == "CLOTHIER" then
						total_size = 0
						main_mat_size = 0
						main_mat = nil
						if factory_type == "FURNITURE" or factory_type == "CLOTHIER" then
							if #all_mats > 0 then
								for i=1, #all_mats, 1 do
									total_size = total_size + all_mats[i].size
									if all_mats[i].size > main_mat_size then
										main_mat = all_mats[i].material
										main_mat_size = all_mats[i].size
									end
								end
							end
						elseif factory_type == "FORGE" then
							if #all_mats > 0 then
								for i=1, #all_mats, 1 do
									total_size = total_size + all_mats[i].mat_size
									if all_mats[i].size > main_mat_size then
										main_mat = all_mats[i].material
										main_mat_size = all_mats[i].mat_size
									end
								end
							end
							product_size = product_mat_size
						end
						
						if product_size ~= nil then
							--There are enough materials, so use them
							
							if (product_size <= total_size) or factory_type == "CLOTHIER" and main_mat ~= nil then
							
								opos = mainOutputBlocks[math.random(#mainOutputBlocks)]
								local product = createItem(main_mat,{product_type,product_subtype},0,opos)
								
								if product ~= nil then
								
									setProductStatus(product,getFactorySkill(machina),not hasInvalidMaterial)
								
									--Destroy all items in the building
									for i = 0, #building.contained_items-1, 1 do 
										if building.contained_items[i].use_mode == 0 then
											item = building.contained_items[i].item
											imp_mat = dfhack.matinfo.decode(item)
											if imp_mat ~= nil and product ~= nil then
												if imp_mat.type ~= main_mat.type or imp_mat.index ~= main_mat.index then
													duplicateImprovement = false
													for p = 0, #product.improvements-1, 1 do
														if product.improvements[p].mat_type == imp_mat.type and product.improvements[p].mat_index == imp_mat.index then
															duplicateImprovement = true
															break
														end
													end
													if duplicateImprovement == false then
														improvement = df.itemimprovement_coveredst:new()
														improvement.mat_type = imp_mat.type
														improvement.mat_index = imp_mat.index
														product.improvements:insert('#',improvement)
													end
												end
											end
											destroyItemInBuilding(item,building)
										end
									end
								end
							end
						else
							--Error: product not set
						end
					end
				end
				
				--Product finished: try and get more items
				gotItem = false
				for b = 1, #inputBlocks, 1 do
					cpos = inputBlocks[b]
					block = dfhack.maps.ensureTileBlock(cpos.x,cpos.y,cpos.z)
					if block.occupancy[cpos.x%16][cpos.y%16].item == true then
						for i=#block.items-1,0,-1 do
							item=df.item.find(block.items[i])
							ipos=item.pos
							if ipos.x == cpos.x and ipos.y == cpos.y and ipos.z == cpos.z and item.flags.on_ground == true then
								item.flags.forbid = true
								dfhack.items.moveToBuilding(item,building,0)
								gotItem = true
								break
							end
						end
					end
					if gotItem == false then
						--Try to get a creature
						if block.occupancy[cpos.x%16][cpos.y%16].unit == true or block.occupancy[cpos.x%16][cpos.y%16].unit_grounded == true then
							allUnits = df.global.world.units.active
							for i=#allUnits-1,0,-1 do	-- search list in reverse
								u = allUnits[i]
								if u.pos.x == cpos.x and u.pos.y == cpos.y and u.pos.z == cpos.z and u.flags1.dead == false and u.flags3.ghostly == false then
									if dfhack.units.isDwarf(u) then
										dfhack.gui.showAnnouncement( dfhack.TranslateName(u.name).." has been caught in a machine!" , COLOR_MAGENTA, true)
									end
									ripPart(u)
									break
								end
							end
						end
					end
				end
			end
			factoryFlicker(building)
			if math.random(20) == 1 then makeNoise(building,power/50) end
		else
			settings.ints[7] = settings.ints[7] - power
		end
	end
end

alreadyAdjusting = false

function getItemCaption(type,subtype)
    local attrs=df.item_type.attrs[type]
    if subtype == -1 or subtype == nil then return attrs.caption
	else return df['itemdef_'..df.item_type[type]:lower()..'st'].find(subtype).name
	end
end

function factoryAdjust(reaction,unit,job,input_items,input_reagents,output_items,call_native)
	if alreadyAdjusting == false then
		alreadyAdjusting = true
		local building = dfhack.buildings.findAtTile(unit.pos)
		local machina = getMachinaByBuildingId(building.id)
		local settings = machina.settings
		local factory_type = machina.factory_type
		
		if factory_type == "SORTER" then
			settings.ints[1] = -1 -- Item type
			settings.ints[2] = -1 -- Item subtype
			settings.ints[3] = -1 -- Material type
			settings.ints[4] = -1 -- Material index
			settings.ints[5] = -1 -- Item token
			settings.ints[6] = -1 -- Material token
			settings.ints[7] = 10000 -- cooldown
			
			local opt_types = {}
			local opt_names = {}
			local script=require('gui/script')
			
			script.start(function()
				itemtype = settings.ints[1]
				itemsubtype = settings.ints[2]
				mattype = settings.ints[3]
				matindex = settings.ints[4]
				propData = settings.ints[5]
				local useItemProp = false
				local useMatProp = false
				if propData == -1 then
				else
					if propData[0] == 1 then useItemProp = true end
					if propData[1] == 1 then useMatProp = true end
				end
				invert = settings.ints[6]
				
				adjust = script.showYesNoPrompt('Mode Set','Sort by specific item?',COLOR_LIGHTGREEN)
				if adjust == true then itemok,itemtype,itemsubtype=script.showItemPrompt('What kind of items should be separated?',function() return true end,true) end
				
				adjust = script.showYesNoPrompt('Mode Set','Sort by specific material?',COLOR_LIGHTGREEN)
				if adjust == true then matok,mattype,matindex=script.showMaterialPrompt('Sort','What kind of material should be separated?') end
				
				adjust = script.showYesNoPrompt('Mode Set','Output separated items forward?',COLOR_LIGHTGREEN)
				if adjust == true then invert = 0 end
				
				if itemtype ~= nil then
					settings.ints[1] = itemtype
					settings.ints[2] = itemsubtype
				end
				if mattype ~= nil then
					settings.ints[3] = mattype
					settings.ints[4] = matindex
				end
				settings.ints[6] = invert

				local pSettings = getMachinaSettings(building)
				pSettings = settings
				pSettings:save()
				alreadyAdjusting = false
			end)
			
		else
		
			if settings.ints[1] == -1 then -- initial settings
				settings.ints[1] = -1 -- Item type
				settings.ints[2] = -1 -- Item subtype
				settings.ints[3] = -1 -- Damage
				settings.ints[4] = -1 
				settings.ints[5] = -1
				settings.ints[6] = -1
				settings.ints[7] = 10000 -- cooldown
			end
			
			local opt_types = {}
			local opt_names = {}
			
			for i=0, #reaction.products-1, 1 do
				option = reaction.products[i]
				--itemtype_info = dfhack.items.getSubtypeDef(option.item_type,option.item_subtype)
				--print(itemtype_info)
				table.insert(opt_types,{item_type=option.item_type,item_subtype=option.item_subtype})
				table.insert(opt_names,getItemCaption(option.item_type,option.item_subtype))
				--print(option.item_str[0])
			end

			local script=require('gui/script')
			script.start(function()
				itemtype = settings.ints[1]
				local choiceok,choice=script.showListPrompt('Settings', 'Select items to produce:', COLOR_LIGHTGREEN, opt_names)
				if choice ~= nil then
					item_type = opt_types[choice].item_type
					item_subtype = opt_types[choice].item_subtype
					if item_subtype == nil then item_subtype = -1 end
					settings.ints[1] = item_type
					settings.ints[2] = item_subtype
				else
					settings.ints[1] = -1
					settings.ints[2] = -1
				end
				local pSettings = getMachinaSettings(building)
				pSettings = settings
				pSettings:save()
				alreadyAdjusting = false
			end)
		end
	end
end

function factoryInputLoad(reaction,unit,job,input_items,input_reagents,output_items,call_native)
	item = job[0]
	local building = dfhack.buildings.findAtTile(unit.pos)
	item.flags.forbid = true
	ejectItem(building,item,item.pos)
end

function timewarpAdjust(reaction,unit,job,input_items,input_reagents,output_items,call_native)
	if alreadyAdjusting == false then
		alreadyAdjusting = true
		local building = dfhack.buildings.findAtTile(unit.pos)
		local machina = getMachinaByBuildingId(building.id)
		local settings = machina.settings
		if settings.ints[1] == -1 then 
			settings.ints[1] = 0
			dfhack.gui.showAnnouncement( "The gear has been reversed." , COLOR_WHITE, true)
		else 
			settings.ints[1] = -1 
			dfhack.gui.showAnnouncement( "The gear has been set to normal." , COLOR_WHITE, true)
		end
		local pSettings = getMachinaSettings(building)
		pSettings = settings
		pSettings:save()
		alreadyAdjusting = false
	end
end

function script.showItemPrompt(text,item_filter,hide_none)
    require('gui.materials').ItemTypeDialog{
        text=text,
        item_filter=item_filter,
        hide_none=hide_none,
        on_select=script.mkresume(true),
        on_cancel=script.mkresume(false),
        on_close=script.qresume(nil)
    }:show()
    
    return script.wait()
end

function factoryInputAdjust(reaction,unit,job,input_items,input_reagents,output_items,call_native)

end

function factoryOutputAdjust(reaction,unit,job,input_items,input_reagents,output_items,call_native)

end

--TimeWarp

function destroyBody(unit)
	for i=0,#unit.corpse_parts-1,1 do
		part=df.item.find(unit.corpse_parts[i])
		if part ~= nil and getmetatable(part) ~= "item_corpsepiecest" then
			destroyItemInBuilding(part) -- destroy all corpsepieces
		end
	end
end

function fullHeal(unit,resurrect,leavebody)
	if unit then
		if resurrect then
			if unit.flags1.dead then
				unit.flags2.slaughter = false
				unit.flags3.scuttle = false
			end
			unit.flags1.dead = false
			unit.flags2.killed = false
			unit.flags3.ghostly = false
			print('Reviving unit')
			--unit.unk_100 = 3
			if leavebody then
			else
				destroyBody(unit)
			end
		end
		
		while #unit.body.wounds > 0 do
			unit.body.wounds:erase(#unit.body.wounds-1)
		end
		unit.body.wound_next_id=1

		unit.body.blood_count=unit.body.blood_max

		unit.status2.limbs_stand_count=unit.status2.limbs_stand_max
		unit.status2.limbs_grasp_count=unit.status2.limbs_grasp_max

		unit.flags2.has_breaks=false
		unit.flags2.gutted=false
		unit.flags2.circulatory_spray=false
		unit.flags2.vision_good=true
		unit.flags2.vision_damaged=false
		unit.flags2.vision_missing=false
		unit.flags2.breathing_good=true
		unit.flags2.breathing_problem=false

		unit.flags2.calculated_nerves=false
		unit.flags2.calculated_bodyparts=false
		unit.flags2.calculated_insulation=false
		unit.flags3.compute_health=true

		unit.counters.winded=0
		unit.counters.stunned=0
		unit.counters.unconscious=0
		unit.counters.webbed=0
		unit.counters.pain=0
		unit.counters.nausea=0
		unit.counters.dizziness=0

		unit.counters2.paralysis=0
		unit.counters2.fever=0
		unit.counters2.exhaustion=0
		unit.counters2.hunger_timer=0
		unit.counters2.thirst_timer=0
		unit.counters2.sleepiness_timer=0
		unit.counters2.vomit_timeout=0
		
		v=unit.body.components
		for i=0,#v.nonsolid_remaining - 1,1 do
			v.nonsolid_remaining[i] = 100	-- percent remaining of fluid layers (Urist Da Vinci)
		end

		v=unit.body.components
		for i=0,#v.layer_status - 1,1 do
			for j=0,#v.layer_status-1,1 do -- severed, leaking layers (Urist Da Vinci)
				v.layer_status[j].gone = 0
				v.layer_status[j].leaking = 0
			end
			v.layer_wound_area[i] = 0		-- wound contact areas (Urist Da Vinci)
			v.layer_cut_fraction[i] = 0		-- 100*surface percentage of cuts/fractures on the body part layer (Urist Da Vinci)
			v.layer_dent_fraction[i] = 0		-- 100*surface percentage of dents on the body part layer (Urist Da Vinci)
			v.layer_effect_fraction[i] = 0		-- 100*surface percentage of "effects" on the body part layer (Urist Da Vinci)
		end
		
		v=unit.body.components.body_part_status
		for i=0,#v-1,1 do
			v[i].on_fire = false
			v[i].missing = false
			v[i].organ_loss = false
			v[i].organ_damage = false
			v[i].muscle_loss = false
			v[i].muscle_damage = false
			v[i].bone_loss = false
			v[i].bone_damage = false
			v[i].skin_damage = false
			v[i].motor_nerve_severed = false
			v[i].sensory_nerve_severed = false
		end
		
		if unit.job.current_job and unit.job.current_job.job_type == df.job_type.Rest then
			unit.job.current_job = df.job_type.CleanSelf
		end
	end
end




function getCaste(race_id,caste_id)
    local cr=df.creature_raw.find(race_id)
    return cr.caste[caste_id]
end
function genBodyModifier(body_app_mod)
    local a=math.random(0,#body_app_mod.ranges-2)
    return math.random(body_app_mod.ranges[a],body_app_mod.ranges[a+1])
end
function getBodySize(caste,time)
    --todo real body size...
    return caste.body_size_1[#caste.body_size_1-1] --returns last body size
end
function genAttribute(array)
    local a=math.random(0,#array-2)
    return math.random(array[a],array[a+1])
end
function norm()
    return math.sqrt((-2)*math.log(math.random()))*math.cos(2*math.pi*math.random())
end
function normalDistributed(mean,sigma)
    return mean+sigma*norm()
end
function clampedNormal(min,median,max)
    local val=normalDistributed(median,math.sqrt(max-min))
    if val<min then return min end
    if val>max then return max end
    return val
end
function makeCloneSoul(unit,orig)
	caste = getCaste(orig.race,orig.caste)
	origSoul = orig.status.current_soul
    local tmp_soul=df.unit_soul:new()
    tmp_soul.unit_id=unit.id
    tmp_soul.name:assign(unit.name)
    tmp_soul.race=unit.race
    tmp_soul.sex=unit.sex
    tmp_soul.caste=unit.caste
    local attrs=caste.attributes
    for k,v in pairs(origSoul.mental_attrs) do
       tmp_soul.mental_attrs[k]:assign(origSoul.mental_attrs[k])
    end
    for k,v in pairs(tmp_soul.traits) do
        tmp_soul.traits[k] = origSoul.traits[k]
    end
	for k, v in pairs(origSoul.skills) do
		local skill = df.unit_skill:new()
		skill:assign(origSoul.skills[k])
		tmp_soul.skills:insert('#',skill)
	end
	for k, v in pairs(origSoul.preferences) do
		local pref = df.unit_preference:new()
		pref:assign(origSoul.preferences[k])
		tmp_soul.preferences:insert('#',pref)
	end
    --todo skills,preferences,traits.
    unit.status.souls:insert("#",tmp_soul)
    unit.status.current_soul=tmp_soul
end
function CreateClone(u)
    local race=df.creature_raw.find(u.race)
    if race==nil then error("Invalid race_id") end
    local caste=getCaste(u.race,u.caste)
    local unit=df.unit:new()
    unit.race=u.race
    unit.caste=u.caste
    unit.id=df.global.unit_next_id
	unit.profession=u.profession
    df.global.unit_next_id=df.global.unit_next_id+1
	unit.relations.old_year=u.relations.old_year
    unit.sex=caste.gender
		local num_inter=#caste.body_info.interactions  -- new for interactions
	unit.curse.anon_4:resize(num_inter) -- new for interactions
	unit.curse.anon_5:resize(num_inter) -- new for interactions
    local body=unit.body
    
    body.body_plan=caste.body_info
    local body_part_count=#body.body_plan.body_parts
    local layer_count=#body.body_plan.layer_part
    --components
    unit.relations.birth_year=u.relations.birth_year
    unit.relations.birth_time=u.relations.birth_time
    unit.relations.old_year=u.relations.old_year
    unit.relations.old_time=u.relations.old_time
    
    --unit.relations.old_time=?? --TODO add normal age
	
	unit.enemy:assign(u.enemy)
	unit.appearance:assign(u.appearance)
	unit.body:assign(u.body)
	unit.recuperation:assign(u.recuperation)
    
    makeCloneSoul(unit,u)
    
    --df.global.world.units.all:insert("#",unit)
    df.global.world.units.active:insert("#",unit)
    --todo set weapon bodypart
    
    local num_inter=#caste.body_info.interactions
    unit.curse.anon_5:resize(num_inter)
    return unit
end

function PlaceClone(orig)
	
    local u=CreateClone(orig)
	
	if orig.name.has_name == true then
		u.name.first_name=orig.name.first_name
		u.name.nickname = orig.name.nickname
		u.name.has_name=true
	end
	
    u.civ_id=orig.civ_id
	
	pos = orig.pos
    
    local desig,ocupan=dfhack.maps.getTileFlags(pos)
    if ocupan.unit then
        ocupan.unit_grounded=true
        u.flags1.on_ground=true
    else
        ocupan.unit=true
    end
    
	histfig = df.historical_figure.find(orig.hist_figure_id)
	
	newFig = createCloneNemesis(u,u.civ_id)
	if histfig then
		newFig.name:assign(histfig.name)
		u.name:assign(newFig.name)
	end
	return u
end
function createFigure(trgunit,he)
    local hf=df.historical_figure:new()
    hf.id=df.global.hist_figure_next_id
    hf.race=trgunit.race
    hf.caste=trgunit.caste
	hf.profession = trgunit.profession
	hf.sex = trgunit.sex
    df.global.hist_figure_next_id=df.global.hist_figure_next_id+1
	hf.appeared_year = df.global.cur_year
	
	hf.born_year = trgunit.relations.birth_year
	hf.born_seconds = trgunit.relations.birth_time
	hf.curse_year = trgunit.relations.curse_year
	hf.curse_seconds = trgunit.relations.curse_time
	hf.birth_year_bias = trgunit.relations.birth_year_bias
	hf.birth_time_bias = trgunit.relations.birth_time_bias
	hf.old_year = trgunit.relations.old_year
	hf.old_seconds = trgunit.relations.old_time
	hf.died_year = -1
	hf.died_seconds = -1
	hf.name:assign(trgunit.name)
	hf.civ_id = trgunit.civ_id
	hf.population_id = trgunit.population_id
	hf.breed_id = -1
	hf.unit_id = trgunit.id
	
    df.global.world.history.figures:insert("#",hf)

	hf.info = df.historical_figure_info:new()
	hf.info.unk_14 = df.historical_figure_info.T_unk_14:new() -- hf state?
	--unk_14.region_id = -1; unk_14.beast_id = -1; unk_14.unk_14 = 0
	hf.info.unk_14.unk_18 = -1; hf.info.unk_14.unk_1c = -1
	-- set values that seem related to state and do event
	--change_state(hf, dfg.ui.site_id, region_pos)


--lets skip skills for now
--local skills = df.historical_figure_info.T_skills:new() -- skills snap shot
-- ...
--info.skills = skills


	he.histfig_ids:insert('#', hf.id)
	he.hist_figures:insert('#', hf)

	trgunit.flags1.important_historical_figure = true
	trgunit.flags2.important_historical_figure = true
	trgunit.hist_figure_id = hf.id
	trgunit.hist_figure_id2 = hf.id
    
    hf.entity_links:insert("#",{new=df.histfig_entity_link_memberst,entity_id=trgunit.civ_id,link_strength=100})
    --add entity event
    local hf_event_id=df.global.hist_event_next_id
    df.global.hist_event_next_id=df.global.hist_event_next_id+1
    df.global.world.history.events:insert("#",{new=df.history_event_add_hf_entity_linkst,year=trgunit.relations.birth_year,
        seconds=trgunit.relations.birth_time,id=hf_event_id,civ=hf.civ_id,histfig=hf.id,link_type=0})
    return hf
end
function createCloneNemesis(trgunit,civ_id)
    local id=df.global.nemesis_next_id
    local nem=df.nemesis_record:new()
	local he=df.historical_entity.find(civ_id)
    nem.id=id
    nem.unit_id=trgunit.id
    nem.unit=trgunit
    nem.flags:resize(1)
    --not sure about these flags...
    nem.flags[4]=true
    nem.flags[5]=true
    nem.flags[6]=true
    nem.flags[7]=true
    nem.flags[8]=true
    nem.flags[9]=true
    --[[for k=4,8 do
        nem.flags[k]=true
    end]]
    df.global.world.nemesis.all:insert("#",nem)
    df.global.nemesis_next_id=id+1
    trgunit.general_refs:insert("#",{new=df.general_ref_is_nemesisst,nemesis_id=id})
    trgunit.flags1.important_historical_figure=true
    
    nem.save_file_id=he.save_file_id
	
    he.nemesis_ids:insert("#",id)
	he.nemesis:insert("#",nem)
    nem.member_idx=he.next_member_idx
    he.next_member_idx=he.next_member_idx+1
    --[[ local gen=df.global.world.worldgen
    gen.next_unit_chunk_id
    gen.next_unit_chunk_offset
    ]]
    nem.figure=createFigure(trgunit,he)
	return nem.figure
end

function fixAge(u,change,torque,canClone)
	if change == nil then change = 0 end
	if torque == nil then torque = 0 end

	unitRaw = df.global.world.raws.creatures.all[u.race]
	casteRaw = unitRaw.caste[u.caste]
	
	death = nil
	age = df.global.cur_year - u.relations.birth_year
	
	--print('fixing age: '..age)
		
	if u.flags1.dead == true then
		for de=#df.global.world.deaths.all-1,0,-1 do	-- search list in reverse
			d = df.global.world.deaths.all[de]
			death_id=d.victim
			if u.id==death_id then
				death = d
				break
			end
		end
	end
	
	local immortal = false
	
	if u.relations.old_year < u.relations.birth_year then immortal = true end
	
	if torque ~= 0 and canClone == true and math.random(1000000) < torque and u.relations.birth_year <= df.global.cur_year and u.relations.old_year > df.global.cur_year then
		--print('pulling creature from parallel universe')
		clone = PlaceClone(u)
		if math.random(2) == 1 then
			clone.pos:assign(u.idle_area)
			u.pos:assign(u.path.dest)
		else
			clone.pos:assign(u.path.dest)
			u.pos:assign(u.idle_area)
		end
		if u.flags1.dead == false then
			clone.animal.vanish_countdown = math.random(torque) * 100
		end
		clone.status.happiness=0
		clone.status.insanity_chance=100
	elseif change ~= 0 then
		for y=0,math.abs(change),1 do
		
			local prevBirthYear = u.relations.birth_year
			local prevOldYear = u.relations.old_year
			local prevAge = df.global.cur_year - u.relations.birth_year
			
			if change > 0 then c = 1
			elseif change < 0 then c = -1 end
			
			if change ~= 0 then
				u.relations.birth_year = u.relations.birth_year + c
				if immortal == false then u.relations.old_year = u.relations.old_year + c end
			end
			
			age = df.global.cur_year - u.relations.birth_year
			
			if age < casteRaw.misc.child_age and u.profession ~= 103 then
				u.profession = 103
			end
			if age < casteRaw.misc.baby_age and u.profession ~= 104 then
				u.profession = 104
			end
			
			if age > casteRaw.misc.child_age and (u.profession == 103 or u.profession == 104) then
				u.profession = 102
			end
			if age > casteRaw.misc.baby_age and age < casteRaw.misc.child_age then
				u.profession = 103
			end
			
			if u.relations.old_year == 0 and u.flags1.dead == false then
				break
			end
						
			if death ~= nil and (death.death_cause==df.death_type.VANISH or death.death_cause==df.death_type.OLD_AGE) then timeDeath = true end
				
			if u.relations.birth_year > df.global.cur_year and prevBirthYear <= df.global.cur_year then
				if u.name.has_name and u.flags1.dead == false then dfhack.gui.showAnnouncement( dfhack.TranslateName(u.name).." has been erased from time!" , COLOR_MAGENTA, true) end
				local histfig = df.historical_figure.find(u.hist_figure_id)
				if histfig then
					retGone(u.hist_figure_id)
				else
					if u.flags1.dead then
						destroyBody(u)
					else
						u.animal.vanish_countdown = 1
					end
				end
				break
			elseif death ~= nil and timeDeath and u.relations.birth_year <= df.global.cur_year and prevBirthYear > df.global.cur_year then
				fullHeal(u,true,false)
				break
			elseif death ~= nil and timeDeath and u.relations.old_year > df.global.cur_year and prevOldYear <= df.global.cur_year then
				fullHeal(u,true,false)
				break
			end
		end
	end
	
	if immortal == true and u.relations.old_year >= u.relations.birth_year then
		u.relations.old_year = u.relations.birth_year - 1
		if u.relations.old_year > -1 then
			u.relations.old_year = -1
		end
	end
	
	local histfig = df.historical_figure.find(u.hist_figure_id)
	
	if histfig then 
		histfig.born_year = u.relations.birth_year
		histfig.old_year = u.relations.old_year
	end
	
	--print('birth year: '..u.relations.birth_year)
	--print('death year: '..u.relations.old_year)
	--print('age set as: '..age)
end

function retGone(histfig_id)
	local histfig = df.historical_figure.find(histfig_id)
	--destroy all children
	if histfig and histfig.histfig_links then
		for i=#histfig.histfig_links-1,0,-1 do
			local link = histfig.histfig_links[i]
			if getmetatable(link) == 'histfig_hf_link_childst' then
				local target = link.target_hf
				retGone(target)
			end
		end
	end
	--revive all victims
	if histfig and histfig.info and histfig.info.kills then
		local kills = histfig.info.kills.events
		for i=#kills-1,0,-1 do
			local event_id = kills[i]
			local event = df.global.world.history.events[event_id]
			local weapon = df.item.find(event.weapon.item)
			if weapon then
				local weaponkills = weapon.history_info.value.kills.targets.events
			end
			local victim_hf = df.historical_figure.find(event.victim_hf)
			if victim_hf then
				for _,v in ipairs(df.global.world.units.active) do
					if v.hist_figure_id == victim_hf.id then
						fullHeal(v,true)
					end
				end
			end
		end
	end
	if histfig then
		for _,v in ipairs(df.global.world.units.active) do
			if v.hist_figure_id == histfig.id then
				if v.flags1.dead then
					destroyBody(v)
				else
					v.animal.vanish_countdown = 1
				end
			end
		end
		histfig.born_year = 0
		histfig.born_seconds = 0
		histfig.old_year = 0
		histfig.old_seconds = 0
	end
end

function timeWarp(machina,power)
	local building = machina.building
	local settings = machina.settings
	if df.global.cur_year > 0 then
		mult = 10000
		if settings.ints[7] > mult then 
			local num = math.floor(settings.ints[7]/mult)
			
			settings.ints[7] = settings.ints[7] - (mult*num)

			if settings.ints[1] == -1 then
				timestream = timestream + num
			else
				timestream = timestream - num
			end
		end
	end
	settings.ints[7] = settings.ints[7] + power
end

--Initial call

if dfhack.isMapLoaded() then 
	dfhack.onStateChange.loadMachina(SC_MAP_LOADED)
end