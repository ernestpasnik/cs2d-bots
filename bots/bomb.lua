--------------------------------------------------
-- Bomb Plant / Defuse Logic
--------------------------------------------------

local abs = math.abs
local p   = player

--------------------------------------------------
-- fai_plantbomb(id)
--------------------------------------------------

function fai_plantbomb(id)
    -- Bot dropped or lost the bomb
    if not p(id, "bomb") then
        vai_mode[id] = 0
        return
    end

    local tx  = p(id, "tilex")
    local ty  = p(id, "tiley")

    -- Check whether we're standing on a valid bombspot
    local onSpot = tile(tx, ty, "entity") ~= 0 and inentityzone(tx, ty, 5)

    if onSpot then
        -- Ensure bomb is selected before planting
        if p(id, "weapontype") ~= 55 then
            ai_selectweapon(id, 55)
            return
        end

        if vai_timer[id] == 0 then
            ai_radio(id, 6)  -- "Cover me!"
            vai_timer[id] = 1
        end

        ai_attack(id)  -- hold attack to plant
        return
    end

    -- Navigate to nearest bombspot
    if ai_goto(id, vai_destx[id], vai_desty[id]) ~= 2 then
        vai_destx[id], vai_desty[id] = randomentity(5)
    else
        fai_walkaim(id)
    end
end

--------------------------------------------------
-- fai_defuse(id)
--------------------------------------------------

-- Helper: redirect all CT bots currently searching the same cleared spot
local function redirectBotsFrom(srcid, oldx, oldy)
    local bots = p(0, "table")
    for i = 1, #bots do
        local b = bots[i]
        if p(b, "bot") == 1
        and vai_mode[b] == 52
        and vai_destx[b] == oldx
        and vai_desty[b] == oldy then
            vai_destx[b], vai_desty[b] = randomentity(5, 0)
            vai_smode[b] = 0
        end
    end
end

function fai_defuse(id)
    local tx = p(id, "tilex")
    local ty = p(id, "tiley")

    --------------------------------------------------------------------------
    -- SMODE 0: SEARCH for the bomb
    --------------------------------------------------------------------------
    if vai_smode[id] == 0 then

        -- Keep moving toward current search destination
        if ai_goto(id, vai_destx[id], vai_desty[id]) ~= 2 then
            vai_destx[id], vai_desty[id] = randomentity(5, 0)
        else
            fai_walkaim(id)
        end

        -- When close enough, inspect for bomb items
        if abs(tx - vai_destx[id]) < 7 and abs(ty - vai_desty[id]) < 7 then
            local items = item(0, "table")

            for i = 1, #items do
                local it = items[i]
                if item(it, "type") == 63 then  -- planted bomb item
                    local ix = item(it, "x")
                    local iy = item(it, "y")

                    if abs(tx - ix) < 10 and abs(ty - iy) < 10 then
                        -- Bomb found: switch to defuse mode
                        vai_destx[id] = ix
                        vai_desty[id] = iy
                        vai_smode[id] = 1
                        return
                    end
                end
            end

            -- No bomb here: mark sector clear, redirect bots
            setentityaistate(vai_destx[id], vai_desty[id], 1)
            ai_radio(id, 5)  -- "Area clear"
            redirectBotsFrom(id, vai_destx[id], vai_desty[id])
            vai_destx[id], vai_desty[id] = randomentity(5, 0)
        end

    --------------------------------------------------------------------------
    -- SMODE 1: DEFUSE the bomb
    --------------------------------------------------------------------------
    else
        local result = ai_goto(id, vai_destx[id], vai_desty[id])

        if result == 1 then
            -- Adjacent to bomb: hold use to defuse
            if vai_timer[id] == 0 then
                ai_radio(id, 6)  -- "Cover me!"
                vai_timer[id] = 1
            end
            ai_use(id)

        elseif result == 0 then
            -- Path blocked: fall back to search mode
            vai_mode[id] = 0
        end
    end
end
