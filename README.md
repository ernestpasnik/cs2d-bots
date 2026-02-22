# 🧠 CS2D Bots

## 📁 File Structure

**`Standard AI.lua`** — Entry point; state tables, mode dispatch, engine callbacks  
**`includes/constants.lua`** — All magic numbers in one place  
**`includes/core.lua`** — Server settings + shared utilities  
**`includes/combat.lua`** — Target tracking, aiming, firing, strafing  
**`includes/objectives.lua`** — Bomb plant/defuse, hostage rescue  
**`includes/movement.lua`** — Item collection, follow‑teammate logic  
**`includes/tactics.lua`** — Buy logic, round decisions, radio replies  

`core.lua` auto‑loads `constants.lua`. Everything else is loaded by `Standard AI.lua`.

---

## 🔄 How It Works

### ⏱️ Tick Loop

Every tick, CS2D calls `ai_update_living(id)` for each living bot:

```
ai_update_living(id)
  fai_engage(id)        -- always runs: scan, aim, shoot
  radio reply timer     -- counts down, fires queued ai_radio()
  fai_collect(id)       -- item scan; may switch to mode 6
  MODE[vai_mode[id]]    -- dispatch behaviour
```

`fai_engage` always runs so bots can shoot even while buying, following, or defusing.  
It skips target‑finding in modes **-1** (buying) and **1** (waiting).

---

## 🎛️ Mode State Machine

Each bot has a `vai_mode[id]` that defines its behaviour.  
Modes jump to each other by directly writing to `vai_mode`.

```
spawn
  ↓
[-1] buying
  ↓
[0] decide
  ├─ [2] goto destination
  ├─ [3] roam
  ├─ [50] rescue hostages
  ├─ [51] plant bomb
  └─ [52] defuse bomb
```

Combat‑triggered modes:

- **[4] fight** — strafe + shoot  
- **[5] hunt** — chase target until close  
- **[8] flee** — run when flashbanged  
- **[6] collect** — walk to item  
- **[1] wait** — hold position  
- **[7] follow** — follow teammate

---

## 📊 State Variables

All arrays are indexed by player ID (1–32).

- `vai_mode[id]` — current mode  
- `vai_smode[id]` — sub‑mode value (varies by mode)  
- `vai_timer[id]` — general countdown  
- `vai_destx/y[id]` — navigation target  
- `vai_aimx/y[id]` — last aim position  
- `vai_px/y[id]` — last movement snapshot  
- `vai_target[id]` — current enemy  
- `vai_reaim[id]` — ticks until next target scan  
- `vai_rescan[id]` — ticks until next LOS check  
- `vai_itemscan[id]` — ticks until next item scan  
- `vai_buyingdone[id]` — 1 when buy sequence finished  
- `vai_radioanswer[id]` — queued radio reply  
- `vai_radioanswert[id]` — ticks until reply  
- `vai_followangle[id]` — roam direction for follow mode  

### `vai_smode` meaning by mode

- **-1** — buy step index  
- **3** — roam direction (degrees)  
- **4** — strafe direction (degrees)  
- **5** — hunted player ID  
- **7** — follow target ID  
- **50/51/52** — objective sub‑step (0 = searching, 1 = acting)

---

## 🔫 Combat Pipeline (`fai_engage`)

Runs **every tick**:

1. **Reacquire** — every 20 ticks, run `ai_findtarget`  
2. **Validate** — check alive, visible, LOS  
3. **Aim** — rotate toward target  
4. **Fire** — shoot when within 20°  
5. **Enter fight mode** — set mode 4 with random strafe angle

---

## 🗺️ Decision Logic by Map Type

- **DE (bomb)**  
  - T: 50% patrol; bomb carrier → plant  
  - CT: if bomb planted → defuse; else patrol  
- **CS (hostage)**  
  - T: guard or roam  
  - CT: rescue hostages  
- **AS (VIP)**  
  - T: escort VIP  
  - CT: intercept  
- **CTF** — capture enemy flag  
- **DOM** — capture points  
- **Zombie** — T hunts, CT flees/roams  
- **DM/Generic** — wander between nodes

---

## 📻 Radio Responses

- **Bomb planted** → all CTs go defuse  
- **Follow me / Cover me / Need backup** → one bot follows  
- **Enemy spotted / Taking fire** → one bot moves to caller  
- **Hold position** → one bot waits  
- **Regroup / Fall back / Go go go / Stick together** → reset to mode 0  
- **Report in** → one bot replies  

Replies fire after a random 35–100 tick delay.

---

## 🛒 Buy Sequence

Each step runs with a 1–5 tick delay:

0. Buy AK‑47 (T) or M4A1 (CT), or ammo if already armed  
1. Buy armor (full if ≥$1000, kevlar if ≥$650)  
2. 25% chance to buy HE grenade (≥$300)  
3. Buy secondary ammo  
4. Switch to knife for max speed