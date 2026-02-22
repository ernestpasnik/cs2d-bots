-- combat.lua: target tracking, aiming, firing, and fight movement

local abs    = math.abs
local random = math.random
local p      = player

-- Runs every tick. Finds and validates a target, updates aim, and fires when on-angle.
-- Skips target scanning in buy (-1) and wait (1) modes to avoid interrupting those states.
function fai_engage(id)

    -- Reacquire target on a fixed period
    vai_reaim[id] = vai_reaim[id] - 1
    if vai_reaim[id] < 0 then
        vai_reaim[id] = REAIM_PERIOD

        local mode = vai_mode[id]
        if mode ~= -1 and mode ~= 1 then
            if p(id, "ai_flash") == 0 then
                local t = ai_findtarget(id)
                vai_target[id] = t
                if t > 0 then vai_rescan[id] = 0 end
            else
                -- Flashbanged: drop target and flee to a nearby tile
                vai_target[id] = 0
                if mode ~= 8 then
                    vai_mode[id] = 8
                    fai_randomadjacent(id)
                end
            end
        end
    end

    -- Validate the current target every tick
    local tid = vai_target[id]
    if tid > 0 then
        if not p(tid, "exists") or p(tid, "health") <= 0
        or p(tid, "team") <= 0 or not fai_enemies(tid, id) then
            vai_target[id] = 0
            tid = 0
        else
            local x1 = p(id,  "x");  local y1 = p(id,  "y")
            local tx = p(tid, "x");  local ty = p(tid, "y")

            if abs(x1 - tx) >= VIEW_HALF_W or abs(y1 - ty) >= VIEW_HALF_H then
                -- Target scrolled off screen
                vai_target[id] = 0
                tid = 0
            else
                -- Periodic LOS check; skipped when target is very close
                vai_rescan[id] = vai_rescan[id] - 1
                if vai_rescan[id] < 0 then
                    vai_rescan[id] = RESCAN_PERIOD
                    if (abs(x1 - tx) > LOS_MIN_DIST or abs(y1 - ty) > LOS_MIN_DIST)
                    and not ai_freeline(id, tx, ty) then
                        vai_target[id] = 0
                        tid = 0
                    end
                end
            end
        end
    end

    -- Lock aim onto target; enter fight mode on first acquisition
    tid = vai_target[id]
    if tid > 0 then
        vai_aimx[id] = p(tid, "x")
        vai_aimy[id] = p(tid, "y")

        local mode = vai_mode[id]
        if mode ~= 4 and mode ~= 5 then
            -- vai_smode holds the strafe angle in mode 4; set a fresh one on entry
            vai_smode[id] = random(0, 360)
            vai_timer[id] = random(25, 100)
            vai_mode[id]  = 4
        end
    end

    ai_aim(id, vai_aimx[id], vai_aimy[id])

    -- Fire only when aimed within tolerance of the target
    if tid > 0 then
        local rot = p(id, "rot")
        local ang = fai_angleto(p(id, "x"), p(id, "y"), p(tid, "x"), p(tid, "y"))
        if abs(fai_angledelta(rot, ang)) < AIM_TOLERANCE then
            ai_iattack(id)
        end
    end
end

-- MODE 4: strafe sideways while shooting at the current target.
--   vai_smode = strafe direction in degrees (0-360)
--   vai_timer = ticks until next direction change
-- When switching to hunt mode (5), vai_smode is repurposed to hold the target's
-- player ID. fai_engage resets it to a fresh angle whenever mode 4 is re-entered.
function fai_fight(id)
    local tid = vai_target[id]

    if tid <= 0 or not p(tid, "exists") or p(tid, "health") <= 0 then
        vai_mode[id] = 0
        return
    end

    -- Melee weapons: close the gap instead of strafing
    if itemtype(p(id, "weapontype"), "range") < 50 then
        if ai_goto(id, p(tid, "tilex"), p(tid, "tiley")) ~= 2 then
            vai_mode[id] = 0
        else
            fai_walkaim(id)
        end
        return
    end

    -- Decrement strafe timer; pick a new direction when it expires
    vai_timer[id] = vai_timer[id] - 1
    if vai_timer[id] <= 0 then
        vai_timer[id] = random(50, 150)
        vai_smode[id] = random(0, 360)

        -- Occasionally chase if healthy and the target is far away
        local my_x = p(id, "x");   local my_y = p(id, "y")
        local tx   = p(tid, "x");  local ty   = p(tid, "y")
        if random(1, 2) == 1 and p(id, "health") > HUNT_MIN_HP
        and math.abs(my_x - tx) > HUNT_DIST_X
        and math.abs(my_y - ty) > HUNT_DIST_Y then
            vai_mode[id]  = 5
            vai_smode[id] = tid  -- hunt mode reads this as the target player ID
        end
    end

    -- Move in the current strafe direction; nudge angle if blocked
    if ai_move(id, vai_smode[id]) == 0 then
        vai_smode[id] = vai_smode[id] + ((id % 2 == 0) and 45 or -45)
        vai_timer[id] = random(50, 150)
    end
end
