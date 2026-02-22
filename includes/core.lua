-- core.lua: server settings + shared utility functions

dofile("bots/includes/constants.lua")

local abs    = math.abs
local sin    = math.sin
local cos    = math.cos
local deg    = math.deg
local rad    = math.rad
local atan2  = math.atan2  -- Lua 5.1/LuaJIT; replace with math.atan(y,x) on 5.3+
local random = math.random
local sqrt   = math.sqrt
local p      = player

-- Settings globals; refreshed on every spawn and death so live server changes apply
vai_set_gm         = 0
vai_set_botskill   = 0
vai_set_botweapons = 0
vai_set_debug      = 0

-- ============================================================
-- PERSONALITY & SKILL STATE (indexed by player ID)
-- ============================================================
-- Each bot gets a randomly assigned personality and derived skill traits on spawn.
-- These persist for the bot's lifetime so behaviour feels consistent per-bot.

vai_personality    = {}  -- PERSONALITY_* archetype
vai_react_delay    = {}  -- ticks before locking onto a spotted target
vai_aim_smooth     = {}  -- degrees per tick of aim rotation speed
vai_burst_size     = {}  -- shots per burst (remaining)
vai_burst_pause    = {}  -- ticks until next burst allowed
vai_spray_drift    = {}  -- accumulated recoil drift in degrees
vai_shot_count     = {}  -- consecutive shots fired this engagement
vai_is_moving      = {}  -- 1 if bot moved last tick (for accuracy penalty)

-- Last-known-position memory
vai_lkp_x         = {}  -- last known enemy X (pixels)
vai_lkp_y         = {}  -- last known enemy Y
vai_lkp_timer     = {}  -- ticks remaining before memory fades

-- Peek / cover state
vai_peek_state    = {}  -- 0 = exposed, 1 = retreating to cover
vai_peek_timer    = {}  -- ticks until next peek state change

-- Crouch state
vai_crouch_timer  = {}  -- >0 means bot is crouching this many ticks

-- Target acquisition delay (reaction time simulation)
vai_react_timer   = {}  -- counts down; bot doesn't engage until 0

-- ============================================================
-- INITIALISE PERSONALITY
-- ============================================================

local function assignPersonality(id)
    local skill = vai_set_botskill  -- 0-5 typically

    -- Roll a random personality archetype
    local p_type = random(1, 4)
    vai_personality[id] = p_type

    -- Derive skill-scaled traits
    -- Higher skill = faster reaction, smoother aim, better burst control
    local skill_t = math.max(0, math.min(skill, 5)) / 5  -- 0.0 to 1.0

    -- Reaction delay: skill 0 = slow, skill 5 = fast
    local base_react
    if p_type == PERSONALITY_AGGRESSIVE then
        base_react = REACT_TICKS_FAST
    elseif p_type == PERSONALITY_CAUTIOUS then
        base_react = REACT_TICKS_MED + 4
    else
        base_react = REACT_TICKS_MED
    end
    -- Blend toward fast at higher skill
    vai_react_delay[id] = math.floor(base_react * (1 - skill_t * 0.7))
    vai_react_delay[id] = math.max(vai_react_delay[id], 2)

    -- Aim smoothing speed
    local base_smooth
    if p_type == PERSONALITY_AGGRESSIVE then
        base_smooth = AIM_SMOOTH_FAST
    elseif p_type == PERSONALITY_CAUTIOUS then
        base_smooth = AIM_SMOOTH_SLOW
    else
        base_smooth = AIM_SMOOTH_MED
    end
    -- Scale up with skill, add slight per-bot jitter so no two bots aim identically
    vai_aim_smooth[id] = base_smooth + math.floor(skill_t * 15) + random(-2, 2)
    vai_aim_smooth[id] = math.max(vai_aim_smooth[id], 8)
end

-- ============================================================
-- SETTINGS
-- ============================================================

function fai_update_settings()
    vai_set_gm         = game("sv_gamemode")
    vai_set_botskill   = game("bot_skill")
    vai_set_botweapons = game("bot_weapons")
    vai_set_debug      = game("debugai")
end

-- ============================================================
-- INIT PER-SPAWN STATE
-- ============================================================

function fai_init_humanstate(id)
    assignPersonality(id)

    vai_burst_size[id]  = random(BURST_SIZE_MIN, BURST_SIZE_MAX)
    vai_burst_pause[id] = 0
    vai_spray_drift[id] = 0
    vai_shot_count[id]  = 0
    vai_is_moving[id]   = 0

    vai_lkp_x[id]       = 0
    vai_lkp_y[id]       = 0
    vai_lkp_timer[id]   = 0

    vai_peek_state[id]  = 0
    vai_peek_timer[id]  = 0

    vai_crouch_timer[id]= 0
    vai_react_timer[id] = 0
end

-- ============================================================
-- GENERAL UTILITIES
-- ============================================================

-- Counts vai_timer down by one each tick; switches to nextMode when it hits zero
function fai_wait(id, nextMode)
    if vai_timer[id] > 0 then
        vai_timer[id] = vai_timer[id] - 1
    else
        vai_mode[id] = nextMode
    end
end

-- Shortest signed angular difference in degrees, result in (-180, 180]
function fai_angledelta(a1, a2)
    local d = (a2 - a1) % 360
    if d > 180 then d = d - 360 end
    return d
end

-- Bearing in degrees from (x1,y1) to (x2,y2)
function fai_angleto(x1, y1, x2, y2)
    return deg(atan2(x2 - x1, y1 - y2))
end

-- Euclidean pixel distance squared (cheaper than sqrt)
function fai_distsq(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx * dx + dy * dy
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

-- Smoothly rotate the bot's aim toward (tx, ty) by at most vai_aim_smooth[id]
-- degrees per call.  This makes aiming feel organic instead of snap-instant.
-- Adds optional drift (recoil) and distance/movement accuracy penalties.
function fai_smoothaim(id, tx, ty, tid)
    local bx  = p(id, "x")
    local by  = p(id, "y")
    local rot = p(id, "rot")

    -- Compute base target angle
    local target_ang = fai_angleto(bx, by, tx, ty)

    -- Distance-based accuracy penalty
    local dist = sqrt(fai_distsq(bx, by, tx, ty))
    local dist_penalty = 0
    if dist > ACC_FULL_RANGE then
        dist_penalty = ((dist - ACC_FULL_RANGE) / ACC_FULL_RANGE) * ACC_FAR_PENALTY
        dist_penalty = math.min(dist_penalty, ACC_FAR_PENALTY)
    end

    -- Movement accuracy penalty
    local move_penalty = (vai_is_moving[id] == 1) and ACC_MOVE_PENALTY or 0

    -- Spray / recoil drift
    local drift = vai_spray_drift[id]

    -- Total noise: randomised each tick within the penalty envelope
    local total_noise = dist_penalty + move_penalty + drift
    local noise_offset = 0
    if total_noise > 0 then
        noise_offset = (random() * 2 - 1) * total_noise
    end

    target_ang = target_ang + noise_offset

    -- Smooth rotation: step toward target_ang by at most aim_smooth degrees
    local delta   = fai_angledelta(rot, target_ang)
    local speed   = vai_aim_smooth[id] or AIM_SMOOTH_MED
    local step    = math.max(-speed, math.min(speed, delta))
    local new_rot = (rot + step) % 360

    -- Recover spray drift gradually when not firing
    if vai_burst_pause[id] > 0 or vai_shot_count[id] == 0 then
        drift = math.max(0, drift - SPRAY_RECOVER_RATE)
        vai_spray_drift[id] = drift
    end

    ai_rotate(id, new_rot)

    -- Return how far off we still are (used by combat.lua to decide whether to fire)
    return abs(fai_angledelta(new_rot, fai_angleto(bx, by, tx, ty)))
end

-- Points the bot's aim in the direction it is currently walking,
-- derived from the delta between current and last recorded position.
-- Uses smooth aim system so walk-aiming is also gradual.
function fai_walkaim(id)
    local x  = p(id, "x")
    local y  = p(id, "y")
    local px = vai_px[id]
    local py = vai_py[id]

    local a = rad(deg(atan2(x - px, py - y)))
    local wx = x + sin(a) * 150
    local wy = y - cos(a) * 150

    -- Use smooth aim toward walk direction
    ai_aim(id, wx, wy)

    -- Track movement for accuracy penalty
    vai_is_moving[id] = ((px ~= x or py ~= y) and 1 or 0)

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

-- Update the last-known-position for enemy tid as seen by bot id
function fai_updatelpk(id, tx, ty)
    vai_lkp_x[id]     = tx
    vai_lkp_y[id]     = ty
    vai_lkp_timer[id] = LKP_MEMORY_TICKS
end

-- Tick down the LKP memory; returns true if a valid memory still exists
function fai_ticklkp(id)
    if vai_lkp_timer[id] > 0 then
        vai_lkp_timer[id] = vai_lkp_timer[id] - 1
        return vai_lkp_timer[id] > 0
    end
    return false
end