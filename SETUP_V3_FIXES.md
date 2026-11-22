# Survival Island V3 Fix Pack — Monster V2 + Visible Lighthouse Beams + GitHub Actions CI Fix

## What's Fixed
1. **Redesigned Realistic Monster (`assets/models/hollow_keeper.glb`)**:
   - Full 15-joint humanoid horror skeleton (`Hips`, `Spine`, `Chest`, `Neck`, `Head`, `UpperArm/LowerArm/Hand L/R`, `UpperLeg/LowerLeg L/R`).
   - Sculpted skull head with hollow sockets, blazing crimson eyes, cracked jaw/teeth, branching curved antlers, exposed ribs, tattered sea-cloak + mossy shoulder mantle, 4 long curved claws per hand, and a rusted iron cage-lantern staff.
   - 4 smooth cosine-eased animations: `Idle`, `Patrol_Walk`, `Chase_Run`, `Attack`.
2. **Visible Rotating Lighthouse Light Beams (`scenes/island_setup.gd`)**:
   - Centers `BeaconPivot` inside the Lighthouse lantern room (`+14.2m`), adds a glowing emissive core orb, a warm `OmniLight3D`, two huge additive translucent volumetric rotating beam cones (100% visible on mobile GL Compatibility!), and boosted `SpotLight3D` sweeps.
3. **GitHub Actions Android APK Build Fix (`.github/workflows/build_android_apk.yml` + `export_presets.cfg`)**:
   - Replaced failing `android-actions/setup-android@v3` with `ubuntu-latest`'s pre-installed Android SDK (`$ANDROID_HOME`).
   - Removed hardcoded `/home/sarwan/...` paths in `export_presets.cfg` and added headless `--import` + `editor_settings-4.6.tres` configuration so CI exports `builds/island_survival.apk` cleanly.
