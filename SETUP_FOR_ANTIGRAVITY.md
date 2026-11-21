# Survival Island Pack — Godot 4.6 / Antigravity Setup Guide

## 1. Extract into Project Root (`hotel/`)
Copy/merge the two folders from this zip directly into your `hotel/` Godot project:
- `assets/models/castaway_hero_with_tools.glb` *(replaces existing model — adds `Swim_Idle` & `Swim_Forward`, keeps all 13 tool nodes & 15 previous animations intact!)*
- `assets/models/island_terrain.glb` *(sculpted 160m × 130m island with `-col` auto-collision)*
- `assets/models/rowboat.glb` *(castaway wooden boat)*
- `scenes/island_map.tscn` *(complete island scene using your existing Kenney Nature Kit, Survival Kit, Lighthouse, and `player.tscn`)*
- `scenes/island_setup.gd` *(rotates Lighthouse beacon, flickers campfire, triggers swim zone)*
- `scenes/ocean_water.gdshader` *(GL Compatibility ocean water shader)*

## 2. Open & Run in Godot 4.6
1. Open `res://scenes/island_map.tscn` (or set it as `run/main_scene` in `project.godot`).
2. In Godot's **Advanced Import Settings** for `castaway_hero_with_tools.glb`, set Loop Mode = **Linear** on `Idle`, `Walk`, `Run`, `Fall`, `Item_Bucket_Carry`, `Swim_Idle`, and `Swim_Forward`.

## 3. Wire Swimming into `player.gd` (for Antigravity)
Add these fields and method to `res://player.gd` so `OceanSwimZone` automatically toggles swimming:

```gdscript
@export var swim_speed: float = 3.6
var is_swimming: bool = false
var water_surface_y: float = 0.0

func set_swimming(active: bool, surface_y: float = 0.0) -> void:
    is_swimming = active
    water_surface_y = surface_y
```

Inside `_physics_process(delta)`:
- When `is_swimming` is `true` and `global_position.y <= water_surface_y - 0.6`:
  - Gently buoy `velocity.y` toward `(water_surface_y - 0.85 - global_position.y) * 5.0` (and allow Space to swim/jump out near shore).
  - Move horizontally at `swim_speed`.
  - Play `"Swim_Forward"` when moving, or `"Swim_Idle"` when stationary.
