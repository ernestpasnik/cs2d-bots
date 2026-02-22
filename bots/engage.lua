--------------------------------------------------
-- Engage / Combat Detection
--------------------------------------------------

local abs    = math.abs
local random = math.random
local p      = player

-- View frustum constants (pixel-space)
local VIEW_X = 420
local VIEW_Y = 235

function fai_engage(id)

    --------------------------------------------------------------------------
    -- REACQUIRE TARGET (every 20 ticks)
    --------------------------------------------------------------------------
    vai_reaim[id] = vai_reaim[id] - 1
    if vai_reaim[id] < 0 then
        vai_reaim[id] = 20

        if p(id, "ai_flash") == 0 then
            local t = ai_findtarget(id)
            vai_target[id] = t
            if t > 0 then vai_rescan[id] = 0 end
        else
            -- Flashed: lose target and flee
            vai_target[id] = 0
            if vai_mode[id] ~= 8 then
                vai_mode[id] = 8
                fai_randomadjacent(id)
            end
        end
    end

    --------------------------------------------------------------------------
    -- VALIDATE CURRENT TARGET
    --------------------------------------------------------------------------
    local tid = vai_target[id]
    if tid > 0 then
        local tx = p(tid, "x")
        local ty = p(tid, "y")

        if not p(tid, "exists")
        or p(tid, "health") <= 0
        or p(tid, "team") <= 0
        or not fai_enemies(tid, id) then
            -- Dead / invalid
            vai_target[id] = 0
            tid = 0

        else
            local x1 = p(id, "x")
            local y1 = p(id, "y")

            -- Out of screen range?
            if abs(x1 - tx) >= VIEW_X or abs(y1 - ty) >= VIEW_Y then
                vai_target[id] = 0
                tid = 0

            else
                -- Periodic line-of-sight check
                vai_rescan[id] = vai_rescan[id] - 1
                if vai_rescan[id] < 0 then
                    vai_rescan[id] = 10
                    if (abs(x1 - tx) > 30 or abs(y1 - ty) > 30)
                    and not ai_freeline(id, tx, ty) then
                        vai_target[id] = 0
                        tid = 0
                    end
                end
            end
        end
    end

    --------------------------------------------------------------------------
    -- UPDATE AIM POSITION
    --------------------------------------------------------------------------
    tid = vai_target[id]
    if tid > 0 then
        vai_aimx[id] = p(tid, "x")
        vai_aimy[id] = p(tid, "y")

        -- Enter fight mode when we acquire a target
        local mode = vai_mode[id]
        if mode ~= 4 and mode ~= 5 then
            vai_timer[id] = random(25, 100)
            vai_smode[id] = random(0, 360)
            vai_mode[id]  = 4
        end
    end

    ai_aim(id, vai_aimx[id], vai_aimy[id])

    --------------------------------------------------------------------------
    -- SHOOT
    --------------------------------------------------------------------------
    if tid > 0 then
        local rot = p(id, "rot")
        local ang = fai_angleto(p(id, "x"), p(id, "y"),
                                p(tid, "x"), p(tid, "y"))

        -- Fire only when aimed within 20° of target
        if abs(fai_angledelta(rot, ang)) < 20 then
            ai_iattack(id)
        end
    end
end
