function fai_rescuehostages(id)
    local p   = player
    local hst = hostage
    local abs = math.abs
    local r   = math.random

    local sm  = vai_smode[id]

    --------------------------------------------------------------------------
    -- MODE 0: FIND & USE HOSTAGES
    --------------------------------------------------------------------------
    if sm == 0 then
        -- Move toward current hostage destination
        if ai_goto(id, vai_destx[id], vai_desty[id]) ~= 2 then
            vai_mode[id] = 0
        else
            fai_walkaim(id)
        end

        ----------------------------------------------------------------------
        -- TRY TO USE NEARBY HOSTAGES
        ----------------------------------------------------------------------
        local hx = p(id, "x")
        local hy = p(id, "y")

        local list = hst(0, "table")
        for i = 1, #list do
            local hid = list[i]

            if hst(hid, "health") > 0 and hst(hid, "follow") == 0 then
                local tx = hst(hid, "x")
                local ty = hst(hid, "y")

                if abs(hx - tx) <= 15 and abs(hy - ty) <= 15 then
                    ai_rotate(id, fai_angleto(hx, hy, tx, ty))
                    ai_use(id)
                    break
                end
            end
        end

        ----------------------------------------------------------------------
        -- FIND NEXT HOSTAGE
        ----------------------------------------------------------------------
        local dx, dy = closehostage(id)
        vai_destx[id], vai_desty[id] = dx, dy

        if dx == -100 then
            -- No more hostages → switch to rescue mode
            vai_smode[id] = 1

            dx, dy = randomentity(4)  -- rescue point
            if dx == -100 then
                dx, dy = randomentity(1)  -- fallback: CT spawn
            end

            vai_destx[id], vai_desty[id] = dx, dy
        end

        return
    end

    --------------------------------------------------------------------------
    -- MODE 1: RETURN & RESCUE HOSTAGES
    --------------------------------------------------------------------------
    local result = ai_goto(id, vai_destx[id], vai_desty[id])

    if result == 1 then
        -- Reached rescue point → roam
        vai_mode[id]  = 3
        vai_timer[id] = r(150, 300)
        vai_smode[id] = r(0, 360)

    elseif result == 0 then
        -- Path blocked → reset
        vai_mode[id] = 0

    else
        -- Still moving
        fai_walkaim(id)
    end
end
