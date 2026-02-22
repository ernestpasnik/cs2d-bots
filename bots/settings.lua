-- Update Settings (optimized)
function fai_update_settings()
    local g = game  -- cache function reference

    vai_set_gm        = g("sv_gamemode")
    vai_set_botskill  = g("bot_skill")
    vai_set_botweapons= g("bot_weapons")
    vai_set_debug     = g("debugai")
end
