# Survival Island — Mobile + Full SFX + Upgraded Map Pack

## What's Upgraded
1. **31 Mobile-Friendly SFX & Ambient Loops (`assets/audio/sfx/*.wav`)** + **`scripts/sfx_manager.gd`**:
   - Surface-aware footsteps (`sand`, `grass`, `rock`, `run`), `jump`, looping `fall_wind`, `land_soft` / `land_heavy`, `water_splash_in` / `out`, `swim_stroke` / `swim_tread`
   - Every tool & combat sound: `fist_whoosh`, `axe_swing`, `axe_chop_hit`, `tree_fall`, `pickaxe_mine_hit`, `stone_break`, `shovel_dig`, `hammer_strike`, `hoe_till`, `bottle_drink`, `bucket_slosh`
   - UI & progression: `ui_click`, `craft_success`, `error_buzz`, `sapling_plant`, `tree_grow_pop`
   - Ambient & 3D spatial loops: `ambience_ocean`, `ambience_night_wind`, `campfire_crackle`
2. **Updated `player.gd`**:
   - All existing inventory, crafting, hotbar, mobile controls, sapling planting, and stone respawn preserved.
   - Full SFX + mobile haptic vibration (`Input.vibrate_handheld`) wired into every movement, swim, tool, harvest, and UI event.
3. **Richer Island Map (`assets/models/island_terrain.glb`, `scenes/island_map.tscn`, `scenes/island_setup.gd`)**:
   - Higher-detail 156×132 fractal terrain, ~75 props (dense jungle, oaks, palms, stream bridge, fences, signpost, campfire embers, floating fireflies, rocky cliffs, lighthouse ruins).
4. **Smoother Character (`assets/models/castaway_hero_with_tools.glb`)**:
   - 3x denser cosine-eased animation keyframes across all 17 clips for fluid, less robotic movement.

## Setup Steps
Extract/merge this zip into the root of your `survival-game` repo, open in Godot 4.6, let Godot re-import `assets/audio/sfx/`, `assets/models/castaway_hero_with_tools.glb`, and `assets/models/island_terrain.glb`, and run `res://scenes/island_map.tscn`.
