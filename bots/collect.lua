--------------------------------------------------
-- Item Collection
--------------------------------------------------

-- Minimum scan period (ticks)
local SCAN_PERIOD = 100
local SCAN_JITTER = 50
local SCAN_RADIUS = 5

function fai_collect(id)

    --------------------------------------------------------------------------
    -- THROTTLE: only scan every ~100 ticks
    --------------------------------------------------------------------------
    vai_itemscan[id] = vai_itemscan[id] + 1
    if vai_itemscan[id] <= SCAN_PERIOD then return end
    vai_itemscan[id] = math.random(0, SCAN_JITTER)

    local team = player(id, "team")

    -- Skip if already collecting or if zombie-team
    if vai_mode[id] == 6 then return end
    if team == 1 and vai_set_gm == 4 then return end

    --------------------------------------------------------------------------
    -- CACHE PLAYER STATE
    --------------------------------------------------------------------------
    local px      = player(id, "tilex")
    local py      = player(id, "tiley")
    local money   = player(id, "money")
    local hp      = player(id, "health")
    local maxhp   = player(id, "maxhealth")
    local weapons = playerweapons(id)

    --------------------------------------------------------------------------
    -- SCAN NEARBY ITEMS
    --------------------------------------------------------------------------
    local items = closeitems(id, SCAN_RADIUS)

    for i = 1, #items do
        local it    = items[i]
        local ix    = item(it, "x")
        local iy    = item(it, "y")

        -- Skip items on the exact same tile (already standing on it)
        if ix ~= px or iy ~= py then
            local itype   = item(it, "type")
            local slot    = itemtype(itype, "slot")
            local collect = false

            if slot == 1 then
                -- Primary weapon: take only if we have no primary
                collect = not fai_playerslotitems(id, 1) and team ~= 3

            elseif slot == 2 then
                -- Secondary weapon: take only if we have no secondary
                collect = not fai_playerslotitems(id, 2) and team ~= 3

            elseif slot == 3 or slot == 4 then
                -- Melee / Grenade: take if we don't have this specific weapon
                collect = not fai_contains(weapons, itype) and team ~= 3

            elseif slot == 5 then
                -- Special: only T picks up bomb (type 55)
                collect = itype == 55 and team == 1

            elseif slot == 0 then
                if itype == 70 or itype == 71 then
                    -- CTF flags
                    collect = true
                elseif itype >= 66 and itype <= 68 then
                    -- Money (only below cap)
                    collect = money < 16000
                elseif itype >= 64 and itype <= 65 then
                    -- Health items (only when not full)
                    collect = hp < maxhp
                end
            end

            if collect then
                vai_mode[id]  = 6
                vai_smode[id] = itype
                vai_destx[id] = ix
                vai_desty[id] = iy
                return  -- one item at a time
            end
        end
    end
end
