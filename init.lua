dofile_once("mods/noita_inventory/files/sult.lua")
dofile_once("mods/noita_inventory/NoitaPatcher/load.lua")
dofile_once("data/scripts/debug/keycodes.lua")

local np = require("noitapatcher")

function get_player()
	return get_players()[1]
end

function get_magic_numbers_number(key)
	return tonumber(MagicNumbersGetValue(key))
end

gui = GuiCreate()
function get_image_dimensions(filename)
	return GuiGetImageDimensions(gui, filename)
end

function get_full_inventory_slots(player)
	local inventory = EntityGetFirstComponent(player, "Inventory2Component")
	return inventory and ComponentGetValue2(inventory, "full_inventory_slots_x"),
		inventory and ComponentGetValue2(inventory, "full_inventory_slots_y")
end

function Inventory(x, y, box_w, box_h, slots_x, slots_y)
	return {
		x = x,
		y = y,
		box_w = box_w,
		box_h = box_h,
		slots_x = slots_x,
		slots_y = slots_y,
	}
end

function get_inventories(player)
	local UI_BARS_POS_X = get_magic_numbers_number("UI_BARS_POS_X")
	local UI_BARS_POS_Y = get_magic_numbers_number("UI_BARS_POS_Y")
	local UI_QUICKBAR_OFFSET_X = get_magic_numbers_number("UI_QUICKBAR_OFFSET_X")
	local UI_QUICKBAR_OFFSET_Y = get_magic_numbers_number("UI_QUICKBAR_OFFSET_Y")
	local UI_FULL_INVENTORY_OFFSET_X = get_magic_numbers_number("UI_FULL_INVENTORY_OFFSET_X")
	local UI_QUICKBAR_POS_X = UI_BARS_POS_X + UI_QUICKBAR_OFFSET_X
	local UI_QUICKBAR_POS_Y = UI_BARS_POS_Y + UI_QUICKBAR_OFFSET_Y

	local quick_inventory_box_w, quick_inventory_box_h = get_image_dimensions("data/ui_gfx/inventory/quick_inventory_box.png")
	local full_inventory_box_w, full_inventory_box_h = get_image_dimensions("data/ui_gfx/inventory/full_inventory_box.png")

	local full_inventory_slots_x, full_inventory_slots_y = get_full_inventory_slots(player)

	return {
		WAND = Inventory(
			UI_QUICKBAR_POS_X - 1, UI_QUICKBAR_POS_Y,
			quick_inventory_box_w, quick_inventory_box_h,
			4, 1
		),
		ITEM = Inventory(
			UI_QUICKBAR_POS_X + quick_inventory_box_w * 4, UI_QUICKBAR_POS_Y,
			quick_inventory_box_w, quick_inventory_box_h,
			4, 1
		),
		SPELL = Inventory(
			UI_BARS_POS_X + UI_FULL_INVENTORY_OFFSET_X, UI_BARS_POS_Y,
			full_inventory_box_w, full_inventory_box_h,
			full_inventory_slots_x, full_inventory_slots_y
		),
	}
end

function mouse_in_inventory(inventory)
	local mouse_x, mouse_y = InputGetMousePosOnScreen()
	return point_in_rectangle(
		mouse_x / 2, mouse_y / 2,
		inventory.x, inventory.y,
		inventory.x + inventory.box_w * inventory.slots_x, inventory.y + inventory.box_h * inventory.slots_y
	)
end

function get_current_slot(inventories)
	local name
	local slot_x
	local slot_y
	local mouse_x, mouse_y = InputGetMousePosOnScreen()
	for k, inventory in pairs(inventories) do
		if mouse_in_inventory(inventory) then
			name = k
			slot_x = math.floor((mouse_x / 2 - inventory.x) / inventory.box_w)
			slot_y = math.floor((mouse_y / 2 - inventory.y) / inventory.box_h)
		end
	end
	return name, slot_x, slot_y
end

function get_quick_inventory(player)
	local children = get_children(player)
	return children[table.find(children, function(child)
		return EntityGetName(child) == "inventory_quick"
	end)]
end

function get_active_item(player)
	local inventory = EntityGetFirstComponent(player, "Inventory2Component")
	return inventory and validate_entity(ComponentGetValue2(inventory, "mActiveItem"))
end

function item_is_wand(item)
	local ability = EntityGetFirstComponentIncludingDisabled(item, "AbilityComponent")
	return ability and ComponentGetValue2(ability, "use_gun_script") or false
end

function item_is_spell(item)
	return EntityGetFirstComponentIncludingDisabled(item, "ItemActionComponent") ~= nil
end

function OnWorldPreUpdate()
	local player = get_player()
	if player == nil then return end

	local inventory_open = GameIsInventoryOpen()
	local mouse_down = InputIsMouseButtonDown(Mouse_left)
	local mouse_just_down = InputIsMouseButtonJustDown(Mouse_left)
	local mouse_just_up = InputIsMouseButtonJustUp(Mouse_left)

	local inventories = get_inventories(player)
	local mouse_to_x, mouse_to_y = InputGetMousePosOnScreen()
	if mouse_just_down then
		mouse_from_x = mouse_to_x
		mouse_from_y = mouse_to_y
		from, from_x, from_y = get_current_slot(inventories)
		mouse_drag = false
	elseif mouse_from_x ~= nil and mouse_from_y ~= nil and get_distance2(mouse_to_x, mouse_to_y, mouse_from_x, mouse_from_y) >= 16 then
		mouse_drag = true
	end
	local to, to_x, to_y = get_current_slot(inventories)

	local controls = EntityGetFirstComponent(player, "ControlsComponent")
	local inventory = EntityGetFirstComponent(player, "Inventory2Component")
	local gui = EntityGetFirstComponent(player, "InventoryGuiComponent")
	local inventory_items = get_inventory_items(player)
	local quick_inventory = get_quick_inventory(player)
	local quick_items = get_children(quick_inventory)
	local cards = EntityGetWithTag("card_action")

	for _, card in ipairs(cards) do
		EntityRemoveTag(card, "this_is_sampo")
	end
	for _, item in ipairs(inventory_items) do
		if not item_is_wand(item) and not item_is_spell(item) then
			EntityRemoveTag(item, "this_is_sampo")
		end
	end
	if inventory_open and (mouse_down or mouse_just_up) then
		if mouse_drag then
			if (from == "SPELL" or from == "") and to == "ITEM" or from == "ITEM" and (to == "SPELL" or to == "") then
				for _, card in ipairs(cards) do
					if EntityGetParent(card) ~= quick_inventory then
						EntityAddTag(card, "this_is_sampo")
					end
				end
			end
			if mouse_just_up and (from == "ITEM" and to == "SPELL" or from == "SPELL" and to == "ITEM") then
				local active_item = get_active_item(player)
				if active_item ~= nil and not item_is_wand(active_item) and not item_is_spell(active_item) then
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
		end
		if mouse_drag and (from == "ITEM" and to == "SPELL" or from == "SPELL" and to == "ITEM" and mouse_just_up) or from == "SPELL" and to == "SPELL" then
			for _, item in ipairs(inventory_items) do
				if not item_is_wand(item) and not item_is_spell(item) then
					EntityAddTag(item, "this_is_sampo")
				end
			end
		end
		if mouse_drag and mouse_just_up and (from == "WAND" and to == "ITEM" or from == "ITEM" and to == "WAND") and inventory ~= nil and gui ~= nil then
			local wands_item
			local items_item
			for _, item in ipairs(quick_items) do
				local item_component = EntityGetFirstComponentIncludingDisabled(item, "ItemComponent")
				if item_component ~= nil then
					local slot_x, slot_y = ComponentGetValue2(item_component, "inventory_slot")
					if item_is_wand(item) and wands_item == nil then
						if from == "WAND" then
							if slot_x == from_x then
								wands_item = item
							end
						elseif slot_x == to_x then
							wands_item = item
						end
					elseif not item_is_wand(item) and items_item == nil then
						if from == "WAND" then
							if slot_x == to_x then
								items_item = item
							end
						elseif slot_x == from_x then
							items_item = item
						end
					end
				end
			end
			if wands_item ~= nil then
				local ability = EntityGetFirstComponentIncludingDisabled(wands_item, "AbilityComponent")
				if ability ~= nil then
					ComponentSetValue2(ability, "use_gun_script", false)
					if EntityHasTag(wands_item, "wand") then
						ComponentSetValue2(ability, "click_to_use", false)
					end
				end
				local item = EntityGetFirstComponentIncludingDisabled(wands_item, "ItemComponent")
				if item ~= nil then
					ComponentSetValue2(item, "inventory_slot", from == "WAND" and to_x or from_x, 0)
				end
			end
			if items_item ~= nil then
				local ability = EntityGetFirstComponentIncludingDisabled(items_item, "AbilityComponent")
				if ability ~= nil then
					ComponentSetValue2(ability, "use_gun_script", true)
					if EntityHasTag(items_item, "wand") then
						ComponentSetValue2(ability, "click_to_use", true)
					end
				end
				local item = EntityGetFirstComponentIncludingDisabled(items_item, "ItemComponent")
				if item ~= nil then
					ComponentSetValue2(item, "inventory_slot", from == "WAND" and from_x or to_x, 0)
				end
			end
			if wands_item ~= nil and items_item ~= nil then
				EntityRemoveComponent(player, gui)
				gui = EntityAddComponent2(player, "InventoryGuiComponent")
				ComponentSetValue2(gui, "mActive", true)
				ComponentSetValue2(gui, "mBackgroundOverlayAlpha", 0.5)
			end
		end
	end

	if controls ~= nil and inventory ~= nil and ComponentGetValue2(controls, "mButtonDownFire") then
		local item = ComponentGetValue2(inventory, "mActiveItem")
		local x, y = EntityGetTransform(player)
		local target_x, target_y = DEBUG_GetMouseWorld()
		local ability = EntityGetFirstComponentIncludingDisabled(item, "AbilityComponent")
		if ability ~= nil then
			local use_gun_script = ComponentGetValue2(ability, "use_gun_script")
			if not use_gun_script and EntityHasTag(item, "wand") then
				ComponentSetValue2(ability, "use_gun_script", true)
				np.UseItem(player, item, false, true, ComponentGetValue2(controls, "mButtonFrameFire") == GameGetFrameNum(), x, y, target_x, target_y)
				ComponentSetValue2(ability, "use_gun_script", false)
			end
		end
	end
end
