## v1.0.14 - Apex Legends Max FPS support

This release adds full Apex Legends optimization support based on the project research profile.

### New in this release
- Added Apex Legends as a selectable game optimization in the app UI.
- Added automatic Apex install detection for Steam and EA/common install paths.
- Added a dedicated Apex optimization script:
  - Writes competitive `videoconfig.txt` values for max FPS.
  - Enforces `videoconfig.txt` read-only (critical for persistence).
  - Creates/updates `autoexec.cfg` in Apex `cfg` folder.
  - Applies safe Windows compatibility flags for `r5apex.exe`.
- Added Apex-specific validation checks into run logs.
- Updated NVIDIA per-game guidance for Apex Reflex behavior.

### Notes
- Some settings remain manual by design: NVIDIA Reflex (Enabled + Boost), TSAA, and launch options (`+fps_max 0 -novid -preload -high`).
