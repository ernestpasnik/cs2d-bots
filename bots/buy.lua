--------------------------------------------------
-- Buy Logic
--------------------------------------------------

-- Buy steps executed in order (smode 0..5)
-- Each entry: { handler(id, money, team, weapons) }
local BUY_STEPS = {
    -- 0: Primary weapon
    function(id, money, team, weapons)
        if fai_contains(weapons, 30) or fai_contains(weapons, 32) then
            if money >= 50 then ai_buy(id, 61) end  -- primary ammo
        elseif team == 1 then
            if money >= 3250 then ai_buy(id, 30) end  -- AK-47
        else
            if money >= 3850 then ai_buy(id, 32) end  -- M4A1
        end
    end,

    -- 1: (reserved slot – intentionally empty for timer spacing)
    function() end,

    -- 2: Armor
    function(id, money)
        if money >= 1000 then
            ai_buy(id, 57)  -- kevlar + helmet
        elseif money >= 650 then
            ai_buy(id, 58)  -- kevlar only
        end
    end,

    -- 3: HE grenade (random 25 % chance)
    function(id, money)
        if money >= 300 and math.random(0, 3) == 1 then
            ai_buy(id, 51)
        end
    end,

    -- 4: Secondary ammo
    function(id, money)
        if money >= 50 then ai_buy(id, 62) end
    end,

    -- 5: Switch to knife
    function(id, _, _, weapons)
        if fai_contains(weapons, 50) then
            ai_selectweapon(id, 50)
        end
    end,
}

local STEPS_MAX = #BUY_STEPS  -- 6 steps (indices 1..6 in Lua, mapped from smode 0..5)

function fai_buy(id)
    -- Wait out timer between purchase steps
    if vai_timer[id] > 0 then
        vai_timer[id] = vai_timer[id] - 1
        return
    end

    local smode   = vai_smode[id]
    local step    = smode + 1  -- convert 0-based smode to 1-based table index

    if step <= STEPS_MAX then
        local handler = BUY_STEPS[step]
        if handler then
            handler(id,
                player(id, "money"),
                player(id, "team"),
                playerweapons(id))
        end
    end

    -- Advance to next step
    vai_smode[id] = smode + 1
    vai_timer[id] = math.random(1, 5)

    -- All steps done → transition to decide
    if vai_smode[id] >= STEPS_MAX then
        vai_mode[id]       = 0
        vai_smode[id]      = 0
        vai_buyingdone[id] = 1
    end
end
