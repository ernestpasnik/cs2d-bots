--------------------------------------------------
-- Modernized bot AI for CS2D
--------------------------------------------------

dofile("bots/includes/settings.lua")
dofile("bots/includes/general.lua")
dofile("bots/includes/buy.lua")
dofile("bots/includes/decide.lua")
dofile("bots/includes/engage.lua")
dofile("bots/includes/fight.lua")
dofile("bots/includes/follow.lua")
dofile("bots/includes/collect.lua")
dofile("bots/includes/radio.lua")
dofile("bots/includes/bomb.lua")
dofile("bots/includes/hostages.lua")

--------------------------------------------------
-- Cached Settings
--------------------------------------------------

vai_set_gm         = 0
vai_set_botskill   = 0
vai_set_botweapons = 0
vai_set_debug      = 0
fai_update_settings()

--------------------------------------------------
-- Per-Player State Tables
--------------------------------------------------

local N = 32

local function newtable(default)
    local t = {}
    for i = 1, N do t[i] = default end
    return t
end

vai_mode        = newtable(-1)
vai_smode       = newtable(0)
vai_timer       = newtable(0)
vai_destx       = newtable(0)
vai_desty       = newtable(0)
vai_aimx        = newtable(0)
vai_aimy        = newtable(0)
vai_px          = newtable(0)
vai_py          = newtable(0)
vai_target      = newtable(0)
vai_reaim       = newtable(0)
vai_rescan      = newtable(0)
vai_itemscan    = newtable(0)
vai_buyingdone  = newtable(0)
vai_radioanswer = newtable(0)
vai_radioanswert= newtable(0)

--------------------------------------------------
-- Mode Handlers (dispatch table)
--------------------------------------------------

local MODE = {}

MODE[0] = function(id)
    vai_timer[id] = 0
    vai_smode[id] = 0
    fai_decide(id)
end

MODE[1] = function(id)
    fai_wait(id, 0)
end

MODE[2] = function(id)
    if ai_goto(id, vai_destx[id], vai_desty[id]) ~= 2 then
        vai_mode[id] = 0
    else
        fai_walkaim(id)
    end
end

MODE[3] = function(id)
    if ai_move(id, vai_smode[id]) == 0 then
        vai_smode[id] = vai_smode[id] + ((id % 2 == 0) and 45 or -45)
        vai_timer[id] = math.random(150, 250)
    end
    fai_walkaim(id)
    fai_wait(id, 0)
end

MODE[4] = function(id)
    fai_fight(id)
end

MODE[5] = function(id)
    local tid = vai_smode[id]
    if player(tid, "exists") and player(tid, "health") > 0 then
        if ai_goto(id, player(tid, "tilex"), player(tid, "tiley")) ~= 2 then
            vai_mode[id] = 0
        end
    else
        vai_mode[id] = 0
    end
end

MODE[6] = function(id)
    if ai_goto(id, vai_destx[id], vai_desty[id]) ~= 2 then
        vai_mode[id]     = 0
        vai_itemscan[id] = 140
    else
        fai_walkaim(id)
    end
end

MODE[7] = function(id)
    fai_follow(id)
end

MODE[8] = function(id)
    if ai_goto(id, vai_destx[id], vai_desty[id]) ~= 2 then
        fai_randomadjacent(id)
    end
    if player(id, "ai_flash") == 0 then
        vai_mode[id] = 0
    end
end

MODE[50] = function(id) fai_rescuehostages(id) end
MODE[51] = function(id) fai_plantbomb(id) end
MODE[52] = function(id) fai_defuse(id) end

MODE[-1] = function(id) fai_buy(id) end

--------------------------------------------------
-- ai_onspawn
--------------------------------------------------

function ai_onspawn(id)
    fai_update_settings()

    local x = player(id, "x")
    local y = player(id, "y")
    local r = math.random

    vai_mode[id]         = -1
    vai_smode[id]        = 0
    vai_timer[id]        = r(1, 10)
    vai_destx[id]        = 0
    vai_desty[id]        = 0
    vai_aimx[id]         = x - 50 + r(0, 100)
    vai_aimy[id]         = y - 50 + r(0, 100)
    vai_px[id]           = x
    vai_py[id]           = y
    vai_target[id]       = 0
    vai_reaim[id]        = 0
    vai_rescan[id]       = 0
    vai_itemscan[id]     = 1000
    vai_buyingdone[id]   = 0
    vai_radioanswer[id]  = 0
    vai_radioanswert[id] = 0
end

--------------------------------------------------
-- ai_update_living
--------------------------------------------------

function ai_update_living(id)
    -- Engage handles aiming and target tracking
    fai_engage(id)

    -- Guard: bot may have died or been kicked during engage
    if not player(id, "exists")
    or player(id, "team") <= 0
    or player(id, "health") <= 0 then
        return
    end

    -- Radio answer countdown
    local rt = vai_radioanswert[id]
    if rt > 0 then
        rt = rt - 1
        vai_radioanswert[id] = rt
        if rt == 0 then
            ai_radio(id, vai_radioanswer[id])
            vai_radioanswer[id] = 0
        end
    end

    -- Item collection scan
    fai_collect(id)

    -- Debug overlay
    if vai_set_debug == 1 then
        ai_debug(id, ("m:%d sm:%d ta:%d ti:%d"):format(
            vai_mode[id], vai_smode[id], vai_target[id], vai_timer[id]))
    end

    -- Dispatch to mode handler
    local handler = MODE[vai_mode[id]]
    if handler then
        handler(id)
    else
        if vai_set_debug == 1 then
            print("invalid AI mode: " .. tostring(vai_mode[id]))
        end
        vai_mode[id] = 0
    end
end

--------------------------------------------------
-- ai_update_dead
--------------------------------------------------

function ai_update_dead(id)
    fai_update_settings()
    if vai_set_gm ~= 0 then
        ai_respawn(id)
    end
end

--------------------------------------------------
-- ai_hear_radio
--------------------------------------------------

function ai_hear_radio(source, radio)
    fai_radio(source, radio)
end

--------------------------------------------------
-- ai_hear_chat  (intentionally unused)
--------------------------------------------------

function ai_hear_chat(source, msg, teamonly) end
