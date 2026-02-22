-- objectives.lua: bomb plant/defuse and hostage rescue

local abs    = math.abs
local random = math.random
local p      = player
local hst    = hostage

-- MODE 51: walk to a bombspot and plant.
-- Drops out of this mode if the bot no longer carries the bomb.
function fai_plantbomb(id)
    if not p(id, "bomb") then
        vai_mode[id] = 0
        return
    end

    local tx = p(id, "tilex")
    local ty = p(id, "tiley")

    -- inentityzone alone is sufficient; the old tile-entity check was
    -- preventing planting in multi-tile bombzones
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

    -- Still navigating to the bombspot
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

-- Redirects all bots currently heading toward a sector that was just cleared,
-- so they fan out to remaining sites instead of stacking on a searched one
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

-- MODE 52: search bombsites for the planted bomb, then defuse it.
--   smode 0 = searching  |  smode 1 = pathing to/defusing the bomb
function fai_defuse(id)
    local tx = p(id, "tilex")
    local ty = p(id, "tiley")

    if vai_smode[id] == 0 then
        -- Navigate to the current search sector
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

            -- Sector clear: mark it and send other bots elsewhere
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
            vai_mode[id] = 0  -- path blocked; give up and re-decide
        else
            fai_walkaim(id)   -- still pathing
        end
    end
end

-- MODE 50: pick up all hostages then escort them to the rescue zone.
--   smode 0 = collecting hostages  |  smode 1 = escorting to rescue point
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

        -- Validate before writing to avoid a one-tick NO_ENTITY destination
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
            -- Reached rescue zone: roam briefly before next decision
            vai_mode[id]  = 3
            vai_timer[id] = random(150, 300)
            vai_smode[id] = random(0, 360)
        elseif result == 0 then
            vai_mode[id] = 0
        else
            fai_walkaim(id)
        end
    end
end
