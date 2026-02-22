function fai_collect(id)

    -- Update scan timer
    vai_itemscan[id] = vai_itemscan[id] + 1
    if vai_itemscan[id] <= 100 then
        return
    end

    -- Reset timer
    vai_itemscan[id] = math.random(0, 50)

    local team = player(id, "team")

    -- Already collecting OR zombie mode
    if vai_mode[id] == 6 then return end
    if team == 1 and vai_set_gm == 4 then return end

    -- Scan items within 5 tiles
    local items = closeitems(id, 5)
    local px, py = player(id, "tilex"), player(id, "tiley")
    local money  = player(id, "money")
    local hp     = player(id, "health")
    local maxhp  = player(id, "maxhealth")
    local weapons = playerweapons(id)

    for _, it in ipairs(items) do
        local ix, iy = item(it, "x"), item(it, "y")

        -- Ignore items on the same tile
        if ix ~= px or iy ~= py then
            local itype = item(it, "type")
            local slot  = itemtype(itype, "slot")
            local collect = false

            -- Slot-based logic
            if slot == 1 then
                -- Primary weapon
                if not fai_playerslotitems(id, 1) and team ~= 3 then
                    collect = true
                end

            elseif slot == 2 then
                -- Secondary weapon
                if not fai_playerslotitems(id, 2) and team ~= 3 then
                    collect = true
                end

            elseif slot == 3 or slot == 4 then
                -- Melee or Grenade
                if not fai_contains(weapons, itype) and team ~= 3 then
                    collect = true
                end

            elseif slot == 5 then
                -- Special items
                if itype == 55 and team == 1 then
                    collect = true
                end

            elseif slot == 0 then
                -- No-slot items
                if itype == 70 or itype == 71 then
                    collect = true -- Flags

                elseif itype >= 66 and itype <= 68 and money < 16000 then
                    collect = true -- Money

                elseif itype >= 64 and itype <= 65 and hp < maxhp then
                    collect = true -- Health
                end
            end

            -- Start collecting
            if collect then
                vai_mode[id]  = 6
                vai_smode[id] = itype
                vai_destx[id] = ix
                vai_desty[id] = iy
                break
            end
        end
    end
end
