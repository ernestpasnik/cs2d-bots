-- tactics.lua: buy sequence, round decision-making, and radio responses

local r = math.random
local p = player

------------------------------------------------------------------------
-- BUY SEQUENCE
-- fai_buy steps through BUY_STEPS one entry per tick (with a short
-- random delay between each).  vai_smode tracks the current step index.
------------------------------------------------------------------------

local BUY_STEPS = {
    -- Step 0: primary weapon or primary ammo if we already have one
    function(id, money, team, weapons)
        if fai_contains(weapons, WPN_AK47) or fai_contains(weapons, WPN_M4A1) then
            if money >= 50 then ai_buy(id, AMMO_PRIMARY) end
        elseif team == 1 then
            if money >= 3250 then ai_buy(id, WPN_AK47) end
        else
            if money >= 3850 then ai_buy(id, WPN_M4A1) end
        end
    end,
    -- Step 1: armor (cautious bots always buy; others skip if broke)
    function(id, money)
        local pers = vai_personality[id] or PERSONALITY_BALANCED
        if     money >= 1000 then
            ai_buy(id, ARMOR_FULL)
        elseif money >= 650  then
            ai_buy(id, ARMOR_KEVLAR)
        elseif money >= 350 and pers == PERSONALITY_CAUTIOUS then
            ai_buy(id, ARMOR_KEVLAR)
        end
    end,
    -- Step 2: HE grenade (probability varies by personality)
    function(id, money)
        local pers = vai_personality[id] or PERSONALITY_BALANCED
        local chance
        if     pers == PERSONALITY_AGGRESSIVE then chance = 40
        elseif pers == PERSONALITY_SUPPORT    then chance = 35
        else                                       chance = 20
        end
        if money >= 300 and r(0, 99) < chance then
            ai_buy(id, WPN_GRENADE)
        end
    end,
    -- Step 3: secondary ammo
    function(id, money)
        if money >= 50 then ai_buy(id, AMMO_SECONDARY) end
    end,
    -- Step 4: switch to knife for full run speed
    function(id, _, _, weapons)
        if fai_contains(weapons, WPN_KNIFE) then
            ai_selectweapon(id, WPN_KNIFE)
        end
    end,
}
local BUY_STEPS_MAX = #BUY_STEPS

function fai_buy(id)
    if vai_timer[id] > 0 then
        vai_timer[id] = vai_timer[id] - 1
        return
    end

    local step = vai_smode[id] + 1  -- vai_smode is 0-based; table is 1-based
    if step <= BUY_STEPS_MAX then
        BUY_STEPS[step](id, p(id, "money"), p(id, "team"), playerweapons(id))
    end

    vai_smode[id] = vai_smode[id] + 1
    vai_timer[id] = r(1, 5)

    if vai_smode[id] >= BUY_STEPS_MAX then
        vai_mode[id]       = 0
        vai_smode[id]      = 0
        vai_buyingdone[id] = 1
    end
end

------------------------------------------------------------------------
-- HELPERS
------------------------------------------------------------------------

local function setdest(id, ent, mode)
    local x, y = randomentity(ent)
    if x == NO_ENTITY then return false end
    vai_destx[id] = x
    vai_desty[id] = y
    vai_mode[id]  = mode or 2
    return true
end

-- Prefers bot-node paths (33% chance) for natural movement
local function gotoBotNodeOrSpawn(id, spawn)
    if map("botnodes") > 0 and r(0, 2) == 1 then
        setdest(id, ENT_BOT_NODE)
    else
        setdest(id, spawn)
    end
end

local function roam(id)
    vai_mode[id]  = 3
    vai_timer[id] = r(150, 300)
    vai_smode[id] = r(0, 360)
end

-- Locate the planted bomb item; returns pixel x, y or nil
local function findPlantedBomb()
    local items = item(0, "table")
    for i = 1, #items do
        local it = items[i]
        if item(it, "type") == ITEM_BOMB_PLANTED then
            return item(it, "x"), item(it, "y")
        end
    end
end

-- Personality-weighted push vs. patrol decision
local function shouldPush(id)
    local pers = vai_personality[id] or PERSONALITY_BALANCED
    local roll = r(1, 100)
    if     pers == PERSONALITY_AGGRESSIVE then return roll <= 70
    elseif pers == PERSONALITY_CAUTIOUS   then return roll <= 25
    elseif pers == PERSONALITY_SUPPORT    then return roll <= 40
    else                                       return roll <= 50
    end
end

-- Switch a T-side bot into bomb-guard mode, caching the bomb location.
local function enterGuardMode(id, bx, by)
    vai_mode[id]          = 53
    vai_smode[id]         = 0
    vai_timer[id]         = 0
    vai_bomb_guardx[id]   = bx
    vai_bomb_guardy[id]   = by
    vai_bomb_rescan[id]   = BOMB_CAMP_RESCAN
end

------------------------------------------------------------------------
-- DECISION LOGIC
------------------------------------------------------------------------

function fai_decide(id)
    local team = p(id, "team")

    -- Trigger the buy sequence on the first decision of each life
    if vai_buyingdone[id] ~= 1 then
        vai_mode[id]  = -1
        vai_smode[id] = 0
        vai_timer[id] = r(1, 10)
        return
    end

    -- Low-HP: look for health items before anything else
    if p(id, "health") < PANIC_HP_THRESHOLD then
        vai_itemscan[id] = COLLECT_SCAN_PERIOD + 1  -- force an item scan next tick
        gotoBotNodeOrSpawn(id, team == 1 and ENT_T_SPAWN or ENT_CT_SPAWN)
        return
    end

    -- Zombie mode (gm 4)
    if vai_set_gm == 4 then
        if team == 1 then
            if r(1, 3) <= 2 then gotoBotNodeOrSpawn(id, ENT_T_SPAWN)
            else setdest(id, ENT_CT_SPAWN) end
        else
            if r(1, 3) == 1 then setdest(id, ENT_CT_SPAWN)
            else gotoBotNodeOrSpawn(id, ENT_T_SPAWN) end
        end
        return
    end

    -- AS maps
    if map("mission_vips") > 0 then
        if team == 1 then
            if shouldPush(id) then
                if r(1,2) == 1 then setdest(id, ENT_VIP_SAFE)
                else gotoBotNodeOrSpawn(id, ENT_T_SPAWN) end
            else
                setdest(id, ENT_CT_SPAWN)
            end
        elseif team == 2 then
            if r(1, 2) == 1 then setdest(id, ENT_VIP_SAFE)
            else gotoBotNodeOrSpawn(id, ENT_CT_SPAWN) end
        else  -- VIP player
            if map("botnodes") > 0 and r(0, 2) == 1 then setdest(id, ENT_BOT_NODE)
            else setdest(id, ENT_VIP_SAFE) end
        end
        return
    end

    -- CS maps
    if map("mission_hostages") > 0 then
        if team == 1 then
            if shouldPush(id) then
                if r(1, 2) == 1 then setdest(id, ENT_RESCUE)
                else gotoBotNodeOrSpawn(id, ENT_T_SPAWN) end
            else
                if r(1, 2) == 1 then setdest(id, ENT_HOSTAGE)
                else gotoBotNodeOrSpawn(id, ENT_T_SPAWN) end
            end
        else
            if shouldPush(id) then
                local dx, dy = randomhostage(1)
                if dx ~= NO_ENTITY then
                    vai_destx[id] = dx
                    vai_desty[id] = dy
                    vai_mode[id]  = 50
                    vai_smode[id] = 0
                else
                    gotoBotNodeOrSpawn(id, ENT_CT_SPAWN)
                end
            else
                gotoBotNodeOrSpawn(id, ENT_CT_SPAWN)
            end
        end
        return
    end

    -- DE maps
    if map("mission_bombspots") > 0 then
        if team == 1 then
            -- Post-plant: if bomb is already planted, guard it instead of planting again
            if game("bombplanted") then
                local bx, by = findPlantedBomb()
                if bx then
                    enterGuardMode(id, bx, by)
                else
                    roam(id)
                end
                return
            end

            if shouldPush(id) then
                if not setdest(id, ENT_BOMBSPOT) then roam(id) return end
                if p(id, "bomb") then
                    vai_mode[id]  = 51
                    vai_smode[id] = 0
                    vai_timer[id] = 0
                end
            else
                gotoBotNodeOrSpawn(id, ENT_T_SPAWN)
            end
        else
            -- CT side
            if game("bombplanted") then
                -- Try to locate the actual bomb for a direct rush
                local bx, by = findPlantedBomb()
                if bx then
                    vai_destx[id] = bx
                    vai_desty[id] = by
                else
                    setdest(id, ENT_BOMBSPOT)
                end
                vai_mode[id]  = 52
                vai_smode[id] = 0
                vai_timer[id] = 0
            elseif shouldPush(id) then
                setdest(id, ENT_BOMBSPOT)
            else
                gotoBotNodeOrSpawn(id, ENT_CT_SPAWN)
            end
        end
        return
    end

    -- CTF maps
    if map("mission_ctfflags") > 0 then
        local px      = p(id, "tilex")
        local py      = p(id, "tiley")
        local hasflag = p(id, "flag")
        local etype   = entity(px, py, "type")

        if team == 1 then
            if hasflag then
                if etype == ENT_FLAG and entity(px, py, "int0") == FLAG_TEAM1 then roam(id)
                else setdest(id, ENT_FLAG) end
            else
                if shouldPush(id) then setdest(id, ENT_FLAG)
                else gotoBotNodeOrSpawn(id, ENT_T_SPAWN) end
            end
        else
            if hasflag then
                if etype == ENT_FLAG and entity(px, py, "int0") == FLAG_TEAM2 then roam(id)
                else setdest(id, ENT_FLAG) end
            else
                if shouldPush(id) then setdest(id, ENT_FLAG)
                else gotoBotNodeOrSpawn(id, ENT_CT_SPAWN) end
            end
        end
        return
    end

    -- DOM maps
    if map("mission_dompoints") > 0 then
        if shouldPush(id) then setdest(id, ENT_DOM_POINT)
        else roam(id) end
        return
    end

    -- Generic / DM
    if team == 1 then
        if r(1, 3) <= 2 then gotoBotNodeOrSpawn(id, ENT_T_SPAWN)
        else setdest(id, ENT_CT_SPAWN) end
    else
        if r(1, 3) <= 2 then gotoBotNodeOrSpawn(id, ENT_CT_SPAWN)
        else setdest(id, ENT_T_SPAWN) end
    end

    if vai_mode[id] ~= 2 then roam(id) end  -- last-resort fallback
end

------------------------------------------------------------------------
-- RADIO RESPONSES
------------------------------------------------------------------------

local function scheduleReply(mate, answer)
    vai_radioanswer[mate]  = answer
    vai_radioanswert[mate] = r(35, 100)
end

local function okReply()
    return (r(1, 2) == 1) and RADIO_OK or RADIO_AFFIRM
end

local function forTeamBots(source, fn)
    local team = p(source, "team")
    if team > 2 then team = 2 end
    local mates = p(0, "team" .. team .. "living")
    for i = 1, #mates do
        local mate = mates[i]
        if mate ~= source and p(mate, "bot") then
            fn(mate)
        end
    end
end

local RADIO = {}

-- Bomb planted: all CT bots switch to defuse; all T bots switch to guard
RADIO[RADIO_BOMB_PLANTED] = function()
    local bx, by = findPlantedBomb()
    local bots = p(0, "bot")
    for i = 1, #bots do
        local id   = bots[i]
        local team = p(id, "team")

        if team == 2 then
            -- CT: rush to defuse
            if vai_mode[id] ~= 52 then
                if bx then
                    vai_destx[id] = bx
                    vai_desty[id] = by
                else
                    local x, y = randomentity(ENT_BOMBSPOT)
                    if x ~= NO_ENTITY then
                        vai_destx[id] = x
                        vai_desty[id] = y
                    end
                end
                vai_mode[id]  = 52
                vai_smode[id] = 0
                vai_timer[id] = 0
            end
        elseif team == 1 then
            -- T: switch to guard mode if not already guarding or fighting
            if vai_mode[id] ~= 53 and vai_mode[id] ~= 4 and vai_mode[id] ~= 5 then
                if bx then
                    enterGuardMode(id, bx, by)
                end
            end
        end
    end
end

local function cmdFollow(source)
    local mate = fai_randommate(source)
    if mate ~= 0 then
        scheduleReply(mate, okReply())
        vai_mode[mate]  = 7
        vai_smode[mate] = source
        vai_timer[mate] = 0
    end
end
RADIO[RADIO_FOLLOW_ME]   = cmdFollow
RADIO[RADIO_COVER_ME]    = cmdFollow
RADIO[RADIO_NEED_BACKUP] = cmdFollow

local function cmdReinforce(source)
    local mate = fai_randommate(source)
    if mate ~= 0 then
        scheduleReply(mate, okReply())
        vai_mode[mate]  = 2
        vai_destx[mate] = p(source, "tilex")
        vai_desty[mate] = p(source, "tiley")
    end
end
RADIO[RADIO_ENEMY_SPOT]  = cmdReinforce
RADIO[RADIO_TAKING_FIRE] = cmdReinforce

RADIO[RADIO_REGROUP] = function(source)
    local c = 1
    forTeamBots(source, function(mate)
        if vai_mode[mate] == 7 then
            vai_radioanswer[mate]  = okReply()
            vai_radioanswert[mate] = r(50, 55) * c
            c = c + 1
            vai_mode[mate] = 0
        end
    end)
end

RADIO[RADIO_HOLD_POS] = function(source)
    local mate = fai_randommate(source)
    if mate ~= 0 then
        scheduleReply(mate, okReply())
        vai_mode[mate]  = 1
        vai_timer[mate] = r(30 * 50, 60 * 50)
    end
end

local function cmdResumeMove(source)
    local c = 1
    forTeamBots(source, function(mate)
        local mode = vai_mode[mate]
        if mode == 1 or mode == 7 then
            vai_radioanswer[mate]  = okReply()
            vai_radioanswert[mate] = r(50, 55) * c
            c = c + 1
            vai_mode[mate] = 0
        end
    end)
end
RADIO[RADIO_FALL_BACK]  = cmdResumeMove
RADIO[RADIO_GO_GO]      = cmdResumeMove
RADIO[RADIO_STICK_TOG1] = cmdResumeMove
RADIO[RADIO_STICK_TOG2] = cmdResumeMove
RADIO[RADIO_STICK_TOG3] = cmdResumeMove

RADIO[RADIO_REPORT_IN] = function(source)
    local mate = fai_randommate(source)
    if mate ~= 0 then scheduleReply(mate, RADIO_REPORTING) end
end

-- enterGuardMode is also needed in objectives.lua radio handler
-- expose it as a module-level function so objectives.lua can reference it
-- (both files are loaded in the same Lua state, so global scope works)
function fai_enterguardmode(id, bx, by)
    enterGuardMode(id, bx, by)
end

function fai_radio(source, radio)
    local handler = RADIO[radio]
    if handler then handler(source) end
end