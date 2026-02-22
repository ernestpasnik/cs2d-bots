# 🧠 CS2D Bots — Human-Like Edition

## 📁 File Structure

**`Standard AI.lua`** — Entry point; state tables, mode dispatch, engine callbacks  
**`includes/constants.lua`** — All magic numbers in one place (+ human-behaviour tuning params)  
**`includes/core.lua`** — Server settings, shared utilities, smooth-aim + burst-fire helpers  
**`includes/combat.lua`** — Target tracking, smooth aiming, firing, strafing, peek-and-retreat  
**`includes/objectives.lua`** — Bomb plant/defuse, hostage rescue  
**`includes/movement.lua`** — Item collection, follow-teammate logic  
**`includes/tactics.lua`** — Buy logic, round decisions, radio replies  

`core.lua` auto-loads `constants.lua`. Everything else is loaded by `Standard AI.lua`.

---

## 🆕 Human-Like Improvements

### 🎯 Shooting

| Feature | Behaviour |
|---|---|
| Smooth aim interpolation | Aim glides toward the enemy each tick; faster at higher skill |
| Reaction time delay | 3–8 tick delay before committing to a new target (shorter at high skill) |
| Burst fire control | Bots tap fire in short bursts at range; full-auto only up close |
| Recoil compensation | Aim nudged downward after each shot; accumulated recoil decays when not firing |
| Target velocity prediction | Bot leads moving enemies by up to 5 ticks (skill-scaled) |
| Movement-accuracy penalty | Fire cone widens when moving; tightens when crouched |
| Crouch-to-shoot | Probability scales with skill (5%→45%); bot crouches only when stationary |

### 🏃 Movement

| Feature | Behaviour |
|---|---|
| Peek-and-retreat | Bot strafes out of cover, fires, then steps back behind it |
| Micro-duck on geometry | Tries to crouch under blocking objects before turning |
| Tactical spacing | Follows one tile behind leader to avoid stacking |
| Slow angle sweep | Follow mode drifts direction ±10° each tick for natural milling |
| Last-known-position memory | Bot continues aiming/navigating toward where it last saw the enemy for ~4 seconds |

### 🤖 Bot Brain

| Feature | Behaviour |
|---|---|
| Priority scoring | Health prioritised when low HP; bomb highest of all, flags second |
| Afford-both check | Only buys HE grenade if money covers armor too (≥$1300) |
| Extended debug | HUD also shows peek phase and recoil offset |

---

## 🎛️ Mode State Machine

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

Combat-triggered modes:

- **[4] fight** — peek + strafe + shoot  
- **[5] hunt** — chase target until close  
- **[8] flee** — run when flashbanged  
- **[6] collect** — walk to highest-priority item  
- **[1] wait** — hold position  
- **[7] follow** — follow teammate with spacing  

---

## 📊 State Variables

All arrays are indexed by player ID (1–32).

### Core variables
| Variable | Purpose |
|---|---|
| `vai_mode[id]` | Current mode |
| `vai_smode[id]` | Sub-mode value (varies by mode) |
| `vai_timer[id]` | General countdown |
| `vai_destx/y[id]` | Navigation target |
| `vai_aimx/y[id]` | Current smooth aim position |
| `vai_px/y[id]` | Last movement snapshot |
| `vai_target[id]` | Current committed enemy |
| `vai_reaim[id]` | Ticks until next target scan |
| `vai_rescan[id]` | Ticks until next LOS check |
| `vai_itemscan[id]` | Ticks until next item scan |
| `vai_buyingdone[id]` | 1 when buy sequence finished |
| `vai_radioanswer/t[id]` | Queued radio reply |
| `vai_followangle[id]` | Roam direction for follow mode |

### Human-behaviour variables
| Variable | Purpose |
|---|---|
| `vai_reacttime[id]` | Reaction delay ticks remaining before committing to new target |
| `vai_pendingtarget[id]` | Spotted enemy not yet committed to |
| `vai_tvx/y[id]` | Target velocity estimate (px/tick) for lead aim |
| `vai_tlastx/y[id]` | Target's position last reaim tick |
| `vai_shotcount[id]` | Shots fired in current burst |
| `vai_burstpause[id]` | Ticks of fire pause remaining |
| `vai_recoiloffset[id]` | Accumulated recoil (decays when not firing) |
| `vai_crouching[id]` | 1 if bot decided to crouch this engagement |
| `vai_peekphase[id]` | 0 = strafe · 1 = peeked-out · 2 = retreating |
| `vai_memx/y[id]` | Last known enemy position |
| `vai_memtimer[id]` | Ticks of position memory remaining |

---

## ⚙️ Skill Scaling

All parameters scale linearly with `bot_skill` (0–100).

| Parameter | Skill 0 (worst) | Skill 100 (best) |
|---|---|---|
| Aim smooth factor | 0.12 — very slow | 0.55 — fast, not instant |
| Aim jitter radius | 14 px | 2 px |
| Target lead | 0 ticks | 5 ticks |
| Recoil compensation | Weak | Strong |
| Burst size | 2 shots | 5 shots |
| Reaction delay | ~8 ticks | ~3 ticks |
| Crouch chance | 5% | 45% |

---

## 🔫 Combat Pipeline (`fai_engage`)

Runs every tick:

1. **Reacquire** — every 20 ticks, run `ai_findtarget`; start reaction-time countdown for new targets  
2. **React** — decrement reaction timer; commit target when it reaches zero  
3. **Validate** — check alive, visible, LOS; store last-known position on loss  
4. **Velocity** — estimate target movement delta for lead prediction  
5. **Smooth-aim** — lerp current aim toward predicted position + jitter  
6. **Recoil** — offset aim by accumulated recoil; decay when not shooting  
7. **Fire** — shoot when within dynamic fire cone (narrower crouching, wider moving)  
8. **Burst** — record shot; pause fire when burst limit hit  
9. **Enter fight mode** — set mode 4 with random strafe angle + crouch decision  

---

## 🛒 Buy Sequence

Each step runs with a 1–5 tick delay:

| Step | Action |
|---|---|
| 0 | Buy AK-47 (T) or M4A1 (CT), or ammo if already armed |
| 1 | Buy armor — full if ≥ $1000, kevlar if ≥ $650 |
| 2 | 25% chance to buy HE grenade — **only if ≥ $1300** (armor covered first) |
| 3 | Buy secondary ammo |
| 4 | Switch to knife for max movement speed |