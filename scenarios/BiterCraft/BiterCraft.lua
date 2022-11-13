---@class BC : module
local M = {}


-- TODO: use another sound when a wave starts
-- TODO: remind players about commands
-- TODO: track player data


--#region Global game data
local mod_data
--#endregion


local START_PLAYER_ITEMS = require("start_player_items")
local START_BASE_ITEMS = require("start_base_items")
local random = math.random
local floor = math.floor
local min = math.min
local EMPTY_WIDGET = {type = "empty-widget"}
local COLON = {"colon"}
local LABEL = {type = "label"}
local YELLOW_COLOR = {1, 1, 0}


local biter_upgrades = {
	"small-biter",
	"medium-biter",
	"big-biter",
	"behemoth-biter"
}
local spitter_upgrades = {
	"small-spitter",
	"medium-spitter",
	"big-spitter",
	"behemoth-spitter"
}


--#region Util

---@param s string
local function trim(s)
	return s:match'^%s*(.*%S)' or ''
end

local function find_chest()
	local chest_name = "steel-chest"
	if game.entity_prototypes[chest_name] then return chest_name end
	log("Starting chest " .. chest_name .. " is not a valid entity prototype, picking a new container from prototype list")

	for name, chest in pairs(game.entity_prototypes) do
		if chest.type == "container" then
			return name
		end
	end
end

local function teleport_safely(player, surface, target_position)
	local character = player.character
	if not (character and character.valid) then
		player.teleport(target_position, surface)
	else
		local target
		local vehicle = player.vehicle
		local target_name
		if vehicle and not vehicle.train and vehicle.get_driver() == character and vehicle.get_passenger() == nil then
			target = vehicle
			target_name = vehicle.name
		else
			target = player
			target_name = character.name
		end
		local radius = 200
		local non_colliding_position = surface.find_non_colliding_position(target_name, target_position, radius, 10)

		if non_colliding_position then
			target.teleport(non_colliding_position, surface)
		else
			player.print("It's not possible to teleport you because there's not enough space for your character")
		end
	end
end

function insert_start_items(player)
	local item_prototypes = game.item_prototypes

	local car_name = "car"
	if game.entity_prototypes[car_name] then
		local surface = game.get_surface(1)
		local non_colliding_position = surface.find_non_colliding_position(car_name, {0, 0}, 200, 10)
		if non_colliding_position then
			local car = surface.create_entity{
				name = car_name, force = "player",
				position = player.position
			}
			car.set_driver(player)

			local fuel_name = "wood"
			if item_prototypes[fuel_name] then
				local stack = {name = fuel_name, count = 600}
				car.insert(stack)
			end

			if game.item_prototypes[car_name] then
				local stack = {name = car_name, count = 1}
				player.insert(stack)
			end
		end
	end

	for _, item_data in pairs(START_PLAYER_ITEMS) do
		if item_prototypes[item_data.name] then
			player.insert(item_data)
		end
	end
end

-- TODO: Refactor?
function print_time_before_wave(player, is_server)
	local next_wave_tick = mod_data.last_wave_tick + (60 * 60 * 5)
	local ticks_before_wave = next_wave_tick - game.tick
	if ticks_before_wave <= 0 then return end

	local minutes = floor(ticks_before_wave / min(3600, 3600 * game.speed))
	local message
	if minutes > 0 then
		message = {"BiterCraft.minutes_before_new_wave", minutes}
	else
		local seconds = floor(ticks_before_wave / min(60, 60 * game.speed))
		message = {"BiterCraft.seconds_before_new_wave", seconds}
	end

	if player then
		player.print(message, YELLOW_COLOR)
	elseif is_server then
		log(message, YELLOW_COLOR)
	else
		for _, _player in pairs(game.connected_players) do
			if _player.valid then
				_player.print(message, YELLOW_COLOR)
			end
		end
	end
end

function print_defend_points(player)
	if mod_data.generate_new_round then return end
	if #mod_data.defend_points == 0 then return end

	local target_entity = mod_data.target_entity
	local main_defend_point_text = ""
	if target_entity and target_entity.valid then
		local pos = target_entity.position
		main_defend_point_text = ("[gps=%d,%d] "):format(pos.x, pos.y)
	end

	local points_data = ""
	for _, point in pairs(mod_data.defend_points) do
		points_data = points_data .. ("[gps=%d,%d] "):format(point[1], point[2])
	end

	local message = {'', {"BiterCraft.main_defend_target"}, COLON, main_defend_point_text}
	if #mod_data.defend_points > 0 then
		table.insert(message, '\n')
		table.insert(message, {"BiterCraft.defend_points"})
		table.insert(message, COLON)
		table.insert(message, points_data)
	end

	if player then
		player.print(message, YELLOW_COLOR)
	else
		for _, _player in pairs(game.connected_players) do
			if _player.valid then
				_player.print(message, YELLOW_COLOR)
			end
		end
	end
end


function delete_settings_gui()
	for _, player in pairs(game.players) do
		if player.valid then
			local frame = player.gui.center.BC_lobby_settings_frame
			if frame and frame.valid then
				frame.destroy()
			end
		end
	end
end

function teleport_players_to_center(players)
	local surface = game.get_surface(1)
	local target_position = {0, 0}
	for _, player in pairs(players) do
		if player.valid then
			teleport_safely(player, surface, target_position)
		end
	end
end

do
	local biter_pos = {0, 0}
	local biter_data = {name = "", force = "enemy", position = biter_pos}
	function upgrade_biters()
		if mod_data.enemy_tech_lvl >= #biter_upgrades then return end
		local surface = game.get_surface(1)

		local entities = surface.find_entities(
			{{25000, 10}, {25050, 50}}
		)
		local spawn_count = floor(#entities/4)
		for i = 1, #entities do
			entities[i].destroy()
		end

		mod_data.enemy_tech_lvl = mod_data.enemy_tech_lvl + 1
		mod_data.spawn_per_wave = 1

		local create_entity = surface.create_entity
		local enemy_tech_lvl = mod_data.enemy_tech_lvl

		if enemy_tech_lvl == 0 then
			biter_data.name = "small-biter"
		elseif enemy_tech_lvl == 1 then
			biter_data.name = "medium-biter"
		elseif enemy_tech_lvl == 2 then
			biter_data.name = "big-biter"
		else
			biter_data.name = "behemoth-biter"
		end
		for _ = 1, spawn_count do
			biter_pos[1] = random(25000, 25050)
			biter_pos[2] = random(10, 50)
			create_entity(biter_data)
		end

		if enemy_tech_lvl == 0 then
			biter_data.name = "small-spitter"
		elseif enemy_tech_lvl == 1 then
			biter_data.name = "medium-spitter"
		elseif enemy_tech_lvl == 2 then
			biter_data.name = "big-spitter"
		else
			biter_data.name = "behemoth-spitter"
		end
		for _ = 1, spawn_count do
			biter_pos[1] = random(25000, 25050)
			biter_pos[2] = random(10, 50)
			create_entity(biter_data)
		end

		game.print({"BiterCraft.biters_evolved"}, YELLOW_COLOR)
	end
end

-- TODO: Refactor everything and make on "stages"!
local function generate_map_territory()
	local map_size = mod_data.map_size
	local surface = game.get_surface(1)
	local tiles = {}

	-- Set refined-concrete tiles
	local c = 0
	for i = -100, 0 do
		for j = -100, 0 do
			c = c + 1
			tiles[c] = {position = {i, j}, name = "refined-concrete"}
			if c > 1024 then
				surface.set_tiles(tiles, false, false, false)
				tiles = {}
				c = 0
			end
		end
	end
	surface.set_tiles(tiles, false, false, false)

	-- Set water tiles
	c = 0
	for i = -51, -48 do
		for j = -51, -48 do
			c = c + 1
			tiles[c] = {position = {i, j}, name = "water"}
		end
	end
	surface.set_tiles(tiles, false, false, false)

	local length = 100
	local steps = map_size / 2 / length
	for i = -steps, steps-1 do
		for j = -steps, steps-1 do
			surface.clone_area{
				source_area={left_top = {x = -length, y = -length}, right_bottom = {x = 0, y = 0}},
				destination_area={left_top = {x = i*length, y = j*length}, right_bottom = {x = i*length+length, y = j*length+length}},
				destination_force="neutral", clone_tiles=true, clone_entities=false,
				clone_decoratives=false, clear_destination_entities=false,
				clear_destination_decoratives=false, expand_map=false,
				create_build_effect_smoke=false
			}
		end
	end

	local length = 1000
	local steps = map_size / 2 / length
	for i = -steps, steps-1 do
		for j = -steps, steps-1 do
			surface.clone_area{
				source_area={left_top = {x = -length, y = -length}, right_bottom = {x = 0, y = 0}},
				destination_area={left_top = {x = i*length, y = j*length}, right_bottom = {x = i*length+length, y = j*length+length}},
				destination_force="neutral", clone_tiles=true, clone_entities=false,
				clone_decoratives=false, clear_destination_entities=false,
				clear_destination_decoratives=false, expand_map=false,
				create_build_effect_smoke=false
			}
		end
	end

	local steps = math.ceil(map_size / 2 / 32)
	local position = {0, 0}
	for i = -steps, steps do
		position[1] = i
		for j = -steps, steps do
			position[2] = j
			surface.set_chunk_generated_status(position, defines.chunk_generated_status.entities)
		end
	end
end


local function make_defend_lines()
	local map_border = mod_data.map_size/2
	local length = 400
	local height = 60
	local defend_lines_count = mod_data.defend_lines_count
	local surface = game.get_surface(1)
	local clone_area = surface.clone_area
	local destination_left_top = {0, 0}
	local destination_right_bottom = {0, 0}
	local clone_data = {
		source_area={left_top = {-length/2, -height/2}, right_bottom = {length/2, height/2}},
		destination_area={left_top = destination_left_top, right_bottom = destination_right_bottom},
		clone_tiles=true, clone_entities=false,
		clone_decoratives=false, clear_destination_entities=false,
		clear_destination_decoratives=false, expand_map=false,
		create_build_effect_smoke=false
	}

	mod_data.defend_points = {}
	local entity_position = {map_border + 20, 0}
	local entity_data = {
		name="", force = "enemy",
		position = entity_position
	}
	local h_size = floor(defend_lines_count/2)
	local c = 0
	for i = -h_size, h_size do
		destination_left_top[1] = map_border
		destination_left_top[2] = (length/2) * i
		destination_right_bottom[1] = map_border + length
		destination_right_bottom[2] = (length/2) * i + height
		clone_area(clone_data)

		c = c + 1
		mod_data.defend_points[c] = {map_border, (length/2) * i + height / 2}

		entity_position[2] = (length/2) * i + height / 2
		entity_data.name = "biter-spawner"
		surface.create_entity(entity_data)
		entity_data.name = "big-worm-turret"
		surface.create_entity(entity_data)
	end

	print_defend_points()
end

local function set_game_rules_by_settings()
	if mod_data.is_settings_set then return end

	if #mod_data.defend_points == 0 then
		make_defend_lines()
	end

	mod_data.is_settings_set = true
end

local function make_defend_target()
	local surface = game.get_surface(1)
	local entity = surface.create_entity{
		name = "rocket-silo", force = "player",
		position = {0, 0}
	}
	entity.minable = false
	mod_data.target_entity = entity
	mod_data.entity_target_event_id = script.register_on_entity_destroyed(entity)

	local turret_name = "gun-turret"
	if game.entity_prototypes[turret_name] then
		local turret = surface.create_entity{
			name = turret_name, force = "player",
			position = {15, 0}
		}

		local ammo_name = "firearm-magazine"
		if game.item_prototypes[ammo_name] then
			local stack = {name = ammo_name, count = 200}
			turret.insert(stack)
		end
	end

	if game.entity_prototypes["electric-energy-interface"] then
		entity = surface.create_entity{
			name = "electric-energy-interface", force = "player",
			position = {-15, 0}
		}
		entity.minable = false
		entity.operable = false
		entity.destructible = true
		entity.power_production = 1000
		entity.electric_buffer_size = 500
		entity.power_usage = 0
	end

	if game.entity_prototypes["substation"] then
		entity = surface.create_entity{
			name = "substation", force = "player",
			position = {-18, 0}
		}
	end

	container_name = find_chest()
	position = surface.find_non_colliding_position(container_name, {0, 0}, 100, 1)
	if position == nil then
		log("Can't find non colliding position for " .. container_name)
	else
		local item_stack = {name = "", count = 0}
		local target_position = {0, 0}
		local non_colliding_position = surface.find_non_colliding_position(container_name, target_position, 100, 1.5)
		target = surface.create_entity{name = container_name, position = non_colliding_position, force = "player", create_build_effect_smoke = false}
		for _, item in pairs(START_BASE_ITEMS) do
			if game.item_prototypes[item.name] then
				item_stack.name = item.name
				item_stack.count = item.count
				while item_stack.count > 0 do
					local inserted_count = target.insert(item_stack)
					if inserted_count > 0 then
						item_stack.count = item_stack.count - inserted_count
					else
						non_colliding_position = surface.find_non_colliding_position(container_name, target_position, 100, 1.5)
						if non_colliding_position == nil then
							log("Can't find non colliding position for " .. container_name)
							goto FINISH_START_BASE_ITEMS
						end
						target = surface.create_entity{name = container_name, position = non_colliding_position, force = "player", create_build_effect_smoke = false}
					end
				end
			end
		end
		:: FINISH_START_BASE_ITEMS ::
	end
end

-- TODO: Recheck with other ores
local function create_resources()
	local map_size = mod_data.map_size
	local h_map_size = map_size / 2
	local surface = game.get_surface(1)
	local create_entity = surface.create_entity
	local clone_area = surface.clone_area
	local source_left_top = {0, 0}
	local source_right_bottom = {0, 0}
	local destination_left_top = {0, 0}
	local destination_right_bottom = {0, 0}
	local clone_data = {
		source_area={left_top = source_left_top, right_bottom = source_right_bottom},
		destination_area={left_top = destination_left_top, right_bottom = destination_right_bottom},
		clone_tiles=false, clone_entities=true,
		clone_decoratives=false, clear_destination_entities=false,
		clear_destination_decoratives=false, expand_map=false,
		create_build_effect_smoke=false
	}
	local position = {0, 0}
	local resource_data = {name="", amount=4294967295, snap_to_tile_center=true, position=position}

	local start_x = -map_size / 2 + 100
	local start_y = -100

	local function create_resourse_zones()
		for x = 0, 9 do
			for y = 0, 9 do
				position[1] = start_x + x
				position[2] = start_y + y
				create_entity(resource_data)
			end
		end

		source_left_top[1] = start_x
		source_left_top[2] = start_y
		source_right_bottom[1] = start_x + 10
		source_right_bottom[2] = start_y + 10
		for x = 0, 2 do
			destination_left_top[1] = start_x + (x * 10)
			destination_right_bottom[1] = start_x + (x * 10) + 10
			for y = 0, 2 do
				if x ~= 0 or y ~= 0 then
					destination_left_top[2] = start_y + (y * 10)
					destination_right_bottom[2] = start_y + (y * 10) + 10
					clone_area(clone_data)
				end
			end
		end
	end

	local resource_count = 0
	for _, prototype in pairs(game.entity_prototypes) do
		if prototype.type == "resource" and prototype.name ~= "crude-oil" then
			resource_count = resource_count + 1
			start_x = start_x + 100
			resource_data.name = prototype.name
			create_resourse_zones()
		end
	end

	-- Oil between ore patches
	start_x = -map_size / 2 + 200 + 65
	resource_data.name = "crude-oil"
	for _ = 1, resource_count - 1 do
		start_x = start_x + 100
		position[1] = start_x
		start_y = -100
		for j = 0, 3 do
			position[2] = start_y + j * 10
			create_entity(resource_data)
		end
	end

	-- Copy and paste ores ad oil
	start_x = -map_size / 2 + 200
	start_y = -100

	source_left_top[1] = start_x
	source_left_top[2] = start_y
	source_right_bottom[1] = start_x + (100 * resource_count)
	source_right_bottom[2] = start_y + 90

	start_y = -start_y
	destination_left_top[1] = start_x
	destination_left_top[2] = start_y
	destination_right_bottom[1] = start_x + (100 * resource_count)
	destination_right_bottom[2] = start_y + 90
	clone_area(clone_data)

	source_left_top[1] = start_x
	source_left_top[2] = -start_y
	source_right_bottom[1] = start_x + (100 * resource_count)
	source_right_bottom[2] = start_y + 90
	while true do
		start_x = start_x + 100 * (resource_count + 1)
		if start_x > map_size / 2 - 200 then
			break
		end
		destination_left_top[1] = start_x
		destination_left_top[2] = -start_y
		destination_right_bottom[1] = start_x + (100 * resource_count)
		destination_right_bottom[2] = start_y + 90
		clone_area(clone_data)
	end

	-- Delete entities outside the map
	local entities = surface.find_entities(
		{{h_map_size - 200, -h_map_size}, {h_map_size + (100 * resource_count), h_map_size}}
	)
	for i = 1, #entities do
		entities[i].destroy()
	end
end


--#endregion


--#region Functions of events

local function create_lobby_settings_GUI(player)
	local center = player.gui.center
	if center.BC_lobby_settings_frame then
		return
	end

	-- local is_multiplayer = game.is_multiplayer()

	local main_frame = center.add{type = "frame", name = "BC_lobby_settings_frame", direction = "vertical"}
	-- local modes_flow = main_frame.add{type = "flow", name = "BC_modes_flow"}
	-- modes_flow.add(LABEL).caption = {'', "Mode", COLON}
	-- modes_flow.add{type = "drop-down", items = {"PvP", "PvE", "PvPvE"}, selected_index = is_multiplayer and 3 or 2}


	local textfield_content = main_frame.add{type = "table", name = "BC_textfield_content", column_count = 2}
	-- content2.add(LABEL).caption = {'', "Biter price multiplier", COLON}
	-- content2.add{type = "textfield", name = "BC_biter_price_mult_textfield", text = 1}.style.maximal_width = 70
	-- textfield_content.add(LABEL).caption = "Biter difficulty:"
	-- textfield_content.add{type = "textfield", name = "BC_biter_difficulty_textfield", text = 30, numeric = true, allow_decimal = true, allow_negative = false}.style.maximal_width = 70
	textfield_content.add(LABEL).caption = {'', "Defend lines", COLON}
	textfield_content.add{type = "textfield", name = "BC_defend_lines_textfield", text = mod_data.defend_lines_count or 3, numeric = true, allow_decimal = true, allow_negative = false}.style.maximal_width = 70
	-- content2.add(LABEL).caption = "Map size:"
	-- content2.add{type = "textfield", name = "BC_map_size_textfield", text = 30000}.style.maximal_width = 70


	-- local biter_crafting_flow = main_frame.add{type = "flow", name = "BC_biter_crafting_flow"}
	-- biter_crafting_flow.add(LABEL).caption = {'', "Biter crafting with science", COLON}
	-- biter_crafting_flow.add{type = "checkbox", name = "BC_biter_crafting_checkbox", state = true}

	-- local ev_on_techs_flow = main_frame.add{type = "flow", name = "BC_ev_on_techs_flow"}
	-- ev_on_techs_flow.add(LABEL).caption = {'', "Evolution on techs", COLON}
	-- ev_on_techs_flow.add{type = "checkbox", name = "BC_ev_on_techs_checkbox", state = false}

	-- local BC_wave_bosses_flow = main_frame.add{type = "flow", name = "BC_wave_bosses_flow"}
	-- BC_wave_bosses_flow.add(LABEL).caption = {'', "Wave bosses", COLON}
	-- BC_wave_bosses_flow.add{type = "checkbox", name = "BC_wave_bosses_checkbox", state = false}

	local BC_wave_bosses_flow = main_frame.add{type = "flow", name = "BC_double_wave_flow"}
	BC_wave_bosses_flow.add(LABEL).caption = {'', "Double enemies each 10th wave", COLON}
	BC_wave_bosses_flow.add{type = "checkbox", name = "BC_double_wave_checkbox", state = mod_data.is_double_wave_on or false}

	-- local PvP_attacks_flow = main_frame.add{type = "flow", name = "BC_PvP_attacks_flow"}
	-- PvP_attacks_flow.add(LABEL).caption = {'', "Players attacks", COLON}
	-- PvP_attacks_flow.add{type = "checkbox", name = "BC_PvP_attacks_checkbox", state = false}


	local content3 = main_frame.add{type = "table", name = "BC_content3", column_count = 3}
	local empty = content3.add(EMPTY_WIDGET)
	empty.style.right_margin = 0
	empty.style.horizontally_stretchable = true
	content3.add{type = "button", name = "BC_confirm_settings", caption = "Confirm"}
	local empty = content3.add(EMPTY_WIDGET)
	empty.style.right_margin = 0
	empty.style.horizontally_stretchable = true
end


local function on_player_joined_game(event)
	local player_index = event.player_index
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end

	if mod_data.is_settings_set == false and player.admin then
		create_lobby_settings_GUI(player)
	end

	if mod_data.generate_new_round then
		player.print({"BiterCraft.generating_new_round"}, YELLOW_COLOR)
	elseif mod_data.init_players[player_index] == nil then
		insert_start_items(player)
		mod_data.init_players[player_index] = game.tick
	end
	print_defend_points(player)
	print_time_before_wave(player)
end

local function on_player_created(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end

	player.print({"BiterCraft.wip_message"}, YELLOW_COLOR)
end

local function on_player_removed(event)
	mod_data.init_players[event.player_index] = nil
end

local function on_game_created_from_scenario()
	local surface = game.get_surface(1)

	mod_data.init_players = {}
	mod_data.defend_points = {}
	mod_data.last_wave_tick = game.tick
	mod_data.is_settings_set = false -- TODO: change it!
	mod_data.generate_new_round = false
	mod_data.last_round_tick = game.tick
	mod_data.spawn_enemy_count = 0
	mod_data.enemy_tech_lvl = 1
	mod_data.enemy_unit_group = surface.create_unit_group{position={0, 0}, force="enemy"}

	generate_map_territory()
	create_resources() -- the map shouldn't have entities
	make_defend_target()

	delete_settings_gui()
	for _, player in pairs(game.players) do
		if player.valid then
			create_lobby_settings_GUI(player) -- TODO: change it!
		end
	end

	game.print({"BiterCraft.new_round_ready"}, YELLOW_COLOR)
	for _, player in pairs(game.players) do
		if player.valid then
			insert_start_items(player)
		end
	end

	print_time_before_wave()
	print_defend_points()
end


local function on_entity_destroyed(event)
	if mod_data.entity_target_event_id ~= event.registration_number then
		return
	end

	-- TODO: delay it with message
	new_round()
end


local GUIS = {
	BC_close = function(element)
		element.parent.parent.destroy()
	end,
	BC_confirm_settings = function(element, player, event)
		if player.admin then
			local main_frame = player.gui.center.BC_lobby_settings_frame
			local textfield_content = main_frame.BC_textfield_content
			local defend_lines_textfield = textfield_content.BC_defend_lines_textfield

			local defend_lines_count = tonumber(defend_lines_textfield.text)
			if defend_lines_count < 1 then
				defend_lines_count = 1
			end
			if defend_lines_count > 10 then
				defend_lines_count = 10
			end
			mod_data.defend_lines_count = defend_lines_count

			local double_wave_checkbox = main_frame.BC_double_wave_flow.BC_double_wave_checkbox
			mod_data.is_double_wave_on = double_wave_checkbox.state

			delete_settings_gui()
			set_game_rules_by_settings()
		else
		end
	end
}
local function on_gui_click(event)
	local element = event.element
	if not (element and element.valid) then return end
	local player = game.get_player(event.player_index)

	local f = GUIS[element.name]
	if f then
		f(element, player, event)
	end
end



function check_is_settings_set(event)
	if mod_data.is_settings_set then return end
	if event.tick < mod_data.last_round_tick + (60 * 60 * 4) then return end

	-- TODO: check players
	-- mod_data.last_round_tick = event.tick
	delete_settings_gui()
	set_game_rules_by_settings()
end


do
	local length = 400
	local height = 60
	local destination_left_top = {0, 0}
	local destination_right_bottom = {0, 0}
	local clone_data = {
		source_area={left_top = {25000, 10}, right_bottom = {25050, 50}},
		destination_area={left_top = destination_left_top, right_bottom = destination_right_bottom},
		clone_tiles=false, clone_entities=true,
		clone_decoratives=false, clear_destination_entities=false,
		clear_destination_decoratives=false, expand_map=false,
		create_build_effect_smoke=false
	}
	local biter_pos = {0, 0}
	local biter_data = {name = "", force = "enemy", position = biter_pos}
	local command_data = {type = defines.command.attack, target = nil}
	function start_new_wave(event)
		if event.tick < mod_data.last_wave_tick + (60 * 60 * 4) then
			return
		end
		if mod_data.generate_new_round then return end

		local current_wave = mod_data.current_wave + 1
		mod_data.current_wave = current_wave
		mod_data.last_wave_tick = event.tick
		local surface = game.get_surface(1)

		-- Spawn new enemies
		local create_entity = surface.create_entity
		local spawn_per_wave = mod_data.spawn_per_wave
		local enemy_tech_lvl = mod_data.enemy_tech_lvl
		biter_data.name = biter_upgrades[enemy_tech_lvl]
		for _ = 1, spawn_per_wave do
			biter_pos[1] = random(25000, 25050)
			biter_pos[2] = random(10, 50)
			create_entity(biter_data)
		end

		biter_data.name = spitter_upgrades[enemy_tech_lvl]
		for _ = 1, spawn_per_wave do
			biter_pos[1] = random(25000, 25050)
			biter_pos[2] = random(10, 50)
			create_entity(biter_data)
		end
		mod_data.spawn_enemy_count = mod_data.spawn_enemy_count + spawn_per_wave * 2

		-- TODO: change it?
		local enemy_unit_group = surface.create_unit_group{position={0, 0}, force="enemy"}
		mod_data.enemy_unit_group = enemy_unit_group

		-- Copy and paste enemies
		local defend_lines_count = mod_data.defend_lines_count
		local h_size = floor(defend_lines_count/2)
		local map_border = mod_data.map_size/2
		local clone_area = surface.clone_area
		for i = -h_size, h_size do
			destination_left_top[1] = map_border + length - 60
			destination_left_top[2] = (length/2) * i + 10
			destination_right_bottom[1] = map_border + length - 10
			destination_right_bottom[2] = (length/2) * i + height - 10
			if mod_data.is_double_wave_on and (current_wave % 10 == 0) then
				clone_area(clone_data)
				clone_area(clone_data)
			else
				clone_area(clone_data)
			end
		end

		-- Command to attack
		command_data.target = mod_data.target_entity
		enemy_unit_group.set_command(command_data)

		game.print({"BiterCraft.new_wave"}, YELLOW_COLOR)
	end
end

-- TODO: Refactor
function check_map(event)
	if not mod_data.generate_new_round then return end
	if event.tick + 600 < mod_data.generate_new_round_tick then return end

	on_game_created_from_scenario()
end

local function on_entity_cloned(event)
	local destination = event.destination
	if not destination.valid then return end
	if destination.force.index ~= 2 then return end

	mod_data.enemy_unit_group.add_member(destination)
end

--#endregion


commands.add_command("skip-wave", {"BiterCraft-commands.skip-wave"}, function(event)
	if event.player_index == 0 then -- server
		mod_data.last_wave_tick = -60 * 60 * 4
		start_new_wave(event)
		return
	end

	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end
	if player.admin == false then
		player.print({"command-output.parameters-require-admin"}, {1, 0, 0})
		return
	end
	mod_data.last_wave_tick = -60 * 60 * 4
	start_new_wave(event)
end)

commands.add_command("restart-round", {"BiterCraft-commands.restart-round"}, function(cmd)
	if cmd.player_index == 0 then -- server
		new_round()
		return
	end

	local player = game.get_player(cmd.player_index)
	if not (player and player.valid) then return end
	if player.admin == false then
		player.print({"command-output.parameters-require-admin"}, {1, 0, 0})
		return
	end
	new_round()
end)

commands.add_command("wave-time", {"BiterCraft-commands.wave-time"}, function(cmd)
	if cmd.player_index == 0 then -- server
		print_time_before_wave(nil, true)
		return
	end

	local player = game.get_player(cmd.player_index)
	if not (player and player.valid) then return end
	print_time_before_wave(player)
end)

commands.add_command("spawn", {"BiterCraft-commands.spawn"}, function(cmd)
	if cmd.player_index == 0 then -- server
		return
	end

	local player = game.get_player(cmd.player_index)
	if not (player and player.valid) then return end

	local surface = game.get_surface(1)
	local target_position = {0, 0}
	teleport_safely(player, surface, target_position)
end)

commands.add_command("tp", {"BiterCraft-commands.tp"}, function(cmd)
	if cmd.player_index == 0 then -- server
		return
	end

	local player = game.get_player(cmd.player_index)
	if not (player and player.valid) then return end

	if cmd.parameter == nil then
		player.print({"BiterCraft-commands.tp"}, YELLOW_COLOR)
		return
	end

	local parameter = trim(cmd.parameter)
	if #parameter == 0 then
		player.print({"BiterCraft-commands.tp"}, YELLOW_COLOR)
		return
	end

	local target_player = game.get_player(cmd.player_index)
	if not (target_player and target_player.valid and player.connected) then return end
	if target_player == player then return end

	local surface = game.get_surface(1)
	teleport_safely(player, surface, target_player.position)
end)


function new_round()
	local surface = game.get_surface(1)
	surface.clear(true) --ignores characters

	for _, force in pairs(game.forces) do
		force.reset()
		force.reset_evolution() -- is this useful?
	end

	game.remove_offline_players()
	for _, player in pairs(game.players) do
		if player.valid then
			player.clear_items_inside()
		end
	end

	game.print({"BiterCraft.generating_new_round"}, YELLOW_COLOR)

	mod_data.defend_points = {}
	mod_data.generate_new_round = true
	mod_data.generate_new_round_tick = game.tick
end


--#region Pre-game stage


function add_event_filters()
	local filters = {
		{filter = "type", type = "unit"},
	}
	script.set_event_filter(defines.events.on_entity_cloned, filters)
end


function link_data()
	mod_data = global.BiterCraft
end


function update_global_data()
	local surface = game.get_surface(1)
	surface.generate_with_lab_tiles = true

	global.BiterCraft = global.BiterCraft or {}
	mod_data = global.BiterCraft
	mod_data.map_size = mod_data.map_size or 2000
	mod_data.defend_lines_count = mod_data.defend_lines_count or 3
	mod_data.current_wave = mod_data.current_wave or 0
	mod_data.enemy_unit_group = mod_data.enemy_unit_group or surface.create_unit_group{position={0, 0}, force="enemy"}
	mod_data.last_wave_tick = mod_data.last_wave_tick or game.tick
	mod_data.generate_new_round = mod_data.generate_new_round or false
	mod_data.is_settings_set = mod_data.is_settings_set or false
	mod_data.defend_points = mod_data.defend_points or {}
	mod_data.spawn_enemy_count = mod_data.spawn_enemy_count or 0
	mod_data.enemy_tech_lvl = mod_data.enemy_tech_lvl or 1
	mod_data.last_round_tick = mod_data.last_round_tick or game.tick
	mod_data.spawn_per_wave = mod_data.spawn_per_wave or 1
	mod_data.generate_new_round_tick = mod_data.generate_new_round_tick
	mod_data.init_players = mod_data.init_players or {}
	mod_data.is_double_wave_on = mod_data.is_double_wave_on or false

	link_data()

	for _, player_index in pairs(mod_data.init_players) do
		local player = game.get_player(player_index)
		if not (player and player.valid) then
			mod_data.init_players[player_index] = nil
		end
	end
end


local function add_remote_interface()
	-- https://lua-api.factorio.com/latest/LuaRemote.html
	remote.remove_interface("BiterCraft") -- For safety
	remote.add_interface("BiterCraft", {})
end
M.add_remote_interface = add_remote_interface

M.on_init = function()
	game.forces.player.friendly_fire = false
	update_global_data()
	add_event_filters()
end
M.on_load = function()
	link_data()
	add_event_filters()
end
M.on_configuration_changed = function()
	delete_settings_gui()
	if mod_data.is_settings_set == false then
		for _, player in pairs(game.players) do
			if player.valid then
				create_lobby_settings_GUI(player) -- TODO: change it!
			end
		end
	end
end


M.events = {
	[defines.events.on_game_created_from_scenario] = on_game_created_from_scenario,
	[defines.events.on_player_joined_game] = on_player_joined_game,
	[defines.events.on_player_created] = on_player_created,
	[defines.events.on_player_created] = on_player_removed,
	[defines.events.on_gui_click] = on_gui_click,
	[defines.events.on_entity_destroyed] = on_entity_destroyed,
	[defines.events.on_entity_cloned] = on_entity_cloned
}

M.on_nth_tick = {
	[60 * 60 * 1] = check_is_settings_set,
	[60 * 60 * 5] = start_new_wave,
	[60 * 60 * 10] = function(event)
		if event.tick < mod_data.last_wave_tick + (60 * 60 * 5) then
			return
		end
		if mod_data.generate_new_round then return end
		mod_data.spawn_per_wave = mod_data.spawn_per_wave + 1
	end,
	[60 * 60 * 30] = function(event)
		if mod_data.enemy_tech_lvl >= #biter_upgrades then return end
		if event.tick < mod_data.last_round_tick + (60 * 60 * 60 * 2) then
			if event.tick > mod_data.last_round_tick + (60 * 60 * 60 * 1) then
				if mod_data.enemy_tech_lvl == 1 then
					upgrade_biters()
				end
			end
			return
		end
		if mod_data.generate_new_round then return end
		upgrade_biters()
	end,
	[60 * 60] = function()
		print_time_before_wave()
	end,
	[300] = check_map
}


return M
