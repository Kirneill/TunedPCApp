## v1.0.15 - Fortnite settings persistence hotfix

This hotfix addresses reports that Fortnite settings were resetting on every game launch after optimization.

### Fix in this release
- Updated Fortnite optimization script to write and lock **all active config targets**, not just one path.
  - `...\Saved\Config\WindowsClient\GameUserSettings.ini`
  - `...\Saved\Config\Windows\GameUserSettings.ini`
  - `...\Saved\Config\WindowsNoEditor\GameUserSettings.ini` (if present)
- Added per-file validation and read-only verification in script output.
- Added Fortnite validation labels in app log mapping for clearer diagnostics.

### Why this fixes it
- Fortnite can use different config folders depending on install/patch state.
- Previously only `WindowsClient` was enforced, allowing another path to overwrite settings at launch.
