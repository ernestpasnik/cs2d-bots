--------------------------------------------------
-- Decision Logic
--------------------------------------------------

local r  = math.random
local re = randomentity

--------------------------------------------------
-- Helpers
--------------------------------------------------

local function setdest(id, ent, mode)
    vai_destx[id], vai_desty[id] = re(ent)
    vai_mode[id] = mode or 2
end

local function gotoBotNodeOrSpawn(id, spawn)
    if map("botnodes") > 0 and r(0, 2) == 1 then
        setdest(id, 19)
    else
        setdest(id, spawn)
    end
end

local function roam(id)
    vai_mode[id]  = 3
    vai_timer[id] = r(150, 300)
    vai_smode[id] = r(0, 360)
end

--------------------------------------------------
-- fai_decide(id)
--------------------------------------------------

function fai_decide(id)
    local team = player(id, "team")

    --------------------------------------------------------------------------
    -- BUYING PHASE
    --------------------------------------------------------------------------
    if vai_buyingdone[id] ~= 1 then
        vai_mode[id]       = -1
        vai_smode[id]      = 0
        vai_timer[id]      = r(1, 10)
        vai_buyingdone[id] = 1
        return
    end

    --------------------------------------------------------------------------
    -- ZOMBIE MODE (gm 4)
    --------------------------------------------------------------------------
    if vai_set_gm == 4 then
        if team == 1 then
            if r(1, 3) <= 2 then gotoBotNodeOrSpawn(id, 1)
            else setdest(id, 0) end
        else
            if r(1, 3) == 1 then setdest(id, 0)
            else gotoBotNodeOrSpawn(id, 1) end
        end
        return
    end

    --------------------------------------------------------------------------
    -- AS MAPS (VIP escort)
    --------------------------------------------------------------------------
    if map("mission_vips") > 0 then
        if team == 1 then
            local x = r(1, 3)
            if x == 1 then setdest(id, 6)
            elseif x == 2 then gotoBotNodeOrSpawn(id, 1)
            else setdest(id, 2) end

        elseif team == 2 then
            if r(1, 2) == 1 then setdest(id, 6)
            else gotoBotNodeOrSpawn(id, 0) end

        else  -- VIP
            if map("botnodes") > 0 and r(0, 2) == 1 then setdest(id, 19)
            else setdest(id, 6) end
        end
        return
    end

    --------------------------------------------------------------------------
    -- CS MAPS (hostage rescue)
    --------------------------------------------------------------------------
    if map("mission_hostages") > 0 then
        if team == 1 then
            local x = r(1, 3)
            if x == 1 then setdest(id, 3)
            elseif x == 2 then gotoBotNodeOrSpawn(id, 1)
            else setdest(id, 4) end

        else
            if r(1, 5) == 1 then
                gotoBotNodeOrSpawn(id, 0)
            else
                vai_destx[id], vai_desty[id] = randomhostage(1)
                vai_mode[id]  = 50
                vai_smode[id] = 0
            end
        end
        return
    end

    --------------------------------------------------------------------------
    -- DE MAPS (bomb defusal)
    --------------------------------------------------------------------------
    if map("mission_bombspots") > 0 then
        if team == 1 then
            if r(1, 2) == 1 then
                setdest(id, 5)
                if player(id, "bomb") then
                    vai_mode[id]  = 51
                    vai_smode[id] = 0
                    vai_timer[id] = 0
                end
            else
                gotoBotNodeOrSpawn(id, 1)
            end

        else  -- CT
            if game("bombplanted") then
                setdest(id, 5, 52)
                vai_smode[id] = 0
            elseif r(1, 2) == 1 then
                setdest(id, 5)
            else
                gotoBotNodeOrSpawn(id, 0)
            end
        end
        return
    end

    --------------------------------------------------------------------------
    -- CTF MAPS
    --------------------------------------------------------------------------
    if map("mission_ctfflags") > 0 then
        local px    = player(id, "tilex")
        local py    = player(id, "tiley")
        local etype = entity(px, py, "type")
        local hasflag = player(id, "flag")

        if team == 1 then
            if hasflag then
                -- Standing on own flag base → roam instead of capping nothing
                if etype == 15 and entity(px, py, "int0") == 0 then roam(id)
                else setdest(id, 15) end
            else
                if r(1, 3) == 1 then setdest(id, 15)
                else gotoBotNodeOrSpawn(id, 1) end
            end

        else
            if hasflag then
                if etype == 15 and entity(px, py, "int0") == 1 then roam(id)
                else setdest(id, 15) end
            else
                if r(1, 3) == 1 then setdest(id, 15)
                else gotoBotNodeOrSpawn(id, 0) end
            end
        end
        return
    end

    --------------------------------------------------------------------------
    -- DOM MAPS (domination)
    --------------------------------------------------------------------------
    if map("mission_dompoints") > 0 then
        if r(1, 5) <= 4 then
            setdest(id, 17)
        end
        return
    end

    --------------------------------------------------------------------------
    -- GENERIC / DM MAPS
    --------------------------------------------------------------------------
    local x = r(1, 3)
    if team == 1 then
        if x <= 2 then gotoBotNodeOrSpawn(id, 1)
        else setdest(id, 0) end
    else
        if x <= 2 then gotoBotNodeOrSpawn(id, 0)
        else setdest(id, 1) end
    end

    -- Fallback: if no valid destination, roam
    if vai_mode[id] == 2 and vai_destx[id] == -100 then
        roam(id)
    end
end
