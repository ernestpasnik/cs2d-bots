
-- combat.lua: target tracking, aiming, firing, and fight movement

local abs    = math.abs
local random = math.random
local sqrt   = math.sqrt
local p      = player

local function isCrouching(id)
    return vai_crouch_timer[id] and vai_crouch_timer[id] > 0
end

local function tryGrenadeThrow(id, tx, ty)
    if NADE_USE_CHANCE == 0 then return end
    local bx = p(id, "x")
    local by = p(id, "y")
    if fai_distsq(bx, by, tx, ty) < NADE_MIN_DIST * NADE_MIN_DIST then return end
    if random() < NADE_USE_CHANCE then
        local weapons = playerweapons(id)
        if fai_contains(weapons, WPN_GRENADE) then
            ai_selectweapon(id, WPN_GRENADE)
            ai_attack(id)
        end
    end
end

function fai_engage(id)
    vai_reaim[id] = vai_reaim[id] - 1
    if vai_reaim[id] < 0 then
        vai_reaim[id] = REAIM_PERIOD
        local mode = vai_mode[id]
        if mode ~= -1 and mode ~= 1 then
            if p(id, "ai_flash") == 0 then
                local t = ai_findtarget(id)
                if t > 0 then
                    if t ~= vai_target[id] then
                        vai_react_timer[id] = vai_react_delay[id] or REACT_TICKS_MED
                    end
                    vai_target[id] = t
                    vai_rescan[id] = 0
                    fai_updatelpk(id, p(t, "x"), p(t, "y"))
                else
                    vai_target[id] = 0
                end
            else
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

    local tid = vai_target[id]
    if tid > 0 then
        if not p(tid, "exists") or p(tid, "health") <= 0
        or p(tid, "team") <= 0 or not fai_enemies(tid, id) then
            if tid > 0 then
                fai_updatelpk(id, p(tid, "x"), p(tid, "y"))
            end
            vai_target[id] = 0
            tid = 0
            vai_shot_count[id] = 0
        else
            local x1 = p(id,  "x");  local y1 = p(id,  "y")
            local tx = p(tid, "x");  local ty = p(tid, "y")
            if abs(x1 - tx) >= VIEW_HALF_W or abs(y1 - ty) >= VIEW_HALF_H then
                fai_updatelpk(id, tx, ty)
                vai_target[id] = 0
                tid = 0
                vai_shot_count[id] = 0
            else
                vai_rescan[id] = vai_rescan[id] - 1
                if vai_rescan[id] < 0 then
                    vai_rescan[id] = RESCAN_PERIOD
                    if (abs(x1 - tx) > LOS_MIN_DIST or abs(y1 - ty) > LOS_MIN_DIST)
                    and not ai_freeline(id, tx, ty) then
                        fai_updatelpk(id, tx, ty)
                        vai_target[id] = 0
                        tid = 0
                        vai_shot_count[id] = 0
                    else
                        fai_updatelpk(id, tx, ty)
                    end
                end
            end
        end
    end

    if vai_react_timer[id] and vai_react_timer[id] > 0 then
        vai_react_timer[id] = vai_react_timer[id] - 1
        if tid > 0 then
            fai_smoothaim(id, p(tid, "x"), p(tid, "y"), tid)
        end
        return
    end

    if vai_burst_pause[id] and vai_burst_pause[id] > 0 then
        vai_burst_pause[id] = vai_burst_pause[id] - 1
        vai_spray_drift[id] = math.max(0, (vai_spray_drift[id] or 0) - SPRAY_RECOVER_RATE)
    end

    tid = vai_target[id]
    if tid > 0 then
        local tx = p(tid, "x")
        local ty = p(tid, "y")

        vai_aimx[id] = tx
        vai_aimy[id] = ty

        local aim_error = fai_smoothaim(id, tx, ty, tid)

        local mode = vai_mode[id]
        if mode ~= 4 and mode ~= 5 then
            vai_smode[id] = random(0, 360)
            vai_timer[id] = random(PEEK_EXPOSE_MIN, PEEK_EXPOSE_MAX)
            vai_mode[id]  = 4
            vai_shot_count[id] = 0
        end

        if vai_is_moving[id] == 0 and vai_crouch_timer[id] == 0 and random() < CROUCH_CHANCE then
            vai_crouch_timer[id] = random(CROUCH_TICKS_MIN, CROUCH_TICKS_MAX)
        end
        if isCrouching(id) then
            ai_crouch(id, 1)
            vai_crouch_timer[id] = vai_crouch_timer[id] - 1
        else
            ai_crouch(id, 0)
        end

        local burst_ok = (not vai_burst_pause[id] or vai_burst_pause[id] == 0)
        if aim_error < AIM_TOLERANCE and burst_ok then
            ai_iattack(id)

            vai_shot_count[id] = vai_shot_count[id] + 1
            local sc = vai_shot_count[id]
            if sc > SPRAY_START_SHOT then
                vai_spray_drift[id] = math.min(
                    SPRAY_MAX_DRIFT,
                    (vai_spray_drift[id] or 0) + SPRAY_DRIFT_RATE
                )
            end

            vai_burst_size[id] = (vai_burst_size[id] or BURST_SIZE_MAX) - 1
            if vai_burst_size[id] <= 0 then
                vai_burst_size[id]  = random(BURST_SIZE_MIN, BURST_SIZE_MAX)
                vai_burst_pause[id] = random(BURST_PAUSE_MIN, BURST_PAUSE_MAX)
                if vai_is_moving[id] == 0 and random() < CROUCH_CHANCE then
                    vai_crouch_timer[id] = random(CROUCH_TICKS_MIN, CROUCH_TICKS_MAX)
                end
            end

            tryGrenadeThrow(id, tx, ty)
        end
    else
        ai_crouch(id, 0)
        vai_crouch_timer[id] = 0
        vai_shot_count[id]   = 0

        if fai_ticklkp(id) then
            fai_smoothaim(id, vai_lkp_x[id], vai_lkp_y[id], 0)
        else
            ai_aim(id, vai_aimx[id], vai_aimy[id])
        end
    end
end

function fai_fight(id)
    local tid = vai_target[id]

    if tid <= 0 or not p(tid, "exists") or p(tid, "health") <= 0 then
        if vai_lkp_timer[id] and vai_lkp_timer[id] > 0 then
            vai_mode[id]  = 5
            vai_smode[id] = 0
        else
            vai_mode[id] = 0
        end
        return
    end

    if p(id, "health") < PANIC_HP_THRESHOLD then
        fai_randomadjacent(id)
        vai_mode[id]  = 2
        vai_timer[id] = 0
        ai_crouch(id, 0)
        return
    end

    if itemtype(p(id, "weapontype"), "range") < 50 then
        if ai_goto(id, p(tid, "tilex"), p(tid, "tiley")) ~= 2 then
            vai_mode[id] = 0
        else
            fai_walkaim(id)
        end
        return
    end

    if vai_peek_state[id] == 1 then
        local bx    = p(id, "x");  local by = p(id, "y")
        local tx    = p(tid, "x"); local ty = p(tid, "y")
        local away  = (fai_angleto(tx, ty, bx, by)) % 360
        if ai_move(id, away) == 0 then
            ai_move(id, (away + 90) % 360)
        end
        fai_walkaim(id)

        vai_peek_timer[id] = vai_peek_timer[id] - 1
        if vai_peek_timer[id] <= 0 then
            vai_peek_state[id] = 0
            vai_peek_timer[id] = random(PEEK_EXPOSE_MIN, PEEK_EXPOSE_MAX)
        end
        return
    end

    vai_timer[id] = vai_timer[id] - 1
    if vai_timer[id] <= 0 then
        vai_timer[id] = random(50, 150)
        vai_smode[id] = random(0, 360)

        if random() < 0.25 then
            vai_peek_state[id] = 1
            vai_peek_timer[id] = random(PEEK_RETREAT_MIN, PEEK_RETREAT_MAX)
            return
        end

        local my_x = p(id, "x");   local my_y = p(id, "y")
        local tx   = p(tid, "x");  local ty   = p(tid, "y")
        if random(1, 2) == 1 and p(id, "health") > HUNT_MIN_HP
        and abs(my_x - tx) > HUNT_DIST_X
        and abs(my_y - ty) > HUNT_DIST_Y then
            vai_mode[id]  = 5
            vai_smode[id] = tid
        end
    end

    if ai_move(id, vai_smode[id]) == 0 then
        vai_smode[id] = vai_smode[id] + ((id % 2 == 0) and 45 or -45)
        vai_timer[id] = random(50, 150)
    end

    vai_is_moving[id] = 1
end

function fai_hunt(id)
    local tid = vai_smode[id]
    if tid and tid > 0 then
        if p(tid, "exists") and p(tid, "health") > 0 then
            if ai_goto(id, p(tid, "tilex"), p(tid, "tiley")) ~= 2 then
                vai_mode[id] = 0
            end
        else
            vai_smode[id] = 0
        end
        return
    end

    if vai_lkp_timer[id] and vai_lkp_timer[id] > 0 then
        local lx = vai_lkp_x[id]
        local ly = vai_lkp_y[id]
        local res = ai_goto(id, lx, ly)
        if res ~= 2 then
            vai_lkp_timer[id] = 0
            vai_mode[id] = 0
        else
            fai_walkaim(id)
        end
    else
        vai_mode[id] = 0
    end
end