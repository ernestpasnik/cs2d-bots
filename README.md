# 🤖 CS2D Bots

![Lua](https://img.shields.io/badge/Lua-5.1%2FLuaJIT-blue?logo=lua)
![CS2D](https://img.shields.io/badge/CS2D-compatible-orange)
![License](https://img.shields.io/badge/license-MIT-green)
![Status](https://img.shields.io/badge/status-production--ready-brightgreen)

> Human-like AI bots for CS2D with smooth aiming, burst fire, post-plant bomb logic, and personality-driven behaviour.

---

## 📦 Install

Copy the files from this repository into your `cs2d/bots/` folder, then add to your server config:

```
bot_count 10
bot_skill 2
bot_weapons 1
```

---

## 🎮 How It Works

### 🎯 Aiming

Bots don't snap to targets. When an enemy is spotted there's a short **reaction delay** before they engage — at skill 0 this is around 360ms, at skill 4 it's around 60ms. Once they start tracking, the aim **rotates smoothly** toward the target each tick rather than teleporting.

Accuracy degrades naturally based on three factors:
- **Distance** — targets further than 180px get an extra aim penalty
- **Movement** — running adds a miss angle on top of distance penalty
- **Spray drift** — after 3 continuous shots the aim starts climbing to simulate recoil, recovering during burst pauses

Bots fire in **controlled bursts** with short pauses between them, and occasionally **crouch while stationary** to tighten their spread.

### 🏃 Movement

In a fight bots **peek and retreat** — they strafe out, shoot, then step back into cover for a few ticks before going again. If an enemy disappears from view the bot remembers the **last-known position** for ~2.4 seconds and moves to check it.

When following a teammate bots keep **one tile of spacing** instead of stacking, and will briefly **hesitate at corners** before rounding them (12% chance) to feel less robotic.

### 💣 Post-Plant (DE maps)

After planting, T bots switch into **guard mode** and hold within a few tiles of the bomb. They strafe and shoot CTs that push the site, and periodically confirm the bomb is still there. When the round timer gets low they automatically **flee the blast radius** and sprint away until they're a safe distance clear.

CTs react to the plant by rushing **directly to the bomb's location**. If no enemies are visible on arrival they start defusing immediately without hesitation. If a fight is happening they hold near the bomb and let combat play out first.

### 🛒 Buying

Each bot rolls a **personality archetype** on spawn that it keeps for its whole life:

- 🔴 **Aggressive** — fast reactions, pushes 70% of the time, buys grenades often
- 🔵 **Cautious** — slow reactions, hangs back, always tries to buy armour
- 🟢 **Support** — balanced play, high grenade purchase rate
- ⚪ **Balanced** — 50/50 on everything, medium aim speed

After buying, bots switch to knife for full run speed.

### 📻 Radio

| Command | What happens |
|---------|-------------|
| Bomb planted | All CTs rush to defuse · all idle Ts guard the bomb |
| Follow me / Cover me / Need backup | One random teammate follows the caller |
| Enemy spotted / Taking fire | One teammate moves to the caller's position |
| Hold position | One teammate camps for 30–60 seconds |
| Regroup / Fall back / Go go go | Cancels follows and camps, bots resume moving |
| Report in | One teammate replies |

---

## 🗺️ Map Support

- 💣 **DE** — Ts plant and guard the bomb · CTs defuse
- 👤 **CS** — Ts guard hostages · CTs rescue them
- 🏃 **AS** — Ts escort the VIP · CTs intercept
- 🚩 **CTF** — both sides capture the enemy flag
- ⭕ **DOM** — both sides capture control points
- 🧟 **ZM** — Ts hunt survivors · CTs flee or roam
- 🔫 **DM** — everyone wanders and shoots

---

## ⚙️ Skill Scaling (`bot_skill` 0–4)

| | Skill 0 | Skill 4 |
|--|---------|---------|
| Reaction | ~360ms | ~60ms |
| Aim speed | Slow | Fast |
| Spray drift | Heavy | Light |
| Burst size | 2 shots | 5 shots |
| Crouch chance | 5% | 45% |

---

## 🔧 Tuning

Everything is in `includes/constants.lua`. Key values:

- `BOMB_CAMP_RADIUS` — tiles Ts stay near the planted bomb
- `BOMB_ESCAPE_TICKS` — how early Ts flee before detonation
- `LKP_MEMORY_TICKS` — how long bots remember a last-seen enemy position
- `PANIC_HP_THRESHOLD` — HP level that triggers a retreat
- `BURST_SIZE_MIN/MAX` — shots per burst
- `REACT_TICKS_FAST/MED/SLOW` — reaction delay per personality

---

## 🐛 Debug

```
debugai 1
```

Shows a live label above each bot:

```
m:4 sm:90 ta:7 ti:23 pers:1 drift:3.0
```

`m` = mode · `sm` = sub-mode · `ta` = target ID · `ti` = timer · `pers` = personality · `drift` = spray drift

---

## 📄 License

MIT