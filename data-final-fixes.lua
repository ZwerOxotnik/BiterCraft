if mods["ups-fps"] then return end


-- Removes blood of biters
local explosions = data.raw['explosion']
explosions['blood-explosion-small'].created_effect = nil
explosions['blood-explosion-big'].created_effect = nil
explosions['blood-explosion-huge'].created_effect = nil


-- Removes corpses and some effects in each unit
for _, unit in pairs(data.raw.unit) do
	unit.dying_explosion = nil
	unit.corpse = nil
end


for _, prototype in pairs(data.raw) do
	for _, entity in pairs(prototype) do
		entity.corpse = nil
	end
end

for name, corpse in pairs(data.raw.corpse) do
	if name == "defender-remnants" then -- it's weird
		corpse.time_before_removed = 60 -- 1 sec
		corpse.time_before_shading_off = 60 -- 1 sec
	else
		corpse = nil
	end
end

-- Probably, it must be changed
for _, corpse in pairs(data.raw['rail-remnants']) do
	corpse.time_before_removed = 60 -- 1 sec
	corpse.time_before_shading_off = 60 -- 1 sec
end
