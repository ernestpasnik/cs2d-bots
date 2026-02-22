-- Wait
-- id: player id
-- mode: switch to this mode
function fai_wait(id, mode)
    local t = vai_timer[id]
    if t > 0 then
        vai_timer[id] = t - 1
    else
        vai_mode[id] = mode
    end
end

-- Angle Delta
-- a1: angle 1
-- a2: angle 2
function fai_angledelta(a1, a2)
    local d = (a2 - a1) % 360
    if d > 180 then
        d = d - 360
    elseif d < -180 then
        d = d + 360
    end
    return d
end

-- Angle to
-- x1|y1: position 1
-- x2|y2: position 2
do
    local atan2 = math.atan2
    local deg   = math.deg
    function fai_angleto(x1, y1, x2, y2)
        return deg(atan2(x2 - x1, y1 - y2))
    end
end

-- Checks if table t has element e
-- t: table
-- e: element
function fai_contains(t, e)
    for _, value in pairs(t) do
        if value == e then
            return true
        end
    end
    return false
end

-- Check if player has item in certain slot
-- id: player id
-- slot: slot
function fai_playerslotitems(id, slot)
    local items = playerweapons(id)
    for i = 1, #items do
        if itemtype(items[i], "slot") == slot then
            return true
        end
    end
    return false
end

-- Walk Aim - aim in walking direction
-- id: player
do
    local p   = player
    local sin = math.sin
    local cos = math.cos
    local atan2 = math.atan2
    local deg = math.deg
    local rad = math.rad

    function fai_walkaim(id)
        local x = p(id, "x")
        local y = p(id, "y")
        local px = vai_px[id] or x
        local py = vai_py[id] or y

        local angle = deg(atan2(x - px, py - y))
        local a_rad = rad(angle)

        ai_aim(id, x + sin(a_rad) * 150, y - cos(a_rad) * 150)

        if px ~= x then vai_px[id] = x end
        if py ~= y then vai_py[id] = y end
    end
end

-- Are two given players enemies?
-- id1: player 1
-- id2: player 2
do
    local p = player
    function fai_enemies(id1, id2)
        local t1 = p(id1, "team")
        local t2 = p(id2, "team")

        if t1 ~= t2 then
            if t1 >= 2 and t2 >= 2 then
                -- VIP special case: CT (2) and VIP (3) are not enemies
                return false
            else
                return true
            end
        elseif vai_set_gm == 1 then
            -- Deathmatch mode
            return true
        end

        return false
    end
end

-- Get random (living) teammate
-- id: get random mate of this player (player id)
do
    local p = player
    local r = math.random
    function fai_randommate(id)
        local team = p(id, "team")
        if team > 2 then team = 2 end

        local players = p(0, "team" .. team .. "living")
        local count = #players
        if count == 0 then
            return 0
        end

        for i = 1, 10 do
            local idx = r(1, count)
            local pid = players[idx]
            if pid ~= id then
                return pid
            end
        end

        return 0
    end
end

-- Set destination to random adjacent tile
do
    local p   = player
    local r   = math.random
    local tilewalk = tile

    function fai_randomadjacent(id)
        local px = p(id, "tilex")
        local py = p(id, "tiley")  -- fixed bug: was "tilex"

        for i = 1, 20 do
            local x = px + r(-1, 1)
            local y = py + r(-1, 1)

            if (x ~= px or y ~= py) and tilewalk(x, y, "walkable") then
                vai_destx[id] = x
                vai_desty[id] = y
                return
            end
        end
    end
end
