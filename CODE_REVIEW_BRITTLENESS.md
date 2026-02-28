# Adversarial Code Review -- Brittleness Audit
## Ebon Tide: Solar Surfer -- Pre-Launch (72h)
### Reviewed: 2026-02-28

---

## CRITICAL -- Will cause crashes or data loss

### 1. Track floor is only 10,000 units long
**File:** `track.gd:59-68`

The `StaticBody3D` floor and lane rails are fixed-length, centered at Z=-5000. Player moves in negative Z. Once a player travels ~5,000m, they fall through the world. EXPERT tier starts at 4,000m.

**Fix:** Floor StaticBody3D must follow the player or be made vastly longer.

### 2. `setup_carousel()` has a live landmine
**File:** `main_menu.gd:396-399`

```gdscript
func setup_carousel() -> void:
    pass
    add_child(carousel_root)  # STILL EXECUTES
```

`pass` does not prevent `add_child` from running. If called, causes re-parenting crash.

### 3. Obstacle spawner has uninitialized variable paths
**File:** `obstacle_spawner.gd` (lines ~203, ~267, ~371, ~900)

Multiple `match` statements on `current_zone` lack `_` default cases. A bad zone value causes "variable used before assignment" crash.

### 4. Save file has no version header
**File:** `game_data.gd:370-399`

Positional `store_var`/`get_var` with no version byte. Any schema change silently corrupts every existing save file.

### 5. DevKit ships in production
**File:** `main.tscn:81-83`, `dev_kit.gd`

DevKit is always loaded. Accessible via F1 or 5 rapid taps in top-left corner. Gives unlimited coins, damage immunity, instant unlocks, save wipes.

### 6. DevKit reset_save() is incomplete
**File:** `dev_kit.gd:392`

Doesn't reset audio/settings fields. Inconsistent with what "reset" implies.

---

## HIGH -- Visible bugs or broken gameplay

### 7. Touch boost can get stuck on Android
**File:** `player.gd:254-335`

If app is backgrounded during a boost hold, the `InputEventScreenTouch` release event is missed. Boost stays permanently active. Need `NOTIFICATION_APPLICATION_FOCUS_OUT` handler.

### 8. Coin pickup duplicates array every frame
**File:** `game_manager.gd:169`

`obstacle_spawner.coins.duplicate()` called every frame. Unnecessary GC pressure at high coin counts.

### 9. Audio fade has 40dB jump cut
**File:** `audio_manager.gd:72-75`

Fade lerps to -40dB, then hard-snaps to -80dB on completion. Audible click/pop on headphones.

### 10. Manual AABB collision, no physics engine
**File:** `game_manager.gd:103-140`

O(n) per frame against every obstacle. No broad-phase. Potential frame drops on low-end Android at EXPERT tier density.

### 11. GLB vessel visual paths are incomplete
**File:** `solar_surfer.gd`

- `set_zone()` only updates procedural components -- GLB gets no zone visuals
- `apply_board_colors()` only works with procedural -- GLB ignores custom colors
- `destroy_sail()`/`destroy_engine()` tween whole-model scale for GLB (looks wrong)

### 12. First pickup spawn check fires at frame 1
**File:** `pickup_manager.gd:36,105`

`next_spawn_check_z = 100.0` but player starts at Z~0 moving negative. Check is immediately true.

### 13. Export has placeholder package name
**File:** `export_presets.cfg:43`

`package/unique_name="com.example.$genname"` -- Play Store will reject this.

### 14. Export version code/name incomplete
**File:** `export_presets.cfg:41-42`

`version/code=1`, `version/name=""`. Empty name will likely cause export failure.

---

## MEDIUM -- Technical debt

### 15. main_menu.gd is 2,272-line god object
Handles mesh creation, UI layout, animation, input, state, purchasing, exchange. Any change risks cascading side effects.

### 16. Parallel arrays for Black Market/Exchange
4 arrays must stay in sync by index. Add/remove/reorder one without others = crash.

### 17. Black Market action button does nothing
`_on_action_pressed()` has no BLACK_MARKET case.

### 18. Ebon Pass button is unimplemented
Shows in UI, prints to console, does nothing.

### 19. IAP/ad buttons grant free currency
No purchase verification, no ad SDK. Players get free premium currency.

### 20. SettingsPanel is an autoload
Persists across scenes. Full-screen overlay could block input if visibility leaks.

### 21. Sovereign exchange bypasses validation
Direct field mutation, no bounds check. Sovereigns can go negative.

### 22. Dead variables in main_menu.gd
`fang_rock` and `backdrop_lights` declared, checked every frame, never assigned.

### 23. SubViewport hardcoded 1280x720
Blurry on high-DPI, wasteful on low-end.

### 24. Run summary timing assumption
`show_run_summary()` reads `best_distance` after a 0.5s await. Relies on `record_run()` being synchronous.

### 25. No gamepad input
Only keyboard and touch mapped. Bluetooth controllers on Android do nothing.

---

## LOW -- Cleanup

- **26.** Storm system fully coded but disabled in obstacle_spawner (~150 lines dead code)
- **27.** Particle cleanup tween on wrong node in particle_manager.gd:203
- **28.** `_get_music_db()` always returns 0.0
- **29.** Only left Shift mapped for boost, not right Shift
- **30.** "NEW BEST" triggers on tie (>= instead of >)

---

## Priority Fix Order (72h)

| Priority | Fix | Effort | Impact |
|----------|-----|--------|--------|
| P0 | Extend floor in track.gd | 30 min | Crash prevention |
| P0 | Remove/gate DevKit | 15 min | Security |
| P0 | Fix export package name + version | 5 min | Store submission |
| P1 | Fix audio fade snap | 10 min | Audio quality |
| P1 | Add save format version byte | 30 min | Future-proofing |
| P1 | Touch state cleanup on focus loss | 15 min | Android stability |
| P1 | Fix initial pickup spawn timing | 5 min | Gameplay |
| P2 | Hide/disable IAP buttons | 10 min | Monetization integrity |
| P2 | Add default cases to match statements | 10 min | Crash prevention |
