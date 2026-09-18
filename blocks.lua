
-- =============================================================================
-- BLOCKS.LUA: DYNAMIC PERCENTAGE-BASED CISTERN STATES
-- =============================================================================

-- Helper function to seamlessly swap node names based on dynamic volume percentages
local function update_cistern_state(pos, current_water)
    local meta = minetest.get_meta(pos)
    meta:set_int("water_level", current_water)
    
    local max_cap = hydration_config.cistern_max_capacity
    
    -- Calculate the current fluid level as a fraction/percentage (0.0 to 1.0)
    local fullness = current_water / max_cap
    
    local target_node = "hydration:clay_cistern" -- Default Empty
    
    if current_water > 0 then
        if fullness < 0.40 then
            target_node = "hydration:clay_cistern_low"    -- Under 40% Full
        elseif fullness >= 0.40 and fullness < 0.90 then
            target_node = "hydration:clay_cistern_half"   -- Between 40% and 90% Full
        elseif fullness >= 0.90 then
            target_node = "hydration:clay_cistern_full"   -- Over 90% Full
        end
    end
    
    minetest.swap_node(pos, {name = target_node})
    meta:set_string("infotext", "Stone Water Cistern (" .. current_water .. "/" .. max_cap .. "L)")
end

-- Shared right-click interactive loop
local function handle_cistern_click(pos, node, clicker, itemstack)
    if not clicker then return itemstack end
    local meta = minetest.get_meta(pos)
    local current_water = meta:get_int("water_level") or 0
    local item_name = itemstack:get_name()
    local max_cap = hydration_config.cistern_max_capacity
    
    -- 📥 CASE 1: Pouring Water In (Clay Jar -> Adds configuration value)
    if item_name == "hydration:clay_jar" then
        if current_water >= max_cap then
            minetest.chat_send_player(clicker:get_player_name(), minetest.colorize("#FF4545", "The Cistern is already full! (" .. max_cap .. "/" .. max_cap .. "L)"))
            return itemstack
        end
        
        local item_meta = itemstack:get_meta()
        local jar_sips = item_meta:get_int("sips")
        if jar_sips == 0 then jar_sips = hydration_config.jar_max_sips end
        
        local max_jar_val = hydration_config.jar_liters_value
        local liters_to_add = (jar_sips / hydration_config.jar_max_sips) * max_jar_val
        local new_water = math.floor(math.min(current_water + liters_to_add, max_cap) + 0.5)
        
        minetest.sound_play("hydration_pour", {pos = pos, gain = 0.8, max_hear_distance = 16})
        update_cistern_state(pos, new_water)
        minetest.chat_send_player(clicker:get_player_name(), minetest.colorize("#32A4DB", "Poured a jar with " .. jar_sips .. " sips left inside. Added " .. string.format("%.1f", liters_to_add) .. "L."))
        return ItemStack("hydration:clay_jar_empty")
        
    -- 📥 CASE 2: Pouring Water In (Water Bucket -> Adds configuration value)
    elseif item_name == "bucket:bucket_water" then
        if current_water >= max_cap then
            minetest.chat_send_player(clicker:get_player_name(), minetest.colorize("#FF4545", "The Cistern is already completely full! (" .. max_cap .. "/" .. max_cap .. "L)"))
            return itemstack
        end
        
        local bucket_val = hydration_config.bucket_liters_value
        local new_water = math.floor(math.min(current_water + bucket_val, max_cap) + 0.5)
        
        minetest.sound_play("hydration_pour", {pos = pos, gain = 1.0, max_hear_distance = 16})
        update_cistern_state(pos, new_water)
        minetest.chat_send_player(clicker:get_player_name(), minetest.colorize("#FF4545", "Dumped a massive bucket inside! Added " .. bucket_val .. "L. (" .. new_water .. "/" .. max_cap .. "L)"))
        return ItemStack("bucket:bucket_empty")

    -- 📤 CASE 3: Scooping Water Out (Clay Jar -> Handles partial refills dynamically)
    elseif item_name == "hydration:clay_jar_empty" then
        if current_water <= 0 then
            minetest.chat_send_player(clicker:get_player_name(), minetest.colorize("#FF4545", "The Cistern is completely dry."))
            return itemstack
        end
        
        local max_jar_val = hydration_config.jar_liters_value
        local liters_extracted = math.min(current_water, max_jar_val)
        local sips_gathered = math.floor((liters_extracted / max_jar_val) * hydration_config.jar_max_sips + 0.5)
        if sips_gathered < 1 then sips_gathered = 1 end 
        
        -- FIXED: Changed from max(0, ...) to math.max(0, ...)
        local new_water = math.floor(math.max(0, current_water - liters_extracted) + 0.5)
        
        minetest.sound_play("hydration_scoop", {pos = pos, gain = 0.8, max_hear_distance = 16})
        update_cistern_state(pos, new_water)
        
        local filled_jar = ItemStack("hydration:clay_jar")
        local jar_meta = filled_jar:get_meta()
        jar_meta:set_int("sips", sips_gathered)
        jar_meta:set_string("description", "Jar of Fresh Water (" .. sips_gathered .. "/" .. hydration_config.jar_max_sips .. " Sips)")
        
        minetest.chat_send_player(clicker:get_player_name(), minetest.colorize("#32A4DB", "Scooped " .. string.format("%.1f", liters_extracted) .. "L out of the barrel! Jar filled with " .. sips_gathered .. " sips."))
        return filled_jar

    -- 📤 CASE 4: Scooping Water Out (Empty Bucket -> Removes configuration value)
    elseif item_name == "bucket:bucket_empty" then
        local bucket_val = hydration_config.bucket_liters_value
        if current_water < bucket_val then
            minetest.chat_send_player(clicker:get_player_name(), minetest.colorize("#FF4545", "Not enough water level! A bucket requires at least " .. bucket_val .. "L to fill up."))
            return itemstack
        end
        
        local new_water = math.floor(math.max(0, current_water - bucket_val) + 0.5)
        
        minetest.sound_play("hydration_scoop", {pos = pos, gain = 1.0, max_hear_distance = 16})
        update_cistern_state(pos, new_water)
        minetest.chat_send_player(clicker:get_player_name(), minetest.colorize("#FF4545", "Filled up your bucket! Remaining Cistern water: " .. new_water .. "L"))
        return ItemStack("bucket:bucket_water")
    end

    
    return itemstack
end

local function handle_cistern_dig(pos, node, digger)
    if not digger then return end
    local meta = minetest.get_meta(pos)
    if (meta:get_int("water_level") or 0) > 0 then
        minetest.chat_send_player(digger:get_player_name(), minetest.colorize("#FF4545", "Too heavy to pick up! You must drain the water completely first."))
        return 
    end
    return minetest.node_dig(pos, node, digger)
end

-- --------------------------------================-----------------------------
-- REGISTER THE 4 DIFFERENT VISUAL CISTERN NODES
-- -----------------------------------------------------------------------------

minetest.register_node("hydration:clay_cistern", {
    description = "Stone Water Cistern",
    tiles = {"hydration_cistern_top_empty.png", "hydration_cistern_base.png", "hydration_cistern_base.png"},
    groups = {cracky = 3},
    on_construct = function(pos) minetest.get_meta(pos):set_string("infotext", "Stone Water Cistern (0/50L)") end,
    on_rightclick = handle_cistern_click,
    on_dig = handle_cistern_dig,
    can_dig = function(pos, player) return true end, 
})

minetest.register_node("hydration:clay_cistern_low", {
    description = "Stone Water Cistern",
    tiles = {"hydration_cistern_top_water.png", "hydration_cistern_base.png", "hydration_cistern_base.png"},
    groups = {cracky = 3, not_in_creative_inventory = 1},
    on_rightclick = handle_cistern_click,
    on_dig = handle_cistern_dig,
    can_dig = function(pos, player) return false end,
})

minetest.register_node("hydration:clay_cistern_half", {
    description = "Stone Water Cistern",
    tiles = {"hydration_cistern_top_water.png", "hydration_cistern_base.png", "hydration_cistern_base.png"},
    groups = {cracky = 3, not_in_creative_inventory = 1},
    on_rightclick = handle_cistern_click,
    on_dig = handle_cistern_dig,
    can_dig = function(pos, player) return false end,
})

minetest.register_node("hydration:clay_cistern_full", {
    description = "Stone Water Cistern",
    tiles = {"hydration_cistern_top_filled.png", "hydration_cistern_base.png", "hydration_cistern_base.png"},
    groups = {cracky = 3, not_in_creative_inventory = 1},
    on_rightclick = handle_cistern_click,
    on_dig = handle_cistern_dig,
    can_dig = function(pos, player) return false end,
})
