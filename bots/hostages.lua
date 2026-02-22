--------------------------------------------------
-- Hostage Rescue Logic
--------------------------------------------------

local abs    = math.abs
local random = math.random
local p      = player
local hst    = hostage

-- Interaction range (pixels)
local USE_RANGE = 15

function fai_rescuehostages(id)
    local sm = vai_smode[id]

    --------------------------------------------------------------------------
    -- SMODE 0: FIND & USE HOSTAGES
    --------------------------------------------------------------------------
    if sm == 0 then

        -- Navigate toward next hostage position
        if ai_goto(id, vai_destx[id], vai_desty[id]) ~= 2 then
            vai_mode[id] = 0
            return
        end
        fai_walkaim(id)

        local bx = p(id, "x")
        local by = p(id, "y")

        -- Try to pick up any hostage we're standing next to
        local list = hst(0, "table")
        for i = 1, #list do
            local hid = list[i]
            if hst(hid, "health") > 0 and hst(hid, "follow") == 0 then
                local hx = hst(hid, "x")
                local hy = hst(hid, "y")

                if abs(bx - hx) <= USE_RANGE and abs(by - hy) <= USE_RANGE then
                    ai_rotate(id, fai_angleto(bx, by, hx, hy))
                    ai_use(id)
                    break
                end
            end
        end

        -- Look for the closest uncollected hostage
        local dx, dy = closehostage(id)
        vai_destx[id] = dx
        vai_desty[id] = dy

        if dx == -100 then
            -- No more hostages: head to rescue zone
            vai_smode[id] = 1

            dx, dy = randomentity(4)  -- rescue point
            if dx == -100 then
                dx, dy = randomentity(1)  -- fallback: CT spawn
            end

            vai_destx[id] = dx
            vai_desty[id] = dy
        end

        return
    end

    --------------------------------------------------------------------------
    -- SMODE 1: ESCORT HOSTAGES TO RESCUE POINT
    --------------------------------------------------------------------------
    local result = ai_goto(id, vai_destx[id], vai_desty[id])

    if result == 1 then
        -- Reached rescue point: roam briefly
        vai_mode[id]  = 3
        vai_timer[id] = random(150, 300)
        vai_smode[id] = random(0, 360)

    elseif result == 0 then
        -- Path blocked: reset
        vai_mode[id] = 0

    else
        fai_walkaim(id)
    end
end
