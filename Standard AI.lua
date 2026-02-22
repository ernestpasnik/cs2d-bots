--------------------------------------------------
-- CS2D Standard Bot AI (Optimized)             --
--------------------------------------------------

-- Includes
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

vai_set_gm        = 0
vai_set_botskill  = 0
vai_set_botweapons= 0
vai_set_debug     = 0
fai_update_settings()

--------------------------------------------------
-- Per‑Player Variables
--------------------------------------------------

vai_mode, vai_smode      = {}, {}
vai_timer                 = {}
vai_destx, vai_desty      = {}, {}
vai_aimx, vai_aimy        = {}, {}
vai_px, vai_py            = {}, {}
vai_target                = {}
vai_reaim, vai_rescan     = {}, {}
vai_itemscan              = {}
vai_buyingdone            = {}
vai_radioanswer           = {}
vai_radioanswert          = {}

for i = 1, 32 do
    vai_mode[i]        = -1
    vai_smode[i]       = 0
    vai_timer[i]       = 0
    vai_destx[i]       = 0
    vai_desty[i]       = 0
    vai_aimx[i]        = 0
    vai_aimy[i]        = 0
    vai_px[i]          = 0
    vai_py[i]          = 0
    vai_target[i]      = 0
    vai_reaim[i]       = 0
    vai_rescan[i]      = 0
    vai_itemscan[i]    = 0
    vai_buyingdone[i]  = 0
    vai_radioanswer[i] = 0
    vai_radioanswert[i]= 0
end

--------------------------------------------------
-- ai_onspawn
--------------------------------------------------

function ai_onspawn(id)
    local p = player
    local r = math.random

    fai_update_settings()

    vai_mode[id]        = -1
    vai_smode[id]       = 0
    vai_timer[id]       = r(1, 10)
    vai_destx[id]       = 0
    vai_desty[id]       = 0

    local x = p(id, "x")
    local y = p(id, "y")

    vai_aimx[id]        = x - 50 + r(0, 100)
    vai_aimy[id]        = y - 50 + r(0, 100)
    vai_px[id]          = x
    vai_py[id]          = y
    vai_target[id]      = 0
    vai_reaim[id]       = 0
    vai_rescan[id]      = 0
    vai_itemscan[id]    = 1000
    vai_buyingdone[id]  = 0
    vai_radioanswer[id] = 0
    vai_radioanswert[id]= 0
end

--------------------------------------------------
-- ai_update_living
--------------------------------------------------

function ai_update_living(id)
    local p = player
    local r = math.random

    -- Engage / Aim
    fai_engage(id)

    -- Bot may have been killed or kicked
    if not p(id, "exists") then return end
    if p(id, "team") <= 0 or p(id, "health") <= 0 then return end

    -- Radio answer timer
    local rt = vai_radioanswert[id]
    if rt > 0 then
        rt = rt - 1
        vai_radioanswert[id] = rt
        if rt <= 0 then
            ai_radio(id, vai_radioanswer[id])
            vai_radioanswer[id]  = 0
            vai_radioanswert[id] = 0
        end
    end

    -- Collect items
    fai_collect(id)

    -- Debug output
    if vai_set_debug == 1 then
        ai_debug(id, "m:" .. vai_mode[id] ..
                     ", sm:" .. vai_smode[id] ..
                     " ta:" .. vai_target[id] ..
                     " ti:" .. vai_timer[id])
    end

    --------------------------------------------------
    -- State Machine
    --------------------------------------------------

    local mode = vai_mode[id]

    if mode == 0 then
        vai_timer[id] = 0
        vai_smode[id] = 0
        fai_decide(id)

    elseif mode == 1 then
        fai_wait(id, 0)

    elseif mode == 2 then
        local result = ai_goto(id, vai_destx[id], vai_desty[id])
        if result ~= 2 then
            vai_mode[id] = 0
        else
            fai_walkaim(id)
        end

    elseif mode == 3 then
        if ai_move(id, vai_smode[id]) == 0 then
            if (id % 2) == 0 then
                vai_smode[id] = vai_smode[id] + 45
            else
                vai_smode[id] = vai_smode[id] - 45
            end
            vai_timer[id] = r(150, 250)
        end
        fai_walkaim(id)
        fai_wait(id, 0)

    elseif mode == 4 then
        fai_fight(id)

    elseif mode == 5 then
        local tid = vai_smode[id]
        if p(tid, "exists") and p(tid, "health") > 0 then
            if ai_goto(id, p(tid, "tilex"), p(tid, "tiley")) ~= 2 then
                vai_mode[id] = 0
            end
            return
        end
        vai_mode[id] = 0

    elseif mode == 6 then
        if ai_goto(id, vai_destx[id], vai_desty[id]) ~= 2 then
            vai_mode[id] = 0
            vai_itemscan[id] = 140
        else
            fai_walkaim(id)
        end

    elseif mode == 7 then
        fai_follow(id)

    elseif mode == 8 then
        if ai_goto(id, vai_destx[id], vai_desty[id]) ~= 2 then
            fai_randomadjacent(id)
        end
        if p(id, "ai_flash") == 0 then
            vai_mode[id] = 0
        end

    elseif mode == 50 then
        fai_rescuehostages(id)

    elseif mode == 51 then
        fai_plantbomb(id)

    elseif mode == 52 then
        fai_defuse(id)

    elseif mode == -1 then
        fai_buy(id)

    else
        if vai_set_debug == 1 then
            print("invalid AI mode: " .. mode)
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
-- ai_hear_chat
--------------------------------------------------

function ai_hear_chat(source, msg, teamonly)
    -- ignored
end
