function fai_decide(id)
    local r = math.random
    local re = randomentity
    local team = player(id, "team")
    local botnodes = map("botnodes") > 0

    local function setdest(ent, mode)
        vai_destx[id], vai_desty[id] = re(ent)
        vai_mode[id] = mode or 2
    end

    local function goto_bot_or_spawn(spawn)
        if botnodes and r(0,2) == 1 then
            setdest(19)
        else
            setdest(spawn)
        end
    end

    local function roam()
        vai_mode[id]  = 3
        vai_timer[id] = r(150,300)
        vai_smode[id] = r(0,360)
    end

    --------------------------------------------------------------------------
    -- BUYING PHASE
    --------------------------------------------------------------------------
    if vai_buyingdone[id] ~= 1 then
        vai_mode[id]  = -1
        vai_smode[id] = 0
        vai_timer[id] = r(1,10)
        vai_buyingdone[id] = 1
        return
    end

    --------------------------------------------------------------------------
    -- GAME MODE 4: ZOMBIES
    --------------------------------------------------------------------------
    if vai_set_gm == 4 then
        if team == 1 then
            if r(1,3) <= 2 then
                goto_bot_or_spawn(1)
            else
                setdest(0)
            end
        else
            if r(1,3) == 1 then
                setdest(0)
            else
                goto_bot_or_spawn(1)
            end
        end
        return
    end

    --------------------------------------------------------------------------
    -- AS MAPS
    --------------------------------------------------------------------------
    if map("mission_vips") > 0 then
        if team == 1 then
            local x = r(1,3)
            if x == 1 then setdest(6)
            elseif x == 2 then goto_bot_or_spawn(1)
            else setdest(2) end

        elseif team == 2 then
            if r(1,2) == 1 then setdest(6)
            else goto_bot_or_spawn(0) end

        else -- VIP
            if botnodes and r(0,2) == 1 then setdest(19)
            else setdest(6) end
        end
        return
    end

    --------------------------------------------------------------------------
    -- CS MAPS
    --------------------------------------------------------------------------
    if map("mission_hostages") > 0 then
        if team == 1 then
            local x = r(1,3)
            if x == 1 then setdest(3)
            elseif x == 2 then goto_bot_or_spawn(1)
            else setdest(4) end

        else
            if r(1,5) == 1 then
                goto_bot_or_spawn(0)
            else
                vai_destx[id], vai_desty[id] = randomhostage(1)
                vai_mode[id] = 50
                vai_smode[id] = 0
            end
        end
        return
    end

    --------------------------------------------------------------------------
    -- DE MAPS
    --------------------------------------------------------------------------
    if map("mission_bombspots") > 0 then
        if team == 1 then
            if r(1,2) == 1 then
                setdest(5)
                if player(id,"bomb") then
                    vai_mode[id] = 51
                    vai_smode[id] = 0
                    vai_timer[id] = 0
                end
            else
                goto_bot_or_spawn(1)
            end

        else
            if game("bombplanted") then
                setdest(5, 52)
                vai_smode[id] = 0
            else
                if r(1,2) == 1 then setdest(5)
                else goto_bot_or_spawn(0) end
            end
        end
        return
    end

    --------------------------------------------------------------------------
    -- CTF MAPS
    --------------------------------------------------------------------------
    if map("mission_ctfflags") > 0 then
        local px, py = player(id,"tilex"), player(id,"tiley")
        local etype = entity(px,py,"type")
        local eint0 = entity(px,py,"int0")
        local hasflag = player(id,"flag")

        local function retry()
            vai_mode[id] = 3
            vai_timer[id] = r(150,300)
            vai_smode[id] = r(0,360)
        end

        if team == 1 then
            if hasflag then
                if etype == 15 and eint0 == 0 then retry()
                else setdest(15) end
            else
                if r(1,3) == 1 then setdest(15)
                else goto_bot_or_spawn(1) end
            end

        else
            if hasflag then
                if etype == 15 and eint0 == 1 then retry()
                else setdest(15) end
            else
                if r(1,3) == 1 then setdest(15)
                else goto_bot_or_spawn(0) end
            end
        end
        return
    end

    --------------------------------------------------------------------------
    -- DOM MAPS
    --------------------------------------------------------------------------
    if map("mission_dompoints") > 0 then
        if r(1,5) <= 4 then
            if team == 1 then setdest(17)
            else setdest(17) end
        end
        return
    end

    --------------------------------------------------------------------------
    -- GENERIC MAPS
    --------------------------------------------------------------------------
    local x = r(1,3)
    if team == 1 then
        if x <= 2 then goto_bot_or_spawn(1)
        else setdest(0) end
    else
        if x <= 2 then goto_bot_or_spawn(0)
        else setdest(1) end
    end

    --------------------------------------------------------------------------
    -- FALLBACK
    --------------------------------------------------------------------------
    if vai_mode[id] == 2 and vai_destx[id] == -100 then
        roam()
    end
end
