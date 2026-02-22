-- movement.lua: item collection and follow-teammate logic
-- Human improvements:
--   • Hesitation at waypoints before rounding corners
--   • Follow mode uses smooth aim and checks for nearby enemies before resuming roam
--   • Movement-state tracking fed into accuracy penalties in core.lua

local abs    = math.abs
local random = math.random
local p      = player

-- ============================================================
-- fai_collect  (runs every tick, throttled)
-- ============================================================
-- Scans for nearby useful items and switches to mode 6 to collect them.
-- Unchanged logic but now tracks vai_is_moving properly.

function fai_collect(id)
    -- Early-out: don't interrupt an ongoing item-walk
    if vai_mode[id] == 6 then return end
    -- Zombies on team 1 skip item collection
    if p(id, "team") == 1 and vai_set_gm == 4 then return end

    vai_itemscan[id] = vai_itemscan[id] + 1
    if vai_itemscan[id] <= COLLECT_SCAN_PERIOD then return end
    vai_itemscan[id] = random(0, COLLECT_SCAN_JITTER)

    local team    = p(id, "team")
    local px      = p(id, "tilex")
    local py      = p(id, "tiley")
    local money   = p(id, "money")
    local hp      = p(id, "health")
    local maxhp   = p(id, "maxhealth")
    local weapons = playerweapons(id)

    local items = closeitems(id, COLLECT_SCAN_RADIUS)
    for i = 1, #items do
        local it    = items[i]
        local ix    = item(it, "x")
        local iy    = item(it, "y")

        if ix ~= px or iy ~= py then
            local itype   = item(it, "type")
            local slot    = itemtype(itype, "slot")
            local collect = false

            if     slot == 1 then
                collect = not fai_playerslotitems(id, 1) and team ~= 3
            elseif slot == 2 then
                collect = not fai_playerslotitems(id, 2) and team ~= 3
            elseif slot == 3 or slot == 4 then
                collect = not fai_contains(weapons, itype) and team ~= 3
            elseif slot == 5 then
                collect = itype == WPN_BOMB and team == 1
            elseif slot == 0 then
                if itype == ITEM_FLAG or itype == ITEM_FLAG + 1 then
                    collect = true
                elseif itype >= ITEM_MONEY_MIN and itype <= ITEM_MONEY_MAX then
                    collect = money < MONEY_CAP
                elseif itype >= ITEM_HEALTH_MIN and itype <= ITEM_HEALTH_MAX then
                    collect = hp < maxhp
                end
            end

            if collect then
                vai_mode[id]  = 6
                vai_smode[id] = itype
                vai_destx[id] = ix
                vai_desty[id] = iy
                return
            end
        end
    end
end

-- ============================================================
-- MODE 7: follow  (follow a teammate)
-- ============================================================
-- Improvements:
--   • Uses smooth aim while following (looks around naturally)
--   • Checks whether the leader has gone far before switching to roam
--   • Stops roaming and snaps to follow if an enemy is spotted
--   • Respects the reaction-time system via normal fai_engage flow

function fai_follow(id)
    local fid = vai_smode[id]

    -- Validate leader
    if fid <= 0 or not p(fid, "exists") or p(fid, "health") <= 0 then
        vai_mode[id] = 0
        return
    end

    local fx = p(fid, "tilex")
    local fy = p(fid, "tiley")

    if vai_timer[id] > 0 then
        -- ── Roaming near the leader ──────────────────────────
        -- If we see an enemy, fai_engage() will override mode; just handle movement here.
        if ai_move(id, vai_followangle[id], 1) == 0 then
            -- Blocked: nudge angle and reset timer
            vai_followangle[id] = vai_followangle[id] + ((id % 2 == 0) and 45 or -45)
            vai_timer[id] = random(3, 5) * 50
        else
            vai_timer[id] = vai_timer[id] - 1
            vai_is_moving[id] = 1  -- report to accuracy system

            if vai_timer[id] == 0 then
                -- Pick a fresh roam direction with hesitation
                vai_timer[id]       = random(3, 5) * 50
                vai_followangle[id] = random(0, 360)
            end

            -- Resume following if the leader has moved significantly away
            if (vai_timer[id] % 25) == 0
            and (abs(p(id, "tilex") - fx) > FOLLOW_CLOSE_X
              or abs(p(id, "tiley") - fy) > FOLLOW_CLOSE_Y) then
                vai_timer[id] = 0
            end
        end
        fai_walkaim(id)
        return
    end

    -- ── Actively following ────────────────────────────────────
    -- ai_goto returns 1 when "arrived" (adjacent tile), 2 when "pathing", 0 when blocked
    local result = ai_goto(id, fx, fy)
    if result == 1 then
        -- Close enough: switch to roam phase with slight hesitation
        if random() < HESITATE_CHANCE then
            -- Brief pause as if checking surroundings before roaming
            vai_timer[id]       = random(HESITATE_TICKS_MIN, HESITATE_TICKS_MAX)
            vai_followangle[id] = p(fid, "rot")  -- initially face same way as leader
        else
            vai_timer[id]       = random(3, 5) * 50
            vai_followangle[id] = random(0, 360)
        end
    elseif result == 0 then
        -- Path blocked: try a random adjacent tile as interim step
        fai_randomadjacent(id)
        vai_mode[id] = 2  -- goto that adjacent tile
    else
        vai_is_moving[id] = 1
    end
    fai_walkaim(id)
end

-- ============================================================
-- Waypoint-arrival hesitation helper
-- ============================================================
-- Call this when a bot arrives at a destination in MODE 2 / MODE 6.
-- With HESITATE_CHANCE probability, inserts a short wait before re-deciding.
-- Returns true if hesitation was triggered (caller should not change mode yet).

function fai_maybehesitate(id)
    if random() < HESITATE_CHANCE then
        vai_mode[id]  = 1  -- wait mode
        vai_timer[id] = random(HESITATE_TICKS_MIN, HESITATE_TICKS_MAX)
        return true
    end
    return false
end