
if script.level.campaign_name then return end -- Don't init if it's a campaign
if script.level.level_name ~= "BiterCraft" then return end -- Don't init if it's not "BiterCraft" scenario

require("scenarios/BiterCraft/control")
