function fai_follow(id)
    local p = player
    local r = math.random
    local abs = math.abs

    local fid = vai_smode[id]  -- followed player ID

    --------------------------------------------------------------------------
    -- VALIDATE FOLLOW TARGET
    --------------------------------------------------------------------------
    if fid <= 0 or not p(fid, "exists") or p(fid, "health") <= 0 then
        vai_mode[id] = 0
        return
    end

    --------------------------------------------------------------------------
    -- CACHE POSITIONS
    --------------------------------------------------------------------------
    local my_tx = p(id, "tilex")
    local my_ty = p(id, "tiley")
    local fx    = p(fid, "tilex")
    local fy    = p(fid, "tiley")

    --------------------------------------------------------------------------
    -- ROAMING AROUND TARGET (timer > 0)
    --------------------------------------------------------------------------
    local timer = vai_timer[id]
    if timer > 0 then
        -- Try to move in current roam direction
        if ai_move(id, vai_destx[id], 1) == 0 then
            -- Blocked → turn
            if (id % 2) == 0 then
                vai_destx[id] = vai_destx[id] + 45
            else
                vai_destx[id] = vai_destx[id] - 45
            end
            vai_timer[id] = r(3, 5) * 50
        else
            -- Continue roaming
            timer = timer - 1
            vai_timer[id] = timer

            -- Change roam direction
            if timer == 1 then
                vai_timer[id] = r(3, 5) * 50
                vai_destx[id] = r(0, 360)
            end

            -- Every 25 ticks: check distance to followed player
            if (timer % 25) == 0 then
                if abs(my_tx - fx) > 3 or abs(my_ty - fy) > 2 then
                    -- Too far → resume following
                    vai_timer[id] = 0
                end
            end
        end

        fai_walkaim(id)
        return
    end

    --------------------------------------------------------------------------
    -- FOLLOW TARGET (timer == 0)
    --------------------------------------------------------------------------
    if ai_goto(id, fx, fy) == 1 then
        -- Reached → start roaming
        vai_timer[id] = r(3, 5) * 50
        vai_destx[id] = r(0, 360)
    end

    fai_walkaim(id)
end
