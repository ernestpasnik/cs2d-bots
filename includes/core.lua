-- core.lua: server settings + shared utility functions

dofile("bots/constants.lua")

local abs    = math.abs
local sin    = math.sin
local cos    = math.cos
local deg    = math.deg
local rad    = math.rad
local atan2  = math.atan2  -- Lua 5.1/LuaJIT; replace with math.atan(y,x) on 5.3+
local random = math.random
local p      = player

-- Settings globals; refreshed on every spawn and death so live server changes apply
vai_set_gm         = 0
vai_set_botskill   = 0
vai_set_botweapons = 0
vai_set_debug      = 0

function fai_update_settings()
    vai_set_gm         = game("sv_gamemode")
    vai_set_botskill   = game("bot_skill")
    vai_set_botweapons = game("bot_weapons")
    vai_set_debug      = game("debugai")
end

-- Counts vai_timer down by one each tick; switches to nextMode when it hits zero
function fai_wait(id, nextMode)
    if vai_timer[id] > 0 then
        vai_timer[id] = vai_timer[id] - 1
    else
        vai_mode[id] = nextMode
    end
end

-- Shortest signed angular difference in degrees, result in (-180, 180]
-- (x % 360) is always [0, 360) in Lua, so only the > 180 branch is needed
function fai_angledelta(a1, a2)
    local d = (a2 - a1) % 360
    if d > 180 then d = d - 360 end
    return d
end

-- Bearing in degrees from (x1,y1) to (x2,y2)
function fai_angleto(x1, y1, x2, y2)
    return deg(atan2(x2 - x1, y1 - y2))
end

-- Returns true if array t contains value e
function fai_contains(t, e)
    for i = 1, #t do
        if t[i] == e then return true end
    end
    return false
end

-- Returns true if the player has any weapon occupying the given inventory slot
function fai_playerslotitems(id, slot)
    local weapons = playerweapons(id)
    for i = 1, #weapons do
        if itemtype(weapons[i], "slot") == slot then return true end
    end
    return false
end

-- Points the bot's aim in the direction it is currently walking,
-- derived from the delta between current and last recorded position
function fai_walkaim(id)
    local x  = p(id, "x")
    local y  = p(id, "y")
    local px = vai_px[id]
    local py = vai_py[id]

    local a = rad(deg(atan2(x - px, py - y)))
    ai_aim(id, x + sin(a) * 150, y - cos(a) * 150)

    if px ~= x then vai_px[id] = x end
    if py ~= y then vai_py[id] = y end
end

-- Returns true when id1 and id2 are on opposing teams.
-- VIP (team 3) counts as allied with CT (team 2).
-- In deathmatch everyone is an enemy regardless of team.
function fai_enemies(id1, id2)
    local t1 = p(id1, "team")
    local t2 = p(id2, "team")
    if t1 == t2    then return vai_set_gm == 1 end
    if t1 >= 2 and t2 >= 2 then return false end
    return true
end

-- Returns the ID of a random living teammate other than id, or 0 if none exist
function fai_randommate(id)
    local team = p(id, "team")
    if team > 2 then team = 2 end

    local list  = p(0, "team" .. team .. "living")
    local count = #list
    if count == 0 then return 0 end

    for _ = 1, 10 do
        local pid = list[random(1, count)]
        if pid ~= id then return pid end
    end
    return 0
end

-- Sets vai_destx/y to a random walkable tile adjacent to the bot's current tile
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

-- Picks a random entity of entityType, assigns it as the destination, and sets
-- vai_mode. Returns false and leaves state unchanged if no such entity exists.
function fai_setdest(id, entityType, mode)
    local x, y = randomentity(entityType)
    if x == NO_ENTITY then return false end
    vai_destx[id] = x
    vai_desty[id] = y
    vai_mode[id]  = mode or 2
    return true
end
