function fai_engage(id)
    local r = math.random
    local p = player
    local abs = math.abs

    --------------------------------------------------------------------------
    -- REACQUIRE TARGET
    --------------------------------------------------------------------------
    vai_reaim[id] = vai_reaim[id] - 1
    if vai_reaim[id] < 0 then
        vai_reaim[id] = 20

        if p(id, "ai_flash") == 0 then
            -- Not flashed
            local t = ai_findtarget(id)
            vai_target[id] = t
            if t > 0 then
                vai_rescan[id] = 0
            end
        else
            -- Flashed
            vai_target[id] = 0
            if vai_mode[id] ~= 8 then
                vai_mode[id] = 8
                fai_randomadjacent(id)
            end
        end
    end

    --------------------------------------------------------------------------
    -- VALIDATE TARGET
    --------------------------------------------------------------------------
    local tid = vai_target[id]
    if tid > 0 then
        if not p(tid, "exists") then
            vai_target[id] = 0
        else
            local thealth = p(tid, "health")
            local tteam   = p(tid, "team")

            if thealth > 0 and tteam > 0 and fai_enemies(tid, id) then
                -- Cache positions
                local x1 = p(id, "x")
                local y1 = p(id, "y")
                local x2 = p(tid, "x")
                local y2 = p(tid, "y")

                -- Range check
                if abs(x1 - x2) < 420 and abs(y1 - y2) < 235 then
                    -- Freeline scan
                    vai_rescan[id] = vai_rescan[id] - 1
                    if vai_rescan[id] < 0 then
                        vai_rescan[id] = 10
                        if abs(x1 - x2) > 30 or abs(y1 - y2) > 30 then
                            if not ai_freeline(id, x2, y2) then
                                vai_target[id] = 0
                            end
                        end
                    end
                else
                    vai_target[id] = 0
                end
            else
                vai_target[id] = 0
            end
        end
    end

    --------------------------------------------------------------------------
    -- AIM
    --------------------------------------------------------------------------
    tid = vai_target[id]
    if tid > 0 then
        local tx = p(tid, "x")
        local ty = p(tid, "y")

        vai_aimx[id] = tx
        vai_aimy[id] = ty

        -- Switch to fight mode
        local mode = vai_mode[id]
        if mode ~= 4 and mode ~= 5 then
            vai_timer[id] = r(25, 100)
            vai_smode[id] = r(0, 360)
            vai_mode[id] = 4
        end
    end

    ai_aim(id, vai_aimx[id], vai_aimy[id])

    --------------------------------------------------------------------------
    -- ATTACK
    --------------------------------------------------------------------------
    if tid > 0 then
        local px = p(id, "x")
        local py = p(id, "y")
        local tx = p(tid, "x")
        local ty = p(tid, "y")

        local rot = p(id, "rot")
        local ang = fai_angleto(px, py, tx, ty)

        if abs(fai_angledelta(rot, ang)) < 20 then
            ai_iattack(id)
        end
    end
end
