function fai_plantbomb(id)
    -- Bot no longer has the bomb → abort
    if not player(id, "bomb") then
        vai_mode[id] = 0
        return
    end

    local tx, ty = player(id, "tilex"), player(id, "tiley")
    local onSpot = tile(tx, ty, "entity") ~= 0 and inentityzone(tx, ty, 5)

    -- Standing on bombspot
    if onSpot then
        -- Ensure bomb is selected
        if player(id, "weapontype") ~= 55 then
            ai_selectweapon(id, 55)
            return
        end

        -- Planting sequence
        if vai_timer[id] == 0 then
            ai_radio(id, 6)  -- "Cover me!"
            vai_timer[id] = 1
        end

        ai_attack(id)
        return
    end

    -- Move toward bombspot
    local result = ai_goto(id, vai_destx[id], vai_desty[id])

    if result ~= 2 then
        -- Pick a new bombspot target
        vai_destx[id], vai_desty[id] = randomentity(5)
    else
        fai_walkaim(id)
    end
end

function fai_defuse(id)
    local tx, ty = player(id, "tilex"), player(id, "tiley")

    -- Searching for bomb
    if vai_smode[id] == 0 then
        local result = ai_goto(id, vai_destx[id], vai_desty[id])

        if result ~= 2 then
            vai_destx[id], vai_desty[id] = randomentity(5, 0)
        else
            fai_walkaim(id)
        end

        -- Close enough to inspect area
        if math.abs(tx - vai_destx[id]) < 7 and math.abs(ty - vai_desty[id]) < 7 then
            local items = item(0, "table")

            -- Look for bomb item
            for i = 1, #items do
                local it = items[i]
                if item(it, "type") == 63 then
                    local ix, iy = item(it, "x"), item(it, "y")
                    if math.abs(tx - ix) < 10 and math.abs(ty - iy) < 10 then
                        vai_destx[id], vai_desty[id] = ix, iy
                        vai_smode[id] = 1
                        return
                    end
                end
            end

            -- No bomb found → clear sector
            setentityaistate(vai_destx[id], vai_desty[id], 1)
            ai_radio(id, 5)

            -- Reassign bots searching same spot
            local bots = player(0, "table")
            for _, b in ipairs(bots) do
                if player(b, "bot") == 1 and vai_mode[b] == 52 then
                    if vai_destx[b] == vai_destx[id] and vai_desty[b] == vai_desty[id] then
                        vai_destx[b], vai_desty[b] = randomentity(5, 0)
                        vai_smode[b] = 0
                    end
                end
            end

            vai_destx[id], vai_desty[id] = randomentity(5, 0)
            return
        end

    else
        -- Defusing mode
        local result = ai_goto(id, vai_destx[id], vai_desty[id])

        if result == 1 then
            if vai_timer[id] == 0 then
                ai_radio(id, 6)
                vai_timer[id] = 1
            end
            ai_use(id)

        elseif result == 0 then
            vai_mode[id] = 0
        end
    end
end
