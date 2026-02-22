function fai_radio(source, radio)
    local p   = player
    local r   = math.random
    local bots, mates, mate

    --------------------------------------------------------------------------
    -- RADIO 4: Bomb planted → all CT bots go defuse
    --------------------------------------------------------------------------
    if radio == 4 then
        bots = p(0, "table")
        for _, id in pairs(bots) do
            if p(id, "bot") == 1 and p(id, "team") == 2 then
                if vai_mode[id] ~= 52 then
                    vai_destx[id], vai_desty[id] = randomentity(5, 0)
                    vai_mode[id]  = 52
                    vai_smode[id] = 0
                    vai_timer[id] = 0
                end
            end
        end
        return
    end

    --------------------------------------------------------------------------
    -- RADIO 1 / 6 / 13: Follow me / Need backup / Cover me
    --------------------------------------------------------------------------
    if radio == 1 or radio == 6 or radio == 13 then
        mate = fai_randommate(source)
        if mate ~= 0 then
            vai_radioanswer[mate]  = (r(1, 2) == 1) and 0 or 28
            vai_radioanswert[mate] = r(35, 100)
            vai_mode[mate]         = 7
            vai_smode[mate]        = source
            vai_timer[mate]        = 0
        end
        return
    end

    --------------------------------------------------------------------------
    -- RADIO 9 / 11: Enemy spotted / Taking fire → go to player
    --------------------------------------------------------------------------
    if radio == 9 or radio == 11 then
        mate = fai_randommate(source)
        if mate ~= 0 then
            vai_radioanswer[mate]  = (r(1, 2) == 1) and 0 or 28
            vai_radioanswert[mate] = r(35, 100)
            vai_mode[mate]         = 2
            vai_destx[mate]        = p(source, "tilex")
            vai_desty[mate]        = p(source, "tiley")
        end
        return
    end

    --------------------------------------------------------------------------
    -- RADIO 24: Regroup team → stop following
    --------------------------------------------------------------------------
    if radio == 24 then
        local team = p(source, "team")
        if team > 2 then team = 2 end

        mates = p(0, "team" .. team .. "living")
        local c = 1

        for i = 1, #mates do
            mate = mates[i]
            if vai_mode[mate] == 7 then
                vai_radioanswer[mate]  = (r(1, 2) == 1) and 0 or 28
                vai_radioanswert[mate] = r(50, 55) * c
                c = c + 1
                vai_mode[mate] = 0
            end
        end
        return
    end

    --------------------------------------------------------------------------
    -- RADIO 23: Hold position → camp
    --------------------------------------------------------------------------
    if radio == 23 then
        mate = fai_randommate(source)
        if mate ~= 0 then
            vai_radioanswer[mate]  = (r(1, 2) == 1) and 0 or 28
            vai_radioanswert[mate] = r(35, 100)
            vai_mode[mate]         = 1
            vai_timer[mate]        = r(30 * 50, 60 * 50)
        end
        return
    end

    --------------------------------------------------------------------------
    -- RADIO 10 / 15 / 30 / 31 / 32: Fall back / Go go go / Stick together
    --------------------------------------------------------------------------
    if radio == 10 or radio == 15 or radio == 30 or radio == 31 or radio == 32 then
        local team = p(source, "team")
        if team > 2 then team = 2 end

        mates = p(0, "team" .. team .. "living")
        local c = 1

        for i = 1, #mates do
            mate = mates[i]
            local mode = vai_mode[mate]
            if mode == 1 or mode == 7 then
                vai_radioanswer[mate]  = (r(1, 2) == 1) and 0 or 28
                vai_radioanswert[mate] = r(50, 55) * c
                c = c + 1
                vai_mode[mate] = 0
            end
        end
        return
    end

    --------------------------------------------------------------------------
    -- RADIO 25: Report in → "reporting in!"
    --------------------------------------------------------------------------
    if radio == 25 then
        mate = fai_randommate(source)
        if mate ~= 0 then
            vai_radioanswer[mate]  = 26
            vai_radioanswert[mate] = r(35, 100)
        end
        return
    end
end
