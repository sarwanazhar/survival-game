# Survival Island — Story, Cutscenes, Hollow Keeper & Collision Fix Pack

## What's Included
1. **Walkable Lighthouse Cliff & Exact Trimesh Collision Fix**:
   - `assets/models/island_terrain.glb`: Lowered the Lighthouse summit to `5.2m` and sculpted a wide, smooth walkable dirt ramp along the trail so the player climbs effortlessly to the Lighthouse.
   - `scenes/island_map.tscn` & `scenes/island_setup.gd`: Placed `Lighthouse.glb` flush on the `5.2m` summit (`y = ground + 1.79`) and upgraded prop collision to `mesh_instance.create_trimesh_collision()` so the player can stand on the Lighthouse platform and never clips through walls, rocks, dock, or camp props.
   - `player.gd`: Increased `floor_max_angle` to `52°` + `floor_snap_length = 0.35`, and pauses movement smoothly during cutscenes.
2. **Full Story & Cinematic Cutscenes (`scripts/cutscene_manager.gd`, `scripts/story_manager.gd`)**:
   - **Intro Cutscene** (shipwreck -> camp -> lighthouse), **Lighthouse Awakening Cutscene**, and **Rowboat Escape Ending Cutscene** with cinematic camera pans, movie letterbox bars, typewriter subtitles, and a mobile **SKIP** button.
   - **Top-Right Objective Tracker HUD** + **3 Interactive Glowing Ancient Shrines** (`assets/models/ancient_shrine.glb`) with lore notes (`[F]` or mobile tap button).
3. **Rigged & Animated Horror Stalker (`assets/models/hollow_keeper.glb` + `scripts/hollow_keeper.gd`)**:
   - Patrols near the Rocky Cliffs & Jungle (`Idle`, `Patrol_Walk`, `Chase_Run`, `Attack`), plays proximity `heartbeat.wav` + `keeper_roar.wav`, and avoids the Campfire safe zone!
4. **4 New Story/Horror SFX (`assets/audio/sfx/`)**: `cutscene_horn.wav`, `shrine_chime.wav`, `keeper_roar.wav`, `heartbeat.wav`.
