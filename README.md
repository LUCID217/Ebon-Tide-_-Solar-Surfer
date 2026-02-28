# Ebon Tide Prototype

A 3D rail-runner prototype built in Godot 4.

## Setup Instructions

1. **Open Godot 4** (version 4.2 or later recommended)
2. Click **"Import"** on the Project Manager
3. Navigate to this folder and select `project.godot`
4. Click **"Import & Edit"**
5. Once the editor opens, press **F5** (or click the Play button) to run the game

## Controls

| Key | Action |
|-----|--------|
| **A** or **←** | Move to left lane |
| **D** or **→** | Move to right lane |
| **SPACE** | Jump |
| **SHIFT** | Boost (uses Solar Charge) |
| **R** | Restart (after death) |

## What's In This Prototype

- ✅ 3-lane rail system
- ✅ Third-person camera (behind the board)
- ✅ Lane switching with smooth movement
- ✅ Jump mechanic
- ✅ Solar Charge boost system (fills passively, drains while boosting)
- ✅ Obstacle spawning
- ✅ One-hit death
- ✅ Camera pullback on death (shows what killed you)
- ✅ Basic HUD (charge bar, distance)
- ✅ Warm sunset sky environment

## Next Steps

Once you've played this and it feels right, we can add:
- Touch/swipe controls for mobile
- More obstacle types (sweep drones, energy gates, collapsing track)
- Solar Spark pickups
- Scripted hostile riders
- Sound effects and music
- Better visuals (your actual art style)

## Troubleshooting

**"Scene not found" error:**  
Make sure all files are in the correct folders:
- `scripts/` folder contains all `.gd` files
- `scenes/` folder contains `main.tscn`
- `project.godot` is in the root folder

**Game runs but nothing happens:**  
Check the Output panel at the bottom of Godot for errors.

---

Built for the Ebon Tide GDD v2.1
