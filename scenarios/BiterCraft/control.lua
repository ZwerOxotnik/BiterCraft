if script.mod_name ~= "BiterCraft" and script.active_mods.BiterCraft then
	return
end


---@type table<string, module>
local modules = {}
modules.BiterCraft = require("BiterCraft")


local event_handler = require("static-lib/lualibs/event_handler_vZO")
event_handler.add_libraries(modules)


-- This is a part of "gvv", "Lua API global Variable Viewer" mod. https://mods.factorio.com/mod/gvv
-- It makes possible gvv mod to read sandboxed variables in the map or other mod if following code is inserted at the end of empty line of "control.lua" of each.
if script.active_mods["gvv"] then require("__gvv__.gvv")() end
