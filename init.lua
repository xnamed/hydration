
-- =============================================================================
-- HYDRATION MOD: CORE ENGINE 
-- =============================================================================

-- Load user configurations first
dofile(minetest.get_modpath("hydration") .. "/config.lua")

local storage = minetest.get_mod_storage()
local THIRST_MAX = hydration_config.thirst_max
local player_huds = {}
local player_text_huds = {}

-- Global tracker data functions accessible to other sub-files
function get_thirst(player)
    local name = player:get_player_name()
    local val = storage:get_float(name .. "_thirst")
    if val == 0 and not storage:get_string(name .. "_thirst") then
        return THIRST_MAX
    end
    return val
end

function set_thirst(player, value)
    local name = player:get_player_name()
    if value > THIRST_MAX then value = THIRST_MAX end
    if value < 0 then value = 0 end
    storage:set_float(name .. "_thirst", value)
end

-- =============================================================================
-- THE VISUAL STATUS BAR HUD SYSTEM 
-- =============================================================================

minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    
    -- Ensure player data key storage exists in database immediately
    if storage:get_string(name .. "_thirst") == "" then
        set_thirst(player, THIRST_MAX)
    end
    
    -- DELAY WINDOW LOGIC: Wait 0.1 seconds for engine sync before drawing HUD
    minetest.after(0.1, function()
        -- Verify player didn't disconnect inside the 0.1s delay window
        local current_player = minetest.get_player_by_name(name)
        if not current_player then return end
        
        local thirst_val = get_thirst(current_player)
        local display_drops = math.ceil(thirst_val)
        if display_drops > 20 then display_drops = 20 end
        if display_drops < 0 then display_drops = 0 end
        
        -- 1. DRAW WATER DROP ICONS BAR (Now loads instantly at the perfect value!)
        local icon_hud_id = current_player:hud_add({
            hud_elem_type = "statbar",                               
            max = 20,                          
            size = { x = 24, y = 24 },         
            text = "hydration_drop_icon.png",   
            offset = { x = -261, y = -114 },
            number = display_drops,                
            position = { x = 0.497, y = 1 }, 
            alignment = { x = 0, y = 1 },      
        })
        player_huds[name] = icon_hud_id

        -- 2. FLOATING TEXT NUMBERS VALUE
        local text_hud_id = current_player:hud_add({
            hud_elem_type = "text",
            position = { x = 0.5, y = 1.0 },      
            offset =  { x = 51, y = -100 },   
            text = "Hydration: " .. string.format("%.1f", thirst_val) .. " / " .. THIRST_MAX,
            number = 0x32A4DB,                 
            alignment = { x = 0, y = 0 },
            scale = { x = 100, y = 100 },
        })
        player_text_huds[name] = text_hud_id
    end)
end)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    player_huds[name] = nil
    player_text_huds[name] = nil
end)

-- Background loop: Drains water drop parameters every 2 seconds based on exact movement states
local timer = 0
minetest.register_globalstep(function(dtime)
    timer = timer + dtime
    if timer < 2.0 then return end
    timer = 0

    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local thirst = get_thirst(player)
        local controls = player:get_player_control()
        
        -- Get player's current speed/velocity vectors
        local vel = player:get_velocity()
        local is_moving = false
        if vel then
            -- Calculate horizontal movement speed across the X and Z axes
            local speed = math.sqrt(vel.x * vel.x + vel.z * vel.z)
            if speed > 0.1 then
                is_moving = true
            end
        end
        
        -- Determine exact drain multiplier based on your config priorities
        local drain = hydration_config.drain_idle_standing -- Default: Completely Still
        
        if controls.dig or controls.jump then 
            drain = hydration_config.drain_exertion        -- Digging/Jumping (Heavy Exertion)
        elseif is_moving then
            drain = hydration_config.drain_idle_walking     -- Walking around normally
        end
        
        local new_thirst = thirst - drain
        set_thirst(player, new_thirst)
        
        -- Recalculate target drops remaining (0 to 10 scale)
        local drops_remaining = math.ceil(new_thirst)
        if drops_remaining > 20 then drops_remaining = 20 end
        if drops_remaining < 0 then drops_remaining = 0 end
        
        local icon_hud = player_huds[name]
        if icon_hud then
            player:hud_change(icon_hud, "number", tonumber(drops_remaining))
        end

        -- Update text parameters strings smoothly
        local text_hud = player_text_huds[name]
        if text_hud then
            player:hud_change(text_hud, "text", "Hydration: " .. string.format("%.1f", new_thirst) .. " / " .. THIRST_MAX)
        end

        if new_thirst <= 0 then
            player:set_hp(player:get_hp() - 1)
            minetest.chat_send_player(name, "You are dying of thirst! Find water!")
        end
    end
end)

-- =============================================================================
-- RESPAWN & DEATH RESET LOGIC
-- =============================================================================
minetest.register_on_respawnplayer(function(player)
    set_thirst(player, THIRST_MAX)
    local name = player:get_player_name()
    
    local icon_hud = player_huds[name]
    if icon_hud then 
        player:hud_change(icon_hud, "number", THIRST_MAX) -- Restores back to full 20 points (10 icons)
    end
    
    local text_hud = player_text_huds[name]
    if text_hud then 
        player:hud_change(text_hud, "text", "Hydration: 20.0 / " .. THIRST_MAX) 
    end
    
    minetest.chat_send_player(name, "Hydration level has been restored!")
end)

-- LOAD MODULAR BLOCKS AND CONTAINER SUB-FILES
dofile(minetest.get_modpath("hydration") .. "/blocks.lua")
dofile(minetest.get_modpath("hydration") .. "/containers.lua")
