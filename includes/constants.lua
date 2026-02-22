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
