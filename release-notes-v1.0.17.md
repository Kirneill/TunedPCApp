## v1.0.17 - Fortnite settings save fix

This release fixes Fortnite not saving in-game settings after optimization.

### Fix in this release
- Updated Fortnite optimization to keep `GameUserSettings.ini` writable (read-only cleared).
- Applies and validates writable state across all active Fortnite config targets:
  - `...\Saved\Config\WindowsClient\GameUserSettings.ini`
  - `...\Saved\Config\Windows\GameUserSettings.ini`
  - `...\Saved\Config\WindowsNoEditor\GameUserSettings.ini` (if present)
- Updated app validation label to report writable state for Fortnite config checks.

### Why this fixes it
- Fortnite cannot persist in-game changes when the config file is read-only.
- This hotfix ensures config writes from the app still apply, while Fortnite can save user changes normally.
