# 🤖 CS2D Bots

AI bots for CS2D with human-like movement and shooting behaviour.

---

## 📁 Files

| File | Purpose |
|------|---------|
| `Standard AI.lua` | Entry point — state, modes, engine callbacks |
| `includes/constants.lua` | Every magic number and tuning parameter |
| `includes/core.lua` | Utilities, smooth aim, burst fire helpers |
| `includes/combat.lua` | Targeting, aiming, shooting, peeking |
| `includes/movement.lua` | Item pickup, follow-teammate logic |
| `includes/objectives.lua` | Bomb plant/defuse, hostage rescue |
| `includes/tactics.lua` | Buying, round decisions, radio responses |

---

## 🎮 Modes

| # | Mode | What the bot does |
|---|------|-------------------|
| `-1` | **Buying** | Steps through buy sequence |
| `0` | **Decide** | Picks the next goal |
| `1` | **Wait** | Holds position |
| `2` | **Goto** | Walks to a destination |
| `3` | **Roam** | Wanders with a heading |
| `4` | **Fight** | Strafes, peeks, shoots |
| `5` | **Hunt** | Chases a specific enemy |
| `6` | **Collect** | Walks to an item |
| `7` | **Follow** | Follows a teammate |
| `8` | **Flee** | Runs while flashbanged |
| `50` | **Rescue** | CT rescues hostages |
| `51` | **Plant** | T plants the bomb |
| `52` | **Defuse** | CT defuses the bomb |

---

## 🧠 Human-Like Behaviour

### 🎯 Shooting
- **Reaction delay** — bots don't snap instantly; they pause before locking on (shorter at high skill)
- **Smooth aim** — aim glides toward the target each tick instead of teleporting
- **Aim jitter** — small random tremor simulates an unsteady hand (less at high skill)
- **Target lead** — bots aim ahead of moving enemies based on their velocity
- **Burst fire** — controlled bursts at range, full-auto only up close
- **Recoil compensation** — aim shifts to counter rifle climb after each shot
- **Crouch to shoot** — bots sometimes crouch when stationary for better accuracy

### 🏃 Movement
- **Peek-and-retreat** — strafe out, shoot, then step back into cover
- **Tactical spacing** — follows one tile behind teammates instead of stacking
- **Last-known position** — remembers where an enemy was last seen for ~4 seconds

### 🛒 Buying
- Only buys a grenade if there's enough money left for armour too
- Switches to knife after buying for full movement speed

---

## ⚙️ Skill Scaling (`bot_skill` 0 → 100)

| Parameter | Skill 0 | Skill 100 |
|-----------|---------|-----------|
| Reaction delay | ~8 ticks | ~3 ticks |
| Aim smooth speed | slow | fast |
| Aim jitter | 14 px | 2 px |
| Target lead | 0 ticks | 5 ticks |
| Burst size | 2 shots | 5 shots |
| Crouch chance | 5% | 45% |
| Recoil control | weak | strong |

---

## 🗺️ Map Support

| Mode | T side | CT side |
|------|--------|---------|
| 💣 **DE** | Plant bomb | Defuse bomb |
| 👤 **CS** | Guard hostages | Rescue hostages |
| 🏃 **AS** | Escort VIP | Intercept VIP |
| 🚩 **CTF** | Capture flag | Capture flag |
| ⭕ **DOM** | Cap control points | Cap control points |
| 🧟 **Zombie** | Hunt survivors | Flee or roam |
| 🔫 **DM** | Wander and shoot | Wander and shoot |

---

## 📻 Radio Commands

| Command | Bot response |
|---------|-------------|
| Bomb planted | All CTs rush to defuse |
| Follow me / Cover me / Need backup | One bot follows the caller |
| Enemy spotted / Taking fire | One bot moves to the caller |
| Hold position | One bot camps for 30–60 s |
| Regroup / Fall back / Go go go | Followers and campers resume moving |
| Report in | One bot replies |

---

## 🐛 Debug

Set `debugai 1` on the server to show a HUD label above each bot:

```
m:4 sm:90 ta:7 ti:23 pk:1 rc:3.0
```

`m` = mode · `sm` = sub-mode · `ta` = target ID · `ti` = timer · `pk` = peek phase · `rc` = recoil offset