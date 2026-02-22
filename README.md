# CS2D Bots

> Modernized bot AI for CS2D — smarter decisions, cleaner Lua, gameplay that feels human.

---

## Goals

- 🎯 Better combat intelligence
- 🧠 Less robotic behaviour  
- 🚶 Smarter navigation & pathfinding
- ⏱️ Improved reaction timing & targeting
- 🔧 Clean, maintainable Lua codebase

---

## Structure

```
bots/
├── settings.lua    # Game settings cache
├── general.lua     # Shared utilities & math helpers
├── decide.lua      # Decision logic per game mode
├── engage.lua      # Target detection & aiming
├── fight.lua       # Combat movement & strafing
├── follow.lua      # Teammate follow behaviour
├── collect.lua     # Item pickup scanning
├── buy.lua         # Weapon & equipment buying
├── radio.lua       # Radio command responses
├── bomb.lua        # Plant & defuse logic
└── hostages.lua    # Hostage rescue logic
```

---

## AI Modes

| Mode | Description |
|------|-------------|
| `-1` | Buying phase |
| `0`  | Decide next action |
| `1`  | Wait / hold position |
| `2`  | Move to destination |
| `3`  | Roam randomly |
| `4`  | Fight target |
| `5`  | Hunt / chase target |
| `6`  | Collect item |
| `7`  | Follow teammate |
| `8`  | Recover from flashbang |
| `50` | Rescue hostages |
| `51` | Plant bomb |
| `52` | Defuse bomb |

---

## Game Mode Support

- **DM** — Deathmatch free-for-all
- **CS** — Hostage rescue
- **DE** — Bomb defusal
- **AS** — VIP escort
- **CTF** — Capture the flag
- **DOM** — Domination
- **ZM** — Zombie mode

---

> ⚠️ Experimental — under active development.