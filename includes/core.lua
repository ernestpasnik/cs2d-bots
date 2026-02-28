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
vai_personality    = {}
vai_react_delay    = {}
vai_aim_smooth     = {}
vai_burst_size     = {}
vai_burst_pause    = {}
vai_spray_drift    = {}
vai_shot_count     = {}
vai_is_moving      = {}

-- Last-known-position memory
vai_lkp_x         = {}
vai_lkp_y         = {}
vai_lkp_timer     = {}

-- Peek / cover state
vai_peek_state    = {}
vai_peek_timer    = {}

-- Crouch state
vai_crouch_timer  = {}

-- Target acquisition delay
vai_react_timer   = {}

-- Post-plant guard/escape state (declared here so all modules share one namespace)
vai_bomb_guardx   = {}
vai_bomb_guardy   = {}
vai_bomb_rescan   = {}

-- ============================================================
-- INITIALISE PERSONALITY
-- ============================================================

local function assignPersonality(id)
    local skill = vai_set_botskill

    local p_type = random(1, 4)
    vai_personality[id] = p_type

    local skill_t = math.max(0, math.min(skill, 4)) / 4  -- 0.0 to 1.0 over the valid 0-4 range


    local base_react
    if p_type == PERSONALITY_AGGRESSIVE then
        base_react = REACT_TICKS_FAST
    elseif p_type == PERSONALITY_CAUTIOUS then
        base_react = REACT_TICKS_MED + 4
    else
        base_react = REACT_TICKS_MED
    end
    vai_react_delay[id] = math.floor(base_react * (1 - skill_t * 0.7))
    vai_react_delay[id] = math.max(vai_react_delay[id], 2)

    local base_smooth
    if p_type == PERSONALITY_AGGRESSIVE then
        base_smooth = AIM_SMOOTH_FAST
    elseif p_type == PERSONALITY_CAUTIOUS then
        base_smooth = AIM_SMOOTH_SLOW
    else
        base_smooth = AIM_SMOOTH_MED
    end
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

    vai_bomb_guardx[id] = 0
    vai_bomb_guardy[id] = 0
    vai_bomb_rescan[id] = 0
end

-- ============================================================
-- GENERAL UTILITIES
-- ============================================================

function fai_wait(id, nextMode)
    if vai_timer[id] > 0 then
        vai_timer[id] = vai_timer[id] - 1
    else
        vai_mode[id] = nextMode
    end
end

function fai_angledelta(a1, a2)
    local d = (a2 - a1) % 360
    if d > 180 then d = d - 360 end
    return d
end

function fai_angleto(x1, y1, x2, y2)
    return deg(atan2(x2 - x1, y1 - y2))
end

function fai_distsq(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx * dx + dy * dy
end

function fai_contains(t, e)
    for i = 1, #t do
        if t[i] == e then return true end
    end
    return false
end

function fai_playerslotitems(id, slot)
    local weapons = playerweapons(id)
    for i = 1, #weapons do
        if itemtype(weapons[i], "slot") == slot then return true end
    end
    return false
end

function fai_smoothaim(id, tx, ty, tid)
    local bx  = p(id, "x")
    local by  = p(id, "y")
    local rot = p(id, "rot")

    local target_ang = fai_angleto(bx, by, tx, ty)

    local dist = sqrt(fai_distsq(bx, by, tx, ty))
    local dist_penalty = 0
    if dist > ACC_FULL_RANGE then
        dist_penalty = ((dist - ACC_FULL_RANGE) / ACC_FULL_RANGE) * ACC_FAR_PENALTY
        dist_penalty = math.min(dist_penalty, ACC_FAR_PENALTY)
    end

    local move_penalty = (vai_is_moving[id] == 1) and ACC_MOVE_PENALTY or 0
    local drift = vai_spray_drift[id]

    local total_noise = dist_penalty + move_penalty + drift
    local noise_offset = 0
    if total_noise > 0 then
        noise_offset = (random() * 2 - 1) * total_noise
    end

    target_ang = target_ang + noise_offset

    local delta   = fai_angledelta(rot, target_ang)
    local speed   = vai_aim_smooth[id] or AIM_SMOOTH_MED
    local step    = math.max(-speed, math.min(speed, delta))
    local new_rot = (rot + step) % 360

    if vai_burst_pause[id] > 0 or vai_shot_count[id] == 0 then
        drift = math.max(0, drift - SPRAY_RECOVER_RATE)
        vai_spray_drift[id] = drift
    end

    ai_rotate(id, new_rot)

    return abs(fai_angledelta(new_rot, fai_angleto(bx, by, tx, ty)))
end

function fai_walkaim(id)
    local x  = p(id, "x")
    local y  = p(id, "y")
    local px = vai_px[id]
    local py = vai_py[id]

    local a = rad(deg(atan2(x - px, py - y)))
    local wx = x + sin(a) * 150
    local wy = y - cos(a) * 150

    ai_aim(id, wx, wy)

    vai_is_moving[id] = ((px ~= x or py ~= y) and 1 or 0)

    if px ~= x then vai_px[id] = x end
    if py ~= y then vai_py[id] = y end
end

function fai_enemies(id1, id2)
    local t1 = p(id1, "team")
    local t2 = p(id2, "team")
    if t1 == t2    then return vai_set_gm == 1 end
    if t1 >= 2 and t2 >= 2 then return false end
    return true
end

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

function fai_setdest(id, entityType, mode)
    local x, y = randomentity(entityType)
    if x == NO_ENTITY then return false end
    vai_destx[id] = x
    vai_desty[id] = y
    vai_mode[id]  = mode or 2
    return true
end

function fai_updatelpk(id, tx, ty)
    vai_lkp_x[id]     = tx
    vai_lkp_y[id]     = ty
    vai_lkp_timer[id] = LKP_MEMORY_TICKS
end

function fai_ticklkp(id)
    if vai_lkp_timer[id] > 0 then
        vai_lkp_timer[id] = vai_lkp_timer[id] - 1
        return vai_lkp_timer[id] > 0
    end
    return false
end