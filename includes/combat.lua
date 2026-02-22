-- combat.lua: target tracking, aiming, firing, and fight movement
-- Human-like improvements:
--   • Reaction delay before engaging a newly spotted target
--   • Smooth aim rotation (not snap-to-target)
--   • Burst-fire with pauses between bursts
--   • Recoil / spray drift that accumulates and recovers
--   • Distance and movement accuracy penalties
--   • Peek-and-retreat cover behaviour
--   • Last-known-position hunting after losing sight
--   • Grenade opportunism during fight

local abs    = math.abs
local random = math.random
local sqrt   = math.sqrt
local p      = player

-- ============================================================
-- INTERNAL HELPERS
-- ============================================================

-- True if the bot is currently crouching
local function isCrouching(id)
    return vai_crouch_timer[id] and vai_crouch_timer[id] > 0
end

-- Decide whether to throw a grenade at the current target position
local function tryGrenadeThrow(id, tx, ty)
    if NADE_USE_CHANCE == 0 then return end
    local bx = p(id, "x")
    local by = p(id, "y")
    if fai_distsq(bx, by, tx, ty) < NADE_MIN_DIST * NADE_MIN_DIST then return end

    if random() < NADE_USE_CHANCE then
        local weapons = playerweapons(id)
        if fai_contains(weapons, WPN_GRENADE) then
            ai_selectweapon(id, WPN_GRENADE)
            ai_attack(id)  -- throw
            -- Switch back to primary next tick via buy/weapon recovery in tactics
        end
    end
end

-- ============================================================
-- fai_engage  (runs every tick)
-- ============================================================
-- Reacquire → validate → smooth-aim → burst-fire → enter fight mode
-- Adds: reaction delay, LKP memory, crouch ticks, movement tracking.

function fai_engage(id)

    -- ── Reacquire target on a fixed period ──────────────────
    vai_reaim[id] = vai_reaim[id] - 1
    if vai_reaim[id] < 0 then
        vai_reaim[id] = REAIM_PERIOD

        local mode = vai_mode[id]
        if mode ~= -1 and mode ~= 1 then
            if p(id, "ai_flash") == 0 then
                local t = ai_findtarget(id)
                if t > 0 then
                    -- Only switch targets if this is a new one; reset reaction timer
                    if t ~= vai_target[id] then
                        vai_react_timer[id] = vai_react_delay[id] or REACT_TICKS_MED
                    end
                    vai_target[id] = t
                    vai_rescan[id] = 0
                    -- Update LKP immediately so we always have a fallback
                    fai_updatelpk(id, p(t, "x"), p(t, "y"))
                else
                    -- No target found; LKP memory ticks down naturally
                    vai_target[id] = 0
                end
            else
                -- Flashbanged: drop target, flee, reset engagement state
                vai_target[id]      = 0
                vai_spray_drift[id] = 0
                vai_shot_count[id]  = 0
                if mode ~= 8 then
                    vai_mode[id] = 8
                    fai_randomadjacent(id)
                end
            end
        end
    end

    -- ── Validate the current target every tick ───────────────
    local tid = vai_target[id]
    if tid > 0 then
        if not p(tid, "exists") or p(tid, "health") <= 0
        or p(tid, "team") <= 0 or not fai_enemies(tid, id) then
            -- Target died or left; remember last position for a while
            if tid > 0 then
                local tx = p(tid, "x"); local ty = p(tid, "y")
                fai_updatelpk(id, tx, ty)
            end
            vai_target[id] = 0
            tid = 0
            vai_shot_count[id] = 0
        else
            local x1 = p(id,  "x");  local y1 = p(id,  "y")
            local tx = p(tid, "x");  local ty = p(tid, "y")

            if abs(x1 - tx) >= VIEW_HALF_W or abs(y1 - ty) >= VIEW_HALF_H then
                -- Target scrolled off screen; save LKP
                fai_updatelpk(id, tx, ty)
                vai_target[id] = 0
                tid = 0
                vai_shot_count[id] = 0
            else
                -- Periodic LOS check; skipped when target is very close
                vai_rescan[id] = vai_rescan[id] - 1
                if vai_rescan[id] < 0 then
                    vai_rescan[id] = RESCAN_PERIOD
                    if (abs(x1 - tx) > LOS_MIN_DIST or abs(y1 - ty) > LOS_MIN_DIST)
                    and not ai_freeline(id, tx, ty) then
                        -- Lost sight; remember where we last saw them
                        fai_updatelpk(id, tx, ty)
                        vai_target[id] = 0
                        tid = 0
                        vai_shot_count[id] = 0
                    else
                        -- Still visible; keep LKP fresh
                        fai_updatelpk(id, tx, ty)
                    end
                end
            end
        end
    end

    -- ── Reaction delay: don't engage instantly on first spot ─
    if vai_react_timer[id] and vai_react_timer[id] > 0 then
        vai_react_timer[id] = vai_react_timer[id] - 1
        -- Still smooth-aim toward where we think the target is, but don't fire
        if tid > 0 then
            fai_smoothaim(id, p(tid, "x"), p(tid, "y"), tid)
        end
        return  -- skip firing logic until reaction window passes
    end

    -- ── Tick down burst pause ─────────────────────────────────
    if vai_burst_pause[id] and vai_burst_pause[id] > 0 then
        vai_burst_pause[id] = vai_burst_pause[id] - 1
        -- During pause, let spray drift recover
        vai_spray_drift[id] = math.max(0, (vai_spray_drift[id] or 0) - SPRAY_RECOVER_RATE)
    end

    -- ── Aim and fire ─────────────────────────────────────────
    tid = vai_target[id]
    if tid > 0 then
        local tx = p(tid, "x")
        local ty = p(tid, "y")

        vai_aimx[id] = tx
        vai_aimy[id] = ty

        -- Smooth aim; get residual angle error back
        local aim_error = fai_smoothaim(id, tx, ty, tid)

        -- Enter fight mode on first acquisition
        local mode = vai_mode[id]
        if mode ~= 4 and mode ~= 5 then
            vai_smode[id] = random(0, 360)
            vai_timer[id] = random(PEEK_EXPOSE_MIN, PEEK_EXPOSE_MAX)
            vai_mode[id]  = 4
            vai_shot_count[id] = 0
        end

        -- Crouch randomly while stationary and shooting
        if vai_is_moving[id] == 0 and vai_crouch_timer[id] == 0 and random() < CROUCH_CHANCE then
            vai_crouch_timer[id] = random(CROUCH_TICKS_MIN, CROUCH_TICKS_MAX)
        end
        if isCrouching(id) then
            ai_crouch(id, 1)
            vai_crouch_timer[id] = vai_crouch_timer[id] - 1
        else
            ai_crouch(id, 0)
        end

        -- Burst-fire: only fire when aimed within tolerance AND burst not paused
        local burst_ok = (not vai_burst_pause[id] or vai_burst_pause[id] == 0)
        if aim_error < AIM_TOLERANCE and burst_ok then
            ai_iattack(id)

            -- Track consecutive shots and add spray drift
            vai_shot_count[id] = vai_shot_count[id] + 1
            local sc = vai_shot_count[id]
            if sc > SPRAY_START_SHOT then
                vai_spray_drift[id] = math.min(
                    SPRAY_MAX_DRIFT,
                    (vai_spray_drift[id] or 0) + SPRAY_DRIFT_RATE
                )
            end

            -- Decrement burst size; start a pause when burst is exhausted
            vai_burst_size[id] = (vai_burst_size[id] or BURST_SIZE_MAX) - 1
            if vai_burst_size[id] <= 0 then
                vai_burst_size[id]  = random(BURST_SIZE_MIN, BURST_SIZE_MAX)
                vai_burst_pause[id] = random(BURST_PAUSE_MIN, BURST_PAUSE_MAX)
                -- Crouch randomly at end of burst
                if vai_is_moving[id] == 0 and random() < CROUCH_CHANCE then
                    vai_crouch_timer[id] = random(CROUCH_TICKS_MIN, CROUCH_TICKS_MAX)
                end
            end

            -- Occasional grenade opportunism
            tryGrenadeThrow(id, tx, ty)
        end

    else
        -- No live target: continue aiming at last-known position if memory is fresh
        ai_crouch(id, 0)
        vai_crouch_timer[id] = 0
        vai_shot_count[id]   = 0

        if fai_ticklkp(id) then
            -- Smoothly pan toward LKP so the bot "checks" the last seen spot
            fai_smoothaim(id, vai_lkp_x[id], vai_lkp_y[id], 0)
        else
            ai_aim(id, vai_aimx[id], vai_aimy[id])
        end
    end
end

-- ============================================================
-- MODE 4: fight  (strafe + peek-and-retreat + shoot)
-- ============================================================
-- Human improvements:
--   • Peek-and-retreat: bot alternates between exposing and ducking back
--   • Low-HP panic retreat
--   • Strafes with variable speed changes
--   • Hunts if healthy and far; retreats if hurt

function fai_fight(id)
    local tid = vai_target[id]

    if tid <= 0 or not p(tid, "exists") or p(tid, "health") <= 0 then
        -- No target: hunt toward LKP if we have one
        if vai_lkp_timer[id] and vai_lkp_timer[id] > 0 then
            vai_mode[id]  = 5
            vai_smode[id] = 0  -- 0 = hunt LKP, not a player
        else
            vai_mode[id] = 0
        end
        return
    end

    -- Low-HP panic: retreat toward a random safe tile
    if p(id, "health") < PANIC_HP_THRESHOLD then
        fai_randomadjacent(id)
        vai_mode[id]  = 2  -- goto mode
        vai_timer[id] = 0
        -- Try to un-crouch while fleeing
        ai_crouch(id, 0)
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

    -- ── Peek-and-retreat ────────────────────────────────────
    -- vai_peek_state[id]: 0 = exposed/attacking, 1 = briefly retreating
    if vai_peek_state[id] == 1 then
        -- Retreating phase: move away from enemy for a few ticks
        local bx    = p(id, "x");  local by = p(id, "y")
        local tx    = p(tid, "x"); local ty = p(tid, "y")
        local away  = (fai_angleto(tx, ty, bx, by)) % 360  -- reverse angle
        if ai_move(id, away) == 0 then
            -- Blocked: just nudge sideways
            ai_move(id, (away + 90) % 360)
        end
        fai_walkaim(id)

        vai_peek_timer[id] = vai_peek_timer[id] - 1
        if vai_peek_timer[id] <= 0 then
            -- Switch back to exposed / attacking
            vai_peek_state[id] = 0
            vai_peek_timer[id] = random(PEEK_EXPOSE_MIN, PEEK_EXPOSE_MAX)
        end
        return
    end

    -- ── Exposed / attacking phase ────────────────────────────
    -- Decrement strafe timer; pick a new direction when it expires
    vai_timer[id] = vai_timer[id] - 1
    if vai_timer[id] <= 0 then
        vai_timer[id] = random(50, 150)
        vai_smode[id] = random(0, 360)

        -- Occasionally start a retreat peek
        if random() < 0.25 then
            vai_peek_state[id] = 1
            vai_peek_timer[id] = random(PEEK_RETREAT_MIN, PEEK_RETREAT_MAX)
            return
        end

        -- Occasionally chase if healthy and target is far
        local my_x = p(id, "x");   local my_y = p(id, "y")
        local tx   = p(tid, "x");  local ty   = p(tid, "y")
        if random(1, 2) == 1 and p(id, "health") > HUNT_MIN_HP
        and abs(my_x - tx) > HUNT_DIST_X
        and abs(my_y - ty) > HUNT_DIST_Y then
            vai_mode[id]  = 5
            vai_smode[id] = tid  -- hunt mode reads this as the target player ID
        end
    end

    -- Move in the current strafe direction; nudge angle if blocked
    if ai_move(id, vai_smode[id]) == 0 then
        -- Alternate nudge direction per bot ID for variety
        vai_smode[id] = vai_smode[id] + ((id % 2 == 0) and 45 or -45)
        vai_timer[id] = random(50, 150)
    end

    -- Track movement for accuracy penalty
    vai_is_moving[id] = 1
end

-- ============================================================
-- MODE 5: hunt  (chase target or last-known-position)
-- ============================================================
-- If vai_smode > 0 it's a live player ID; if 0 we head to LKP then search.

function fai_hunt(id)
    -- Hunt a live player
    local tid = vai_smode[id]
    if tid and tid > 0 then
        if p(tid, "exists") and p(tid, "health") > 0 then
            if ai_goto(id, p(tid, "tilex"), p(tid, "tiley")) ~= 2 then
                vai_mode[id] = 0
            end
        else
            -- Player died; check LKP
            vai_smode[id] = 0
        end
        return
    end

    -- Hunt last-known-position
    if vai_lkp_timer[id] and vai_lkp_timer[id] > 0 then
        local lx = vai_lkp_x[id]
        local ly = vai_lkp_y[id]
        local res = ai_goto(id, lx, ly)
        if res ~= 2 then
            -- Arrived at or can't reach LKP; give up and re-decide
            vai_lkp_timer[id] = 0
            vai_mode[id] = 0
        else
            fai_walkaim(id)
        end
    else
        vai_mode[id] = 0
    end
end