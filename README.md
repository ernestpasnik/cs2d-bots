# Standard AI — CS2D Bot Brain

## File Structure

| File | Responsibility |
|---|---|
| `Standard AI.lua` | Entry point — state tables, mode dispatch, engine callbacks |
| `includes/constants.lua` | Every magic number in one place |
| `includes/core.lua` | Server settings + shared utility functions |
| `includes/combat.lua` | Target tracking, aiming, firing, strafe movement |
| `includes/objectives.lua` | Bomb plant/defuse, hostage rescue |
| `includes/movement.lua` | Item collection, follow-teammate logic |
| `includes/tactics.lua` | Buy sequence, round decision-making, radio responses |

`core.lua` loads `constants.lua` automatically. Everything else is loaded by `Standard AI.lua`.

---

## How It Works

### The tick loop

CS2D calls `ai_update_living(id)` every tick for each living bot. The call order is:

```
ai_update_living(id)
  fai_engage(id)        always runs: target scan, aim, shoot
  radio reply timer     counts down and fires queued ai_radio() calls
  fai_collect(id)       throttled item scan; may switch bot to mode 6
  MODE[vai_mode[id]]    dispatches to the current behaviour
```

`fai_engage` runs unconditionally so bots can always shoot even while buying, following, or defusing. It skips the `ai_findtarget` scan in modes `-1` (buying) and `1` (waiting) to avoid interrupting those states.

---

### The mode state machine

Every bot has a `vai_mode[id]` that selects its current behaviour. Modes call each other by writing to `vai_mode` directly — there is no call stack.

```
spawn
  |
  v
[-1] buying
  |  Steps through BUY_STEPS one per tick. Sets vai_buyingdone = 1 when done.
  v
[0] decide  <-- any mode returns here by setting vai_mode = 0
  |  Reads map type and team, picks a destination mode.
  |
  |-- [2] goto dest     walk to vai_destx/y; return to 0 on arrival
  |-- [3] roam          move in vai_smode direction; return to 0 on timer
  |-- [50] rescue       hostage collection and escort
  |-- [51] plant bomb   walk to bombspot and hold attack
  +-- [52] defuse       search bombsites, then hold use on the bomb

fai_engage --> [4] fight    strafe while shooting at vai_target
                 |  vai_smode = strafe angle (degrees)
                 +-- [5] hunt   chase vai_smode (player ID) until close
                          |
                          +-- back to [4] via fai_engage on re-acquisition

fai_engage --> [8] flee     move away when flashbanged; return to 0 when clear

fai_collect -> [6] collect  walk to item; return to 0 on arrival

radio cmd  --> [1] wait     hold position for vai_timer ticks; return to 0
radio cmd  --> [7] follow   trail vai_smode (player ID); roam nearby when close
```

---

### State variables

Each array is indexed by player ID (1–32).

| Variable | Type | Meaning |
|---|---|---|
| `vai_mode[id]` | int | Current mode (-1..52) |
| `vai_smode[id]` | mixed | Sub-mode or mode-specific value — see table below |
| `vai_timer[id]` | int | General countdown; meaning depends on mode |
| `vai_destx/y[id]` | tile int | Navigation destination |
| `vai_aimx/y[id]` | pixel int | Last aim position |
| `vai_px/y[id]` | pixel int | Last position snapshot used by `fai_walkaim` |
| `vai_target[id]` | player ID | Current enemy (0 = none) |
| `vai_reaim[id]` | int | Ticks until next `ai_findtarget` call |
| `vai_rescan[id]` | int | Ticks until next LOS check |
| `vai_itemscan[id]` | int | Ticks until next item scan |
| `vai_buyingdone[id]` | 0/1 | 1 once the buy sequence has completed this life |
| `vai_radioanswer[id]` | radio ID | Queued radio reply to send |
| `vai_radioanswert[id]` | int | Ticks until the reply fires |
| `vai_followangle[id]` | degrees | Roam direction used only by mode 7 |

#### `vai_smode` by mode

| Mode | `vai_smode` holds |
|---|---|
| `-1` buying | current buy step index (0-based) |
| `3` roam | movement direction in degrees |
| `4` fight | strafe direction in degrees |
| `5` hunt | hunted player ID |
| `7` follow | leader player ID |
| `50/51/52` objectives | sub-step (0 = searching, 1 = acting) |

---

### Combat pipeline (`fai_engage`)

Runs every tick in this order:

1. **Reacquire** — every `REAIM_PERIOD` (20) ticks, call `ai_findtarget`. If flashbanged, drop target and flee instead.
2. **Validate** — check the current target is still alive, on screen, and has LOS (checked every `RESCAN_PERIOD` ticks; skipped when closer than `LOS_MIN_DIST`).
3. **Aim** — call `ai_aim` toward the target or last known position.
4. **Fire** — call `ai_iattack` only when rotation is within `AIM_TOLERANCE` (20°) of the target bearing.
5. **Enter fight mode** — on first acquisition, set mode 4 with a fresh random strafe angle.

---

### Decision logic by map type (`fai_decide`)

| Map type | T behaviour | CT behaviour |
|---|---|---|
| DE (bomb) | 50% patrol bombspot; bomb carrier → mode 51 | Bomb planted → mode 52 direct to bomb; else patrol |
| CS (hostage) | Guard near hostages or roam | Mode 50: collect and escort hostages |
| AS (VIP) | Escort VIP to safe zone | Intercept at safe zone |
| CTF | Grab enemy flag; return to own base | Same |
| DOM | Capture control points (80% chance) | Same |
| Zombie (gm 4) | Hunt survivors | Flee or roam |
| Generic / DM | Wander between spawns and bot nodes | Same |

---

### Radio response table

| Command received | Bot reaction |
|---|---|
| Bomb planted | All CT bots → mode 52, routed to actual bomb position |
| Follow me / Cover me / Need backup | One random mate → mode 7 (follow) |
| Enemy spotted / Taking fire | One random mate moves to caller's tile |
| Hold position | One random mate → mode 1 (wait 30–60 s) |
| Regroup | All mode-7 bots → mode 0 |
| Fall back / Go go go / Stick together | All mode-1 and mode-7 bots → mode 0 |
| Report in | One random mate sends the reporting-in reply |

Replies are scheduled with a random 35–100 tick delay so they don't all fire at once.

---

### Buy sequence

Steps run in order with a 1–5 tick gap between each:

| Step | Action |
|---|---|
| 0 | AK-47 (T) or M4A1 (CT); or primary ammo if already have a rifle |
| 1 | Full armor ≥$1000, or kevlar only ≥$650 |
| 2 | HE grenade — 25% chance, requires ≥$300 |
| 3 | Secondary ammo |
| 4 | Switch to knife so the bot runs at full speed |