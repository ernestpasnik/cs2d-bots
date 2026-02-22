--------------------------------------------------
-- Follow Logic
--------------------------------------------------

local abs    = math.abs
local random = math.random
local p      = player

-- Distance (in tiles) before stopping the follow and roaming near target
local CLOSE_DIST_X = 3
local CLOSE_DIST_Y = 2

function fai_follow(id)
    local fid = vai_smode[id]  -- followed player ID

    --------------------------------------------------------------------------
    -- VALIDATE FOLLOW TARGET
    --------------------------------------------------------------------------
    if fid <= 0 or not p(fid, "exists") or p(fid, "health") <= 0 then
        vai_mode[id] = 0
        return
    end

    local my_tx = p(id,  "tilex")
    local my_ty = p(id,  "tiley")
    local fx    = p(fid, "tilex")
    local fy    = p(fid, "tiley")

    --------------------------------------------------------------------------
    -- ROAMING NEARBY (timer > 0)
    --------------------------------------------------------------------------
    local timer = vai_timer[id]
    if timer > 0 then
        if ai_move(id, vai_destx[id], 1) == 0 then
            -- Blocked → change direction
            vai_destx[id] = vai_destx[id] + ((id % 2 == 0) and 45 or -45)
            vai_timer[id] = random(3, 5) * 50
        else
            timer = timer - 1
            vai_timer[id] = timer

            -- Pick a new random direction at the end of a roam phase
            if timer == 0 then
                vai_timer[id] = random(3, 5) * 50
                vai_destx[id] = random(0, 360)
            end

            -- Periodic distance check: resume following if leader moved away
            if (timer % 25) == 0
            and (abs(my_tx - fx) > CLOSE_DIST_X or abs(my_ty - fy) > CLOSE_DIST_Y) then
                vai_timer[id] = 0  -- break roam, fall through to follow
            end
        end

        fai_walkaim(id)
        return
    end

    --------------------------------------------------------------------------
    -- FOLLOWING (timer == 0)
    --------------------------------------------------------------------------
    if ai_goto(id, fx, fy) == 1 then
        -- Reached → switch to roam phase
        vai_timer[id] = random(3, 5) * 50
        vai_destx[id] = random(0, 360)
    end

    fai_walkaim(id)
end