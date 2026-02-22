--------------------------------------------------
-- General Utilities
--------------------------------------------------

-- Cached stdlib references
local abs   = math.abs
local sin   = math.sin
local cos   = math.cos
local deg   = math.deg
local rad   = math.rad
local atan2 = math.atan2
local random= math.random
local p     = player

--------------------------------------------------
-- fai_wait(id, nextMode)
-- Counts down vai_timer; switches mode when done.
--------------------------------------------------
function fai_wait(id, nextMode)
    local t = vai_timer[id]
    if t > 0 then
        vai_timer[id] = t - 1
    else
        vai_mode[id] = nextMode
    end
end

--------------------------------------------------
-- fai_angledelta(a1, a2)
-- Shortest signed angular difference (−180..180).
--------------------------------------------------
function fai_angledelta(a1, a2)
    local d = (a2 - a1) % 360
    if d > 180 then
        return d - 360
    elseif d < -180 then
        return d + 360
    end
    return d
end

--------------------------------------------------
-- fai_angleto(x1, y1, x2, y2)
-- Returns bearing from point 1 → point 2 in degrees.
--------------------------------------------------
function fai_angleto(x1, y1, x2, y2)
    return deg(atan2(x2 - x1, y1 - y2))
end

--------------------------------------------------
-- fai_contains(t, e)
-- Returns true if table t contains value e.
--------------------------------------------------
function fai_contains(t, e)
    for i = 1, #t do
        if t[i] == e then return true end
    end
    return false
end

--------------------------------------------------
-- fai_playerslotitems(id, slot)
-- Returns true if the player has any weapon in
-- the given inventory slot.
--------------------------------------------------
function fai_playerslotitems(id, slot)
    local items = playerweapons(id)
    for i = 1, #items do
        if itemtype(items[i], "slot") == slot then
            return true
        end
    end
    return false
end

--------------------------------------------------
-- fai_walkaim(id)
-- Aims the bot in its current movement direction.
--------------------------------------------------
function fai_walkaim(id)
    local x  = p(id, "x")
    local y  = p(id, "y")
    local px = vai_px[id]
    local py = vai_py[id]

    -- Derive heading from last recorded position
    local angle = deg(atan2(x - px, py - y))
    local a_rad = rad(angle)

    ai_aim(id, x + sin(a_rad) * 150, y - cos(a_rad) * 150)

    -- Update only when position changes (avoid redundant writes)
    if px ~= x then vai_px[id] = x end
    if py ~= y then vai_py[id] = y end
end

--------------------------------------------------
-- fai_enemies(id1, id2)
-- Returns true if the two players are on opposing
-- teams (accounts for VIP and Deathmatch modes).
--------------------------------------------------
function fai_enemies(id1, id2)
    local t1 = p(id1, "team")
    local t2 = p(id2, "team")

    if t1 == t2 then
        -- Only enemies in Deathmatch (gm 1)
        return vai_set_gm == 1
    end

    -- CT (2) and VIP (3) are allies
    if t1 >= 2 and t2 >= 2 then
        return false
    end

    return true
end

--------------------------------------------------
-- fai_randommate(id)
-- Returns the ID of a random living teammate,
-- or 0 if none found.
--------------------------------------------------
function fai_randommate(id)
    local team = p(id, "team")
    if team > 2 then team = 2 end

    local players = p(0, "team" .. team .. "living")
    local count   = #players
    if count == 0 then return 0 end

    for _ = 1, 10 do
        local pid = players[random(1, count)]
        if pid ~= id then return pid end
    end

    return 0
end

--------------------------------------------------
-- fai_randomadjacent(id)
-- Sets the bot's destination to a random walkable
-- tile adjacent to its current position.
--------------------------------------------------
function fai_randomadjacent(id)
    local px = p(id, "tilex")
    local py = p(id, "tiley")

    for _ = 1, 20 do
        local nx = px + random(-1, 1)
        local ny = py + random(-1, 1)
        if (nx ~= px or ny ~= py) and tile(nx, ny, "walkable") then
            vai_destx[id] = nx
            vai_desty[id] = ny
            return
        end
    end
end
