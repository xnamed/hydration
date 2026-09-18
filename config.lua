-- =============================================================================
-- HYDRATION MOD: CONFIGURATION SETTINGS
-- =============================================================================
hydration_config = {
    -- 💧 THIRST PARAMETERS
    thirst_max = 20,              -- Maximum hydration points (10 full drop icons)
    thirst_thirst_restore = 4,    -- Thirst points restored per single sip of water

    -- ⛏️ DEPLAYMENT RATES (Dtime adjustments every 2 seconds)
    drain_idle_standing = 0.02,   -- Thirst lost while completely standing still (very slow)
    drain_idle_walking = 0.06,    -- Thirst lost while walking around normally
    drain_exertion = 0.15,         -- Thirst lost while digging blocks or jumping (3x faster)

    -- 🏺 INVENTORY LIMITS
    jar_stack_max = 3,            -- Maximum stack size for filled water jars
    jar_max_sips = 3,             -- How many sips a fresh jar holds

    -- 🛢️ CISTERN / BARREL LOGISTICS
    cistern_max_capacity = 50,    -- Maximum liters a storage barrel can hold
    jar_liters_value = 5,         -- How many liters a full jar adds/removes (5L)
    bucket_liters_value = 25,     -- How many liters a bucket adds/removes (25L = 50%)

    -- 🛡️ ANTI-CHEAT ENGINE
    min_neighbor_sources = 4,     -- Minimum touching water blocks needed to scoop underground
}
