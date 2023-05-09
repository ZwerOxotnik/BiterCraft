-- For https://mods.factorio.com/mod/GTTS
local settings = data.raw["int-setting"]
if settings and settings["gtts-Target-FrameRate"] then
	settings["gtts-Target-FrameRate"].default_value = 30
end
