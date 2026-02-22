dofile("bots/includes/core.lua")
dofile("bots/includes/combat.lua")
dofile("bots/includes/objectives.lua")
dofile("bots/includes/movement.lua")
dofile("bots/includes/tactics.lua")

local function newtable(default)
    local t = {}
    for i = 1, MAX_PLAYERS do t[i] = default end
    return t
end

-- Core state
vai_mode         = newtable(-1)
vai_smode        = newtable(0)
vai_timer        = newtable(0)
vai_destx        = newtable(0)
vai_desty        = newtable(0)
vai_aimx         = newtable(0)
vai_aimy         = newtable(0)
vai_px           = newtable(0)
vai_py           = newtable(0)
vai_target       = newtable(0)
vai_reaim        = newtable(0)
vai_rescan       = newtable(0)
vai_itemscan     = newtable(0)
vai_buyingdone   = newtable(0)
vai_radioanswer  = newtable(0)
vai_radioanswert = newtable(0)
vai_followangle  = newtable(0)

-- Human-like behaviour state (initialised by fai_init_humanstate in core.lua)
vai_personality  = newtable(PERSONALITY_BALANCED)
vai_react_delay  = newtable(REACT_TICKS_MED)
vai_aim_smooth   = newtable(AIM_SMOOTH_MED)
vai_burst_size   = newtable(BURST_SIZE_MAX)
vai_burst_pause  = newtable(0)
vai_spray_drift  = newtable(0)
vai_shot_count   = newtable(0)
vai_is_moving    = newtable(0)
vai_lkp_x        = newtable(0)
vai_lkp_y        = newtable(0)
vai_lkp_timer    = newtable(0)
vai_peek_state   = newtable(0)
vai_peek_timer   = newtable(0)
vai_crouch_timer = newtable(0)
vai_react_timer  = newtable(0)

fai_update_settings()

local MODE = {}

MODE[-1] = function(id) fai_buy(id) end

MODE[0] = function(id)
    vai_timer[id] = 0
    vai_smode[id] = 0
    fai_decide(id)
end

MODE[1] = function(id) fai_wait(id, 0) end

MODE[2] = function(id)
    local result = ai_goto(id, vai_destx[id], vai_desty[id])
    if result ~= 2 then
        -- Arrived (or blocked); optional hesitation before re-deciding
        if result == 1 and fai_maybehesitate(id) then
            return  -- wait mode set inside fai_maybehesitate
        end
        vai_mode[id] = 0
    else
        fai_walkaim(id)
        vai_is_moving[id] = 1
    end
end

MODE[3] = function(id)
    if ai_move(id, vai_smode[id]) == 0 then
        -- Blocked: alternate nudge direction per bot ID
        vai_smode[id] = vai_smode[id] + ((id % 2 == 0) and 45 or -45)
        vai_timer[id] = math.random(150, 250)
    end
    vai_is_moving[id] = 1
    fai_walkaim(id)
    fai_wait(id, 0)
end

MODE[4] = function(id) fai_fight(id) end

-- Mode 5 is now handled by fai_hunt() in combat.lua (supports both player ID and LKP)
MODE[5] = function(id) fai_hunt(id) end

MODE[6] = function(id)
    local result = ai_goto(id, vai_destx[id], vai_desty[id])
    if result ~= 2 then
        vai_mode[id]     = 0
        vai_itemscan[id] = COLLECT_SCAN_PERIOD  -- brief cooldown before scanning again
    else
        fai_walkaim(id)
        vai_is_moving[id] = 1
    end
end

MODE[7]  = function(id) fai_follow(id) end

MODE[8] = function(id)
    if ai_goto(id, vai_destx[id], vai_desty[id]) ~= 2 then
        fai_randomadjacent(id)
    end
    vai_is_moving[id] = 1
    if player(id, "ai_flash") == 0 then vai_mode[id] = 0 end
end

MODE[50] = function(id) fai_rescuehostages(id) end
MODE[51] = function(id) fai_plantbomb(id) end
MODE[52] = function(id) fai_defuse(id) end

-- ============================================================
-- SPAWN
-- ============================================================

function ai_onspawn(id)
    fai_update_settings()

    local x   = player(id, "x")
    local y   = player(id, "y")
    local rnd = math.random

    -- Core state
    vai_mode[id]         = -1
    vai_smode[id]        = 0
    vai_timer[id]        = rnd(1, 10)
    vai_destx[id]        = 0
    vai_desty[id]        = 0
    vai_aimx[id]         = x - 50 + rnd(0, 100)
    vai_aimy[id]         = y - 50 + rnd(0, 100)
    vai_px[id]           = x
    vai_py[id]           = y
    vai_target[id]       = 0
    vai_reaim[id]        = 0
    vai_rescan[id]       = 0
    vai_itemscan[id]     = 1000  -- triggers an immediate scan on first tick
    vai_buyingdone[id]   = 0
    vai_radioanswer[id]  = 0
    vai_radioanswert[id] = 0
    vai_followangle[id]  = 0

    -- Initialise personality and all human-like behaviour state
    fai_init_humanstate(id)
end

-- ============================================================
-- MAIN UPDATE LOOP
-- ============================================================

function ai_update_living(id)
    fai_engage(id)

    -- Bot may have died or been kicked during fai_engage
    if not player(id, "exists") or player(id, "team") <= 0 or player(id, "health") <= 0 then
        return
    end

    -- Fire scheduled radio replies
    local rt = vai_radioanswert[id]
    if rt > 0 then
        rt = rt - 1
        vai_radioanswert[id] = rt
        if rt == 0 then
            ai_radio(id, vai_radioanswer[id])
            vai_radioanswer[id] = 0
        end
    end

    fai_collect(id)

    if vai_set_debug == 1 then
        ai_debug(id, ("m:%d sm:%d ta:%d ti:%d pers:%d drift:%.1f"):format(
            vai_mode[id], vai_smode[id], vai_target[id], vai_timer[id],
            vai_personality[id] or 0, vai_spray_drift[id] or 0))
    end

    local handler = MODE[vai_mode[id]]
    if handler then
        handler(id)
    else
        if vai_set_debug == 1 then print("invalid AI mode: " .. tostring(vai_mode[id])) end
        vai_mode[id] = 0
    end
end

function ai_update_dead(id)
    fai_update_settings()
    if vai_set_gm ~= 0 then ai_respawn(id) end
end

function ai_hear_radio(source, radio)
    fai_radio(source, radio)
end

function ai_hear_chat(source, msg, teamonly) end