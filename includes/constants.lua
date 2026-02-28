-- constants.lua: every magic number in one place

MAX_PLAYERS = 32

-- Weapon type IDs
WPN_BOMB       = 55
WPN_AK47       = 30
WPN_M4A1       = 32
WPN_KNIFE      = 50
WPN_GRENADE    = 51
AMMO_PRIMARY   = 61
AMMO_SECONDARY = 62
ARMOR_FULL     = 57  -- kevlar + helmet
ARMOR_KEVLAR   = 58  -- kevlar only

-- Item type IDs
ITEM_BOMB_PLANTED = 63
ITEM_FLAG         = 70  -- flags are types 70 and 71
ITEM_MONEY_MIN    = 66
ITEM_MONEY_MAX    = 68
ITEM_HEALTH_MIN   = 64
ITEM_HEALTH_MAX   = 65
MONEY_CAP         = 16000

-- Entity type IDs used with randomentity()
ENT_CT_SPAWN  = 0
ENT_T_SPAWN   = 1
ENT_HOSTAGE   = 3
ENT_RESCUE    = 4
ENT_BOMBSPOT  = 5
ENT_VIP_SAFE  = 6
ENT_FLAG      = 15
ENT_DOM_POINT = 17
ENT_BOT_NODE  = 19

-- entity int0 value indicating which team owns a flag base
FLAG_TEAM1 = 0
FLAG_TEAM2 = 1

-- Radio command IDs
RADIO_OK           = 0
RADIO_FOLLOW_ME    = 1
RADIO_BOMB_PLANTED = 4
RADIO_AREA_CLEAR   = 5
RADIO_COVER_ME     = 6
RADIO_ENEMY_SPOT   = 9
RADIO_FALL_BACK    = 10
RADIO_TAKING_FIRE  = 11
RADIO_NEED_BACKUP  = 13
RADIO_GO_GO        = 15
RADIO_HOLD_POS     = 23
RADIO_REGROUP      = 24
RADIO_REPORT_IN    = 25
RADIO_REPORTING    = 26
RADIO_AFFIRM       = 28
RADIO_STICK_TOG1   = 30
RADIO_STICK_TOG2   = 31
RADIO_STICK_TOG3   = 32

-- Combat
VIEW_HALF_W   = 420  -- screen half-width in pixels; targets beyond this are dropped
VIEW_HALF_H   = 235  -- screen half-height in pixels
REAIM_PERIOD  = 20   -- ticks between ai_findtarget calls
RESCAN_PERIOD = 10   -- ticks between line-of-sight rechecks
AIM_TOLERANCE = 20   -- max degrees off-axis; bot won't fire if aim error exceeds this
LOS_MIN_DIST  = 30   -- pixels; skip LOS check when target is this close

-- Fight movement
HUNT_DIST_X = 230  -- pixel distance at which bot may switch to chasing
HUNT_DIST_Y = 180
HUNT_MIN_HP = 50   -- don't chase when own HP is below this

-- Follow mode
FOLLOW_CLOSE_X = 3  -- tile distance considered "close enough" to roam instead of follow
FOLLOW_CLOSE_Y = 2

-- Item scanning
COLLECT_SCAN_PERIOD = 100
COLLECT_SCAN_JITTER = 50   -- randomises next scan offset to spread CPU load across bots
COLLECT_SCAN_RADIUS = 5    -- tile radius passed to closeitems()

-- Objectives
HOSTAGE_USE_RANGE  = 15   -- pixel range within which ai_use triggers on a hostage
BOMB_SECTOR_RADIUS = 7    -- tile radius: "arrived at bombsite sector"
BOMB_SEARCH_RADIUS = 10   -- tile radius: scan for the planted bomb item

-- Returned by randomentity / closehostage when no matching entity exists on the map
NO_ENTITY = -100

-- ============================================================
-- BOMB CAMPING (T-side post-plant)
-- ============================================================

-- Tile radius around the planted bomb within which Ts will guard/camp
BOMB_CAMP_RADIUS    = 8
-- How often (ticks) a camping T re-checks whether the bomb is still planted
BOMB_CAMP_RESCAN    = 60
-- When the round timer drops below this many ticks, Ts flee the blast radius
-- CS2D round time is typically ~135 seconds = ~6750 ticks; bomb timer ~45s = ~2250 ticks.
-- We use a conservative value so bots escape with a few seconds to spare.
BOMB_ESCAPE_TICKS   = 180  -- ~3.6 seconds at 50 ticks/sec; tune per server tickrate
-- Minimum pixel distance bots try to put between themselves and the bomb before detonation
BOMB_ESCAPE_DIST_SQ = 300 * 300

-- ============================================================
-- CT BOMB RESPONSE
-- ============================================================

-- After bomb is planted, a CT who finds nobody defending the bomb
-- will rush straight to defuse.  This is the tile radius within which
-- a CT considers itself "alone" at the bombsite (no enemies visible).
CT_RUSH_CHECK_RADIUS = 12

-- ============================================================
-- HUMAN-LIKE BEHAVIOR CONSTANTS
-- ============================================================

-- Personality archetypes (assigned randomly per-bot on spawn)
-- 1 = aggressive, 2 = cautious, 3 = support, 4 = balanced
PERSONALITY_AGGRESSIVE = 1
PERSONALITY_CAUTIOUS   = 2
PERSONALITY_SUPPORT    = 3
PERSONALITY_BALANCED   = 4

-- Reaction time ranges by skill level (in ticks, ~50 ticks/sec)
-- bot_skill valid range is 0-4; bots delay this many ticks before locking onto a new target
REACT_TICKS_FAST = 3   -- very fast reaction (~60ms)
REACT_TICKS_MED  = 8   -- medium reaction (~160ms)
REACT_TICKS_SLOW = 18  -- slow reaction (~360ms)

-- Aim smoothing: how many degrees to rotate per tick toward the target
-- Lower = smoother/slower aim, more human-like
AIM_SMOOTH_FAST = 35   -- aggressive/high-skill bots
AIM_SMOOTH_MED  = 22   -- average bots
AIM_SMOOTH_SLOW = 14   -- cautious/low-skill bots

-- Spray / recoil simulation
-- After this many continuous shots, aim starts drifting
SPRAY_START_SHOT  = 3    -- recoil drift kicks in after 3rd bullet
SPRAY_MAX_DRIFT   = 18   -- max accumulated degrees of drift
SPRAY_DRIFT_RATE  = 2.5  -- degrees of drift added per shot
SPRAY_RECOVER_RATE= 4    -- degrees recovered per tick when not firing

-- Burst fire: bots pause between bursts to simulate controlled shooting
BURST_SIZE_MIN = 2   -- minimum shots per burst
BURST_SIZE_MAX = 5   -- maximum shots per burst
BURST_PAUSE_MIN = 4  -- minimum ticks between bursts
BURST_PAUSE_MAX = 14 -- maximum ticks between bursts

-- Distance-based accuracy penalty (pixels)
-- Beyond this range, bots get an extra angle-miss penalty
ACC_FULL_RANGE  = 180  -- full accuracy within this pixel distance
ACC_FAR_PENALTY = 8    -- extra degrees of miss added at max range

-- Movement accuracy penalty: extra miss angle when bot is moving
ACC_MOVE_PENALTY = 6

-- Peek-and-retreat: bots duck behind cover briefly, then peek again
PEEK_EXPOSE_MIN  = 20  -- ticks exposed while peeking
PEEK_EXPOSE_MAX  = 60
PEEK_RETREAT_MIN = 15  -- ticks hiding between peeks
PEEK_RETREAT_MAX = 45

-- Last-known-position memory: how long (ticks) bots remember where they last saw an enemy
LKP_MEMORY_TICKS = 120

-- Footstep awareness: probability that a bot "hears" nearby movement and turns (per tick)
FOOTSTEP_CHANCE   = 0.07  -- 7% per tick when an enemy is within footstep range
FOOTSTEP_RANGE_SQ = 200 * 200  -- squared pixel radius for hearing footsteps

-- Crouch behavior: probability per shot (while stationary) that bot crouches
CROUCH_CHANCE    = 0.08   -- 8% chance to crouch each second-ish
CROUCH_TICKS_MIN = 25
CROUCH_TICKS_MAX = 90

-- Grenade throw distance threshold (pixels): only throw if enemy is at least this far
NADE_MIN_DIST = 150
-- Probability per decide() call that a bot uses its grenade (if it has one)
NADE_USE_CHANCE = 0.20

-- Hesitation: bots occasionally pause before rounding corners
HESITATE_CHANCE   = 0.12  -- 12% chance to hesitate at a waypoint arrival
HESITATE_TICKS_MIN = 8
HESITATE_TICKS_MAX = 35

-- Low-HP panic: below this HP the bot retreats to find health or cover
PANIC_HP_THRESHOLD = 25