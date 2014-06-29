-- Removes historic id from corpses being butchered
 
local args = {...}

mode = 'enable'

function processArgs(args)
    for k,v in ipairs(args) do
        v=v:lower()
        if v == "disable" then mode = 'disable' end
        if v == "enable" then mode = 'enable' end
    end
end
 
processArgs(args)
 
eventful=require('plugins.eventful')
 
eventful.enableEvent(eventful.eventType.INVENTORY_CHANGE,5)

if mode == 'enable' then 
	-- Enable it
	eventful.onInventoryChange.fixbutchery = function(unit_id,item_id,old_equip,new_equip)
		-- Make sure item exists
		local item = df.item.find(item_id)
		if not item then return false end
		
		-- Check that it's being butchered
		for _, ref in ipairs(item.specific_refs) do
		
			-- Butcher animal is 105 I think
			if ref.job.job_type == 105 then
				
				if item.hist_figure_id > 0 then
					-- Remove historic id
					item.hist_figure_id = -1
					print('Fixing butchery for unit #' .. item.unit_id)
					break
				else
					-- Already fixed
					break
				
				end
				
			end
		
		end
		
	end 
	print('Enabled fixbutchery')
	
else
	-- Disable it
	eventful.onInventoryChange.fixbutchery = nil
	print('Disabled fixbutchery')
	
end