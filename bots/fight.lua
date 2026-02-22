--------------------------------------------------
-- Fight / Combat Movement
--------------------------------------------------

local abs    = math.abs
local random = math.random
local p      = player

-- Thresholds for switching to "hunt" (chase) mode
local HUNT_DIST_X = 230
local HUNT_DIST_Y = 180
local HUNT_MIN_HP = 50

function fai_fight(id)
    local tid = vai_target[id]

    -- No target → exit fight mode
    if tid <= 0 or not p(tid, "exists") or p(tid, "health") <= 0 then
        vai_mode[id] = 0
        return
    end

    local my_x  = p(id, "x")
    local my_y  = p(id, "y")
    local my_hp = p(id, "health")
    local tx    = p(tid, "x")
    local ty    = p(tid, "y")

    ----------------------------------------------------------------------
    -- MELEE: close the gap
    ----------------------------------------------------------------------
    if itemtype(p(id, "weapontype"), "range") < 50 then
        if ai_goto(id, p(tid, "tilex"), p(tid, "tiley")) ~= 2 then
            vai_mode[id] = 0
        end
        return
    end

    ----------------------------------------------------------------------
    -- RANGED: strafe timer
    ----------------------------------------------------------------------
    vai_timer[id] = vai_timer[id] - 1
    if vai_timer[id] <= 0 then
        vai_timer[id] = random(50, 150)
        vai_smode[id] = random(0, 360)

        -- Occasionally chase if healthy and target is far away
        if random(1, 2) == 1 and my_hp > HUNT_MIN_HP
        and abs(my_x - tx) > HUNT_DIST_X
        and abs(my_y - ty) > HUNT_DIST_Y then
            vai_mode[id]  = 5
            vai_smode[id] = tid
        end
    end

    ----------------------------------------------------------------------
    -- STRAFE MOVEMENT
    ----------------------------------------------------------------------
    if ai_move(id, vai_smode[id]) == 0 then
        -- Blocked: reverse strafe direction
        vai_smode[id] = vai_smode[id] + ((id % 2 == 0) and 45 or -45)
        vai_timer[id] = random(50, 150)
    end
end
