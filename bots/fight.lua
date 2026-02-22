function fai_fight(id)
    local p = player
    local r = math.random
    local abs = math.abs

    local tid = vai_target[id]
    if tid > 0 and p(tid, "exists") and p(tid, "health") > 0 then
        
        ----------------------------------------------------------------------
        -- CACHE PLAYER DATA
        ----------------------------------------------------------------------
        local my_x  = p(id, "x")
        local my_y  = p(id, "y")
        local my_hp = p(id, "health")
        local tx    = p(tid, "x")
        local ty    = p(tid, "y")

        ----------------------------------------------------------------------
        -- MELEE COMBAT?
        ----------------------------------------------------------------------
        if itemtype(p(id, "weapontype"), "range") < 50 then
            -- Run to target
            if ai_goto(id, p(tid, "tilex"), p(tid, "tiley")) ~= 2 then
                vai_mode[id] = 0
            end
            return
        end

        ----------------------------------------------------------------------
        -- RANGED COMBAT
        ----------------------------------------------------------------------
        vai_timer[id] = vai_timer[id] - 1
        if vai_timer[id] <= 0 then
            vai_timer[id] = r(50, 150)
            vai_smode[id] = r(0, 360)

            -- Hunt mode?
            if r(1, 2) == 1 and my_hp > 50 then
                if abs(my_x - tx) > 230 and abs(my_y - ty) > 180 then
                    vai_mode[id] = 5
                    vai_smode[id] = tid
                end
            end
        end

        ----------------------------------------------------------------------
        -- MOVEMENT (STRAFING / APPROACH)
        ----------------------------------------------------------------------
        if ai_move(id, vai_smode[id]) == 0 then
            -- Blocked → turn
            if (id % 2) == 0 then
                vai_smode[id] = vai_smode[id] + 45
            else
                vai_smode[id] = vai_smode[id] - 45
            end
            vai_timer[id] = r(50, 150)
        end

        return
    end

    --------------------------------------------------------------------------
    -- NO VALID TARGET → EXIT FIGHT MODE
    --------------------------------------------------------------------------
    vai_mode[id] = 0
end
