
minetest.register_craftitem("hydration:clay_jar_empty", {
    description = "Empty Clay Jar",
    inventory_image = "hydration_jar_empty.png",
    on_use = function(itemstack, user, pointed_thing)
        if not user then return itemstack end
        local pos, dir = user:get_pos(), user:get_look_dir()
        local eye_pos = {x = pos.x, y = pos.y + 1.62, z = pos.z}
        
        for i = 1, 4 do
            local check_pos = {x = eye_pos.x + dir.x * (i * 0.8), y = eye_pos.y + dir.y * (i * 0.8), z = eye_pos.z + dir.z * (i * 0.8)}
            local rounded_pos = {x = math.floor(check_pos.x + 0.5), y = math.floor(check_pos.y + 0.5), z = math.floor(check_pos.z + 0.5)}
            local node = minetest.get_node(rounded_pos)
            local node_def = minetest.registered_nodes[node.name]
            
            if node_def and (string.find(node.name, "water") or (node_def.groups and node_def.groups.liquid)) then
                
                -- ANTI-CHEAT: Puddles/Flowing blocks blocked
                if string.find(node.name, "flowing") then
                    minetest.chat_send_player(user:get_player_name(), minetest.colorize("#FF4545", "Flowing water is too shallow to scoop up!"))
                    
                    return itemstack
                end
                
                if rounded_pos.y < 2 then
                    local neighbor_water_count = 0
                    local scan_offsets = {{x=1,y=0,z=0}, {x=-1,y=0,z=0}, {x=0,y=0,z=1}, {x=0,y=0,z=-1}, {x=0,y=1,z=0}, {x=0,y=-1,z=0}}
                    for _, offset in ipairs(scan_offsets) do
                        local n_pos = {x = rounded_pos.x + offset.x, y = rounded_pos.y + offset.y, z = rounded_pos.z + offset.z}
                        local n_node = minetest.get_node(n_pos)
                        if string.find(n_node.name, "water") and not string.find(n_node.name, "flowing") then
                            neighbor_water_count = neighbor_water_count + 1
                        end
                    end
                    if neighbor_water_count < 4 then
                        minetest.chat_send_player(user:get_player_name(), minetest.colorize("#FF4545", "This pool is too small to gather water from."))
                        return itemstack
                    end
                end

                minetest.sound_play("hydration_scoop", {to_player = user:get_player_name(), gain = 0.8})
                
                -- Build a fresh filled jar item instance with your configuration sips
                local filled_jar = ItemStack("hydration:clay_jar")
                local max_sips = hydration_config.jar_max_sips
                local meta = filled_jar:get_meta()
                meta:set_int("sips", max_sips)
                meta:set_string("description", "Jar of Fresh Water (" .. max_sips .. "/" .. max_sips .. " Sips)")

                -- 🔒 SPACE-LOCK ENGINE: Keep the item exactly in the active hand slot if possible!
                local count = itemstack:get_count()
                
                if count == 1 then
                    -- If you were only holding a single empty jar, swap it instantly in your hand!
                    minetest.chat_send_player(user:get_player_name(), minetest.colorize("#32A4DB", "Filled jar with fresh water! (" .. max_sips .. " Sips)"))
                    return filled_jar
                else
                    -- If you are holding a whole stack of empty jars, subtract one from your hand
                    itemstack:take_item()
                    local inv = user:get_inventory()
                    
                    -- Look through the main pack slots to enforce your jar_stack_max = 3 rule
                    local main_list = inv:get_list("main")
                    local added_to_existing_stack = false
                    
                    for idx, stack in ipairs(main_list) do
                        if stack:get_name() == "hydration:clay_jar" then
                            local stack_meta = stack:get_meta()
                            if stack_meta:get_int("sips") == max_sips and stack:get_count() < hydration_config.jar_stack_max then
                                stack:set_count(stack:get_count() + 1)
                                inv:set_stack("main", idx, stack)
                                added_to_existing_stack = true
                                break
                            end
                        end
                    end
                    
                    -- If existing stacks are full, put it in the first open inventory box
                    if not added_to_existing_stack then
                        if inv:room_for_item("main", filled_jar) then
                            inv:add_item("main", filled_jar)
                        else
                            minetest.item_drop(filled_jar, user, user:get_pos())
                        end
                    end

                    minetest.chat_send_player(user:get_player_name(), minetest.colorize("#32A4DB", "Filled jar with fresh water! (" .. max_sips .. " Sips)"))
                    return itemstack
                end
            end
        end
        return itemstack
    end,
})

minetest.register_craftitem("hydration:clay_jar", {
    description = "Jar of Fresh Water",
    inventory_image = "hydration_jar.png",
    
    -- 🔒 GLOBAL HOOK: Automatically tells Luanti the maximum stack size
    -- for manual dragging and inventory chest shifting!
    groups = { NotInCreativeInventory = 0 }, 
    
    -- We can force Luanti to redefine the item's stack max on runtime boot:
    stack_max = hydration_config.jar_stack_max, 

    on_use = function(itemstack, user, pointed_thing)
        local name = user:get_player_name()
        local current = get_thirst(user)
        if current >= 20 then
            minetest.chat_send_player(name, "You aren't thirsty right now.")
            return itemstack
        end
        
        local meta = itemstack:get_meta()
        local sips = meta:get_int("sips")
        if sips == 0 then sips = hydration_config.jar_max_sips end 
        
        local restored_points = hydration_config.thirst_thirst_restore
        set_thirst(user, math.min(current + restored_points, 20))
        minetest.sound_play("hydration_drink", {to_player = name, gain = 1.0})
        
        sips = sips - 1
        if sips <= 0 then
            minetest.chat_send_player(name, "")
            minetest.chat_send_player(name, minetest.colorize("#32A4DB", "Gulp... you drank the last drop!"))
            return ItemStack("hydration:clay_jar_empty") 
        else
            minetest.chat_send_player(name, minetest.colorize("#32A4DB", "Gulp... refreshed! (" .. sips .. "/" .. hydration_config.jar_max_sips .. " Sips left)"))
            meta:set_int("sips", sips)
            meta:set_string("description", "Jar of Fresh Water (" .. sips .. "/" .. hydration_config.jar_max_sips .. " Sips)")
            return itemstack
        end
    end,
})


minetest.register_craftitem("hydration:unbaked_jar", {
    description = "Unbaked Clay Jar",
    inventory_image = "hydration_jar_empty.png^[colorize:#707070:150",
})

-- RECIPES
minetest.register_craft({
    output = "hydration:unbaked_jar",
    recipe = {{"default:clay_lump", "", "default:clay_lump"}, {"", "default:clay_lump", ""}, {"", "", ""}}
})
minetest.register_craft({ type = "cooking", output = "hydration:clay_jar_empty", recipe = "hydration:unbaked_jar", cooktime = 3 })
minetest.register_craft({
    output = "hydration:clay_cistern",
    recipe = {{"default:clay_brick", "", "default:clay_brick"}, {"default:clay_brick", "", "default:clay_brick"}, {"default:clay_brick", "default:clay_brick", "default:clay_brick"}}
})
minetest.register_craft({
    type = "shapeless", output = "hydration:clay_jar", recipe = { "hydration_jar_empty.png" },
    infotext = "ℹ️ Look/punch at a water node while holding the empty jar to fill it!"
})
