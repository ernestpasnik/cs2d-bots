--------------------------------------------------
-- Radio Handler
--------------------------------------------------

local r = math.random
local p = player

-- Helper: schedule a radio reply for a bot mate
local function scheduleReply(mate, answer)
    vai_radioanswer[mate]  = answer
    vai_radioanswert[mate] = r(35, 100)
end

-- Helper: random "okay/affirmative" reply (radio 0 or 28)
local function okReply()
    return (r(1, 2) == 1) and 0 or 28
end

-- Helper: iterate all living team bots
local function forTeamBots(source, fn)
    local team = p(source, "team")
    if team > 2 then team = 2 end
    local mates = p(0, "team" .. team .. "living")
    for i = 1, #mates do
        fn(mates[i])
    end
end

--------------------------------------------------
-- Dispatch table keyed by radio command
--------------------------------------------------

local RADIO = {}

-- Bomb planted → all CT bots rush to defuse
RADIO[4] = function(source)
    local bots = p(0, "table")
    for i = 1, #bots do
        local id = bots[i]
        if p(id, "bot") == 1 and p(id, "team") == 2 and vai_mode[id] ~= 52 then
            vai_destx[id], vai_desty[id] = randomentity(5, 0)
            vai_mode[id]  = 52
            vai_smode[id] = 0
            vai_timer[id] = 0
        end
    end
end

-- Follow me / Need backup / Cover me → one mate follows
local function cmdFollow(source)
    local mate = fai_randommate(source)
    if mate ~= 0 then
        scheduleReply(mate, okReply())
        vai_mode[mate]  = 7
        vai_smode[mate] = source
        vai_timer[mate] = 0
    end
end
RADIO[1]  = cmdFollow
RADIO[6]  = cmdFollow
RADIO[13] = cmdFollow

-- Enemy spotted / Taking fire → one mate moves to caller's position
local function cmdReinforce(source)
    local mate = fai_randommate(source)
    if mate ~= 0 then
        scheduleReply(mate, okReply())
        vai_mode[mate]  = 2
        vai_destx[mate] = p(source, "tilex")
        vai_desty[mate] = p(source, "tiley")
    end
end
RADIO[9]  = cmdReinforce
RADIO[11] = cmdReinforce

-- Regroup → stop all following bots
RADIO[24] = function(source)
    local c = 1
    forTeamBots(source, function(mate)
        if vai_mode[mate] == 7 then
            vai_radioanswer[mate]  = okReply()
            vai_radioanswert[mate] = r(50, 55) * c
            c = c + 1
            vai_mode[mate] = 0
        end
    end)
end

-- Hold position → one mate camps
RADIO[23] = function(source)
    local mate = fai_randommate(source)
    if mate ~= 0 then
        scheduleReply(mate, okReply())
        vai_mode[mate]  = 1
        vai_timer[mate] = r(30 * 50, 60 * 50)
    end
end

-- Fall back / Go go go / Stick together → wake up camping/following bots
local function cmdResumeMove(source)
    local c = 1
    forTeamBots(source, function(mate)
        local mode = vai_mode[mate]
        if mode == 1 or mode == 7 then
            vai_radioanswer[mate]  = okReply()
            vai_radioanswert[mate] = r(50, 55) * c
            c = c + 1
            vai_mode[mate] = 0
        end
    end)
end
RADIO[10] = cmdResumeMove
RADIO[15] = cmdResumeMove
RADIO[30] = cmdResumeMove
RADIO[31] = cmdResumeMove
RADIO[32] = cmdResumeMove

-- Report in → one mate replies "reporting in!"
RADIO[25] = function(source)
    local mate = fai_randommate(source)
    if mate ~= 0 then
        scheduleReply(mate, 26)
    end
end

--------------------------------------------------
-- Entry point
--------------------------------------------------

function fai_radio(source, radio)
    local handler = RADIO[radio]
    if handler then
        handler(source)
    end
end
