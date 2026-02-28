-- objectives.lua: bomb plant/defuse, hostage rescue, post-plant guard, and bomb escape

local abs    = math.abs
local random = math.random
local sqrt   = math.sqrt
local p      = player
local hst    = hostage

-- ============================================================
-- INTERNAL: locate the planted bomb item
-- Returns tile x, tile y or nil if not found.
-- ============================================================
local function findPlantedBombTile()
    local items = item(0, "table")
    for i = 1, #items do
        local it = items[i]
        if item(it, "type") == ITEM_BOMB_PLANTED then
            return item(it, "x"), item(it, "y")
        end
    end
    return nil, nil
end

-- ============================================================
-- INTERNAL: count enemies visible to bot id
-- Uses a simple proximity check combined with ai_freeline.
-- ============================================================
local function countVisibleEnemies(id)
    local bx   = p(id, "x")
    local by   = p(id, "y")
    local team = p(id, "team")
    local count = 0
    for pid = 1, MAX_PLAYERS do
        if p(pid, "exists") and p(pid, "health") > 0 then
            local eteam = p(pid, "team")
            if fai_enemies(id, pid) then
                local ex = p(pid, "x")
                local ey = p(pid, "y")
                if abs(bx - ex) < VIEW_HALF_W and abs(by - ey) < VIEW_HALF_H then
                    if ai_freeline(id, ex, ey) then
                        count = count + 1
                    end
                end
            end
        end
    end
    return count
end

-- ============================================================
-- MODE 51: plant the bomb
-- ============================================================
function fai_plantbomb(id)
    if not p(id, "bomb") then
        vai_mode[id] = 0
        return
    end

    local tx = p(id, "tilex")
    local ty = p(id, "tiley")

    if inentityzone(tx, ty, ENT_BOMBSPOT) then
        if p(id, "weapontype") ~= WPN_BOMB then
            ai_selectweapon(id, WPN_BOMB)
            return
        end
        if vai_timer[id] == 0 then
            ai_radio(id, RADIO_COVER_ME)
            vai_timer[id] = 1
        end
        ai_attack(id)
        return
    end

    -- Still navigating to the bombspot.
    if ai_goto(id, vai_destx[id], vai_desty[id]) ~= 2 then
        local x, y = randomentity(ENT_BOMBSPOT)
        if x ~= NO_ENTITY then
            vai_destx[id] = x
            vai_desty[id] = y
        end
    else
        fai_walkaim(id)
    end
end

-- ============================================================
-- MODE 53: T-side post-plant guard
-- Bot camps within BOMB_CAMP_RADIUS tiles of the planted bomb.
-- Periodically re-scans to confirm the bomb is still present.
-- Switches to mode 54 (escape) when the round timer is dangerously low.
-- fai_engage() handles shooting any CTs that push the site.
-- ============================================================
function fai_guardbomb(id)
    -- ── Escape check: if bomb timer is nearly expired, flee ──
    -- game("timeleft") returns remaining round time in ticks on most builds;
    -- fall back to a rescan-counter heuristic if the API is unavailable.
    local timeleft = game("timeleft")
    if timeleft and timeleft > 0 and timeleft <= BOMB_ESCAPE_TICKS then
        vai_mode[id] = 54
        fai_randomadjacent(id)   -- pick initial escape tile
        return
    end

    -- ── Re-scan: confirm the bomb is still planted ────────────
    vai_bomb_rescan[id] = vai_bomb_rescan[id] - 1
    if vai_bomb_rescan[id] <= 0 then
        vai_bomb_rescan[id] = BOMB_CAMP_RESCAN
        local bx, by = findPlantedBombTile()
        if bx then
            vai_bomb_guardx[id] = bx
            vai_bomb_guardy[id] = by
        else
            -- Bomb defused or round over; stop guarding
            vai_mode[id] = 0
            return
        end
    end

    local gx = vai_bomb_guardx[id]
    local gy = vai_bomb_guardy[id]
    if gx == 0 and gy == 0 then
        vai_mode[id] = 0
        return
    end

    local tx = p(id, "tilex")
    local ty = p(id, "tiley")

    -- If already close to the bomb, hold position and use fight/wait logic.
    if abs(tx - gx) <= BOMB_CAMP_RADIUS and abs(ty - gy) <= BOMB_CAMP_RADIUS then
        -- Hold here; fai_engage() will handle any targets that appear.
        -- Strafe slightly for variety but don't leave the site.
        if vai_target[id] > 0 then
            -- fai_fight-style micro-strafe while guarding
            if ai_move(id, vai_smode[id]) == 0 then
                vai_smode[id] = (vai_smode[id] + ((id % 2 == 0) and 45 or -45)) % 360
            end
            vai_is_moving[id] = 1
        else
            -- No visible enemy; pick a random nearby watch angle
            if vai_timer[id] <= 0 then
                vai_smode[id] = math.random(0, 360)
                vai_timer[id] = math.random(30, 80)
                ai_rotate(id, vai_smode[id])
            else
                vai_timer[id] = vai_timer[id] - 1
            end
        end
    else
        -- Navigate back toward the bomb site.
        local result = ai_goto(id, gx, gy)
        if result ~= 2 then
            -- Blocked; just wait in place
            fai_randomadjacent(id)
        else
            fai_walkaim(id)
            vai_is_moving[id] = 1
        end
    end
end

-- ============================================================
-- MODE 54: T-side bomb escape
-- Bot sprints away from the bomb before it detonates.
-- Keeps running until it is far enough away or the round ends.
-- ============================================================
function fai_escapebomb(id)
    local gx = vai_bomb_guardx[id]
    local gy = vai_bomb_guardy[id]

    -- If we don't know where the bomb is, just roam away.
    if gx == 0 and gy == 0 then
        local bx, by = findPlantedBombTile()
        if bx then
            vai_bomb_guardx[id] = bx
            vai_bomb_guardy[id] = by
            gx = bx
            gy = by
        else
            vai_mode[id] = 0
            return
        end
    end

    local bx = p(id, "x")
    local by = p(id, "y")

    -- Convert bomb tile coords to pixel coords (CS2D tiles are 32px)
    local bomb_px = gx * 32
    local bomb_py = gy * 32

    local dx = bx - bomb_px
    local dy = by - bomb_py
    local dsq = dx * dx + dy * dy

    if dsq >= BOMB_ESCAPE_DIST_SQ then
        -- Far enough; stop fleeing, re-decide
        vai_mode[id] = 0
        return
    end

    -- Move away from the bomb
    local away_angle = fai_angleto(bomb_px, bomb_py, bx, by) % 360
    if ai_move(id, away_angle) == 0 then
        -- Blocked; try a 90-degree offset
        local alt = (away_angle + (id % 2 == 0 and 90 or -90)) % 360
        if ai_move(id, alt) == 0 then
            fai_randomadjacent(id)
            vai_mode[id] = 2
        end
    end
    vai_is_moving[id] = 1
end

-- ============================================================
-- Redirects all CT bots searching a cleared sector to try others
-- ============================================================
local function redirectBotsFrom(oldx, oldy)
    local bots = p(0, "bot")
    for i = 1, #bots do
        local b = bots[i]
        if vai_mode[b] == 52 and vai_destx[b] == oldx and vai_desty[b] == oldy then
            local x, y = randomentity(ENT_BOMBSPOT, 0)
            if x ~= NO_ENTITY then
                vai_destx[b] = x
                vai_desty[b] = y
            end
            vai_smode[b] = 0
        end
    end
end

-- ============================================================
-- MODE 52: CT defuse
-- smode 0 = searching bombsites
-- smode 1 = pathing to the actual bomb to defuse
-- When smode 0 and the bot spots the bomb alone, it rushes immediately.
-- ============================================================
function fai_defuse(id)
    local tx = p(id, "tilex")
    local ty = p(id, "tiley")

    if vai_smode[id] == 0 then
        -- Try to shortcut: if we can see the bomb and nobody is fighting, rush it.
        local bx, by = findPlantedBombTile()
        if bx then
            local enemies_nearby = countVisibleEnemies(id)
            if enemies_nearby == 0 then
                -- No enemies visible; rush straight to the bomb
                vai_destx[id] = bx
                vai_desty[id] = by
                vai_smode[id] = 1
                return
            end
            -- Enemies present; still update destination to the real bomb location
            -- but let fai_engage handle the fight first
            vai_destx[id] = bx
            vai_desty[id] = by
        end

        -- Navigate to current search sector
        if ai_goto(id, vai_destx[id], vai_desty[id]) ~= 2 then
            local x, y = randomentity(ENT_BOMBSPOT, 0)
            if x ~= NO_ENTITY then
                vai_destx[id] = x
                vai_desty[id] = y
            end
        else
            fai_walkaim(id)
        end

        -- On arrival, scan for the planted bomb item
        if abs(tx - vai_destx[id]) < BOMB_SECTOR_RADIUS
        and abs(ty - vai_desty[id]) < BOMB_SECTOR_RADIUS then
            local items = item(0, "table")
            for i = 1, #items do
                local it = items[i]
                if item(it, "type") == ITEM_BOMB_PLANTED then
                    local ix = item(it, "x")
                    local iy = item(it, "y")
                    if abs(tx - ix) < BOMB_SEARCH_RADIUS
                    and abs(ty - iy) < BOMB_SEARCH_RADIUS then
                        vai_destx[id] = ix
                        vai_desty[id] = iy
                        vai_smode[id] = 1
                        return
                    end
                end
            end

            -- Sector clear: mark it and redirect other bots
            setentityaistate(vai_destx[id], vai_desty[id], 1)
            ai_radio(id, RADIO_AREA_CLEAR)
            redirectBotsFrom(vai_destx[id], vai_desty[id])

            local x, y = randomentity(ENT_BOMBSPOT, 0)
            if x ~= NO_ENTITY then
                vai_destx[id] = x
                vai_desty[id] = y
            end
        end
    else
        local result = ai_goto(id, vai_destx[id], vai_desty[id])
        if result == 1 then
            -- Adjacent to bomb: hold USE to defuse
            if vai_timer[id] == 0 then
                ai_radio(id, RADIO_COVER_ME)
                vai_timer[id] = 1
            end
            ai_use(id)
        elseif result == 0 then
            -- Path blocked; give up and re-decide
            vai_mode[id] = 0
        else
            fai_walkaim(id)
        end
    end
end

-- ============================================================
-- MODE 50: rescue hostages
-- smode 0 = collecting hostages   |   smode 1 = escorting to rescue point
-- ============================================================
function fai_rescuehostages(id)
    if vai_smode[id] == 0 then
        if ai_goto(id, vai_destx[id], vai_desty[id]) ~= 2 then
            vai_mode[id] = 0
            return
        end
        fai_walkaim(id)

        -- Use any free hostage within reach
        local bx = p(id, "x")
        local by = p(id, "y")
        local list = hst(0, "table")
        for i = 1, #list do
            local hid = list[i]
            if hst(hid, "health") > 0 and hst(hid, "follow") == 0 then
                local hx = hst(hid, "x")
                local hy = hst(hid, "y")
                if abs(bx - hx) <= HOSTAGE_USE_RANGE
                and abs(by - hy) <= HOSTAGE_USE_RANGE then
                    ai_rotate(id, fai_angleto(bx, by, hx, hy))
                    ai_use(id)
                    break
                end
            end
        end

        local dx, dy = closehostage(id)
        if dx == NO_ENTITY then
            vai_smode[id] = 1
            dx, dy = randomentity(ENT_RESCUE)
            if dx == NO_ENTITY then
                dx, dy = randomentity(ENT_CT_SPAWN)
            end
        end
        if dx ~= NO_ENTITY then
            vai_destx[id] = dx
            vai_desty[id] = dy
        end
    else
        local result = ai_goto(id, vai_destx[id], vai_desty[id])
        if result == 1 then
            -- Reached rescue zone; roam briefly before next decision
            vai_mode[id]  = 3
            vai_timer[id] = math.random(150, 300)
            vai_smode[id] = math.random(0, 360)
        elseif result == 0 then
            vai_mode[id] = 0
        else
            fai_walkaim(id)
        end
    end
end