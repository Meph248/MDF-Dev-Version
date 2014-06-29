--countersbase.lua v0.0

events = require "plugins.eventful"
events.enableEvent(events.eventType.UNIT_DEATH,100)

events.onUnitDeath.teleport=function(unit_id)
	unit = df.unit.find(unit_id)
	kill_id = unit.relations.last_attacker_id
	if kill_id >= 0 then
		
	end
end
