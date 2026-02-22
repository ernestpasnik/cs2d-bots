function fai_buy(id)
    -- Handle wait timer
    if vai_timer[id] > 0 then
        vai_timer[id] = vai_timer[id] - 1
        return
    end

    local money   = player(id, "money")
    local team    = player(id, "team")
    local weapons = playerweapons(id)
    local smode   = vai_smode[id]

    -- Primary weapon
    if smode == 0 then
        local hasAK = fai_contains(weapons, 30)
        local hasM4 = fai_contains(weapons, 32)

        if hasAK or hasM4 then
            if money >= 50 then
                ai_buy(id, 61) -- primary ammo
            end
        else
            if team == 1 then
                if money >= 3250 then ai_buy(id, 30) end
            else
                if money >= 3850 then ai_buy(id, 32) end
            end
        end

    -- Kevlar
    elseif smode == 2 then
        if money >= 1000 then
            ai_buy(id, 57) -- kevlar + helmet
        elseif money >= 650 then
            ai_buy(id, 58) -- kevlar only
        end

    -- Grenade
    elseif smode == 3 then
        if money >= 300 and math.random(0, 3) == 1 then
            ai_buy(id, 51)
        end

    -- Secondary ammo
    elseif smode == 4 then
        if money >= 50 then
            ai_buy(id, 62)
        end

    -- Switch to knife
    elseif smode == 5 then
        if fai_contains(weapons, 50) then
            ai_selectweapon(id, 50)
        end
    end

    -- Advance buying step
    vai_smode[id] = smode + 1
    vai_timer[id] = math.random(1, 5)

    -- Finish buying
    if vai_smode[id] > 5 then
        vai_mode[id]       = 0
        vai_smode[id]      = 0
        vai_buyingdone[id] = 1
    end
end
