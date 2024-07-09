dofile_once("data/scripts/lib/utilities.lua")
dofile_once("data/scripts/debug/keycodes.lua")

function get_player()
	return get_players()[1]
end

function validate_entity(entity)
	return entity and entity > 0 and entity or nil
end

function get_full_inventory_slots(player)
	local inventory = EntityGetFirstComponent(player, "Inventory2Component")
	return inventory and ComponentGetValue2(inventory, "full_inventory_slots_x"),
		inventory and ComponentGetValue2(inventory, "full_inventory_slots_y")
end

function get_active_item(player)
	local inventory = EntityGetFirstComponent(player, "Inventory2Component")
	return inventory and validate_entity(ComponentGetValue2(inventory, "mActiveItem"))
end

function Inventory(x, y, slots_x, slots_y)
	return {
		x = x,
		y = y,
		slots_x = slots_x,
		slots_y = slots_y
	}
end

function get_inventories()
	local UI_BARS_POS_X = MagicNumbersGetValue("UI_BARS_POS_X")
	local UI_BARS_POS_Y = MagicNumbersGetValue("UI_BARS_POS_Y")
	local UI_FULL_INVENTORY_OFFSET_X = MagicNumbersGetValue("UI_FULL_INVENTORY_OFFSET_X")
	local UI_QUICKBAR_OFFSET_X = MagicNumbersGetValue("UI_QUICKBAR_OFFSET_X")
	local UI_QUICKBAR_OFFSET_Y = MagicNumbersGetValue("UI_QUICKBAR_OFFSET_Y")

	local UI_QUICKBAR_POS_X = UI_BARS_POS_X + UI_QUICKBAR_OFFSET_X
	local UI_QUICKBAR_POS_Y = UI_BARS_POS_Y + UI_QUICKBAR_OFFSET_Y
	local full_inventory_slots_x, full_inventory_slots_y = get_full_inventory_slots(get_player())

	return {
		WAND = Inventory(
			UI_QUICKBAR_POS_X - 1,
			UI_QUICKBAR_POS_Y,
			4, 1
		),
		ITEM = Inventory(
			UI_QUICKBAR_POS_X + SLOT_WIDTH * 4,
			UI_QUICKBAR_POS_Y,
			4, 1
		),
		SPELL = Inventory(
			UI_BARS_POS_X + UI_FULL_INVENTORY_OFFSET_X,
			UI_BARS_POS_Y,
			full_inventory_slots_x, full_inventory_slots_y
		),
	}
end

function point_in_rectangle(x, y, left, up, right, down)
	return x >= left and x <= right and y >= up and y <= down
end

function mouse_in_inventory(inventory)
	local mouse_x, mouse_y = InputGetMousePosOnScreen()
	return point_in_rectangle(
		mouse_x, mouse_y,
		inventory.x * 2, inventory.y * 2,
		(inventory.x + inventory.slots_x * SLOT_WIDTH) * 2, (inventory.y + inventory.slots_y * SLOT_HEIGHT) * 2
	)
end

function get_children(entity)
	return EntityGetAllChildren(entity) or {}
end

function get_quick_inventory(player)
	local children = get_children(player)
	for _, child in ipairs(children) do
		if EntityGetName(child) == "inventory_quick" then
			return child
		end
	end
	return nil
end

function item_is_wand(item)
	local ability_comp = EntityGetFirstComponentIncludingDisabled(item, "AbilityComponent")
	return ability_comp and ComponentGetValue2(ability_comp, "use_gun_script") or false
end

function item_is_spell(item)
	return EntityGetFirstComponentIncludingDisabled(item, "ItemActionComponent") ~= nil
end

SLOT_WIDTH = 20
SLOT_HEIGHT = 20

function OnWorldPreUpdate()
	local player = get_player()
	if player == nil then
		return
	end
	local quick_inventory = get_quick_inventory(player)
	local inventories = get_inventories()

	local items = get_children(quick_inventory)
	for _, item in ipairs(items) do
		if not item_is_wand(item) and not item_is_spell(item) then
			EntityAddTag(item, "this_is_sampo")
		end
	end

	local curr_mouse_x, curr_mouse_y = InputGetMousePosOnScreen()
	if InputIsMouseButtonJustDown(Mouse_left) then
		mouse_move = false
		for k, inventory in pairs(inventories) do
			if mouse_in_inventory(inventory) then
				from = k
			end
		end
	elseif curr_mouse_x ~= prev_mouse_x or curr_mouse_y ~= prev_mouse_y then
		mouse_move = true
	end
	prev_mouse_x = curr_mouse_x
	prev_mouse_y = curr_mouse_y

	local inventory_open = GameIsInventoryOpen()
	local mouse_down = InputIsMouseButtonDown(Mouse_left)
	local mouse_just_up = InputIsMouseButtonJustUp(Mouse_left)
	for k, inventory in pairs(inventories) do
		if mouse_in_inventory(inventory) then
			to = k
		end
	end
	local cards = EntityGetWithTag("card_action")
	if inventory_open and (mouse_down or mouse_just_up) and mouse_move and (from == "ITEM" or to == "ITEM") then
		for _, card in ipairs(cards) do
			EntityAddTag(card, "this_is_sampo")
		end
		if not (from == "ITEM" and to == "ITEM") then
			for _, item in ipairs(items) do
				if item_is_spell(item) then
					EntityRemoveTag(item, "this_is_sampo")
				end
			end
		end
		if from == "ITEM" and to == "SPELL" and mouse_just_up then
			local active_item = get_active_item(player)
			if active_item ~= nil and not item_is_wand(active_item) then
				EntityAddComponent2(active_item, "LuaComponent", {
					_tags = "enabled_in_world",
					_enabled = false,
					remove_after_executed = true,
					script_enabled_changed = "mods/noita_inventory/files/item_check.lua",
				})
				EntityAddComponent2(active_item, "LuaComponent", {
					_tags = "enabled_in_world",
					script_source_file = "mods/noita_inventory/files/item_disable.lua",
					remove_after_executed = true,
				})
			end
		end
	else
		for _, card in ipairs(cards) do
			EntityRemoveTag(card, "this_is_sampo")
		end
	end
end
