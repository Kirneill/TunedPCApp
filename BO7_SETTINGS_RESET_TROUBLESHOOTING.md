# BO7 Settings Reset To Extreme: Root Cause and Fix (v1.0.13)

## Symptom

- BO7 settings in `BO7BACKUP` are low/performance.
- Manually copying those files into the BO7 `players` folder works.
- Running BO7 optimization through the app makes BO7 show or revert to extreme/high settings.

## Root Cause

The template files were not being kept as exact bytes when applied through the app path.

Previous BO7 script logic copied templates and then rewrote `.txt` files using `Get-Content` + regex + `Set-Content` to patch `RendererWorkerCount`. That rewrite step can change file formatting/encoding/newline representation. For BO7 config parsing, those byte-level changes can produce behavior different from manual Explorer copy, including values appearing to reset to unwanted presets.

## What Was Changed In v1.0.13

1. BO7 apply step changed to strict byte-for-byte replacement only.
   - Script now deletes existing destination files and copies the template files directly.
   - Hash verification (`SHA256`) confirms destination exactly matches source.
2. Removed BO7 in-place text patching.
   - No `Set-Content` mutation for BO7 template files.
   - `RendererWorkerCount` patching is intentionally skipped to preserve exact template bytes.
3. Forced cloud sync flag off in both BO7 template files.
   - `ConfigCloudStorageEnabled@... = false` in:
     - `scripts/BO7BACKUP/s.1.0.cod25.txt0`
     - `scripts/BO7BACKUP/s.1.0.cod25.txt1`

## Files Updated

- `scripts/02_BlackOps7_Settings.ps1`
- `scripts/BO7BACKUP/s.1.0.cod25.txt0`
- `scripts/BO7BACKUP/s.1.0.cod25.txt1`
- `src/components/ui/CodFpsGuideModal.tsx`

## How To Verify If This Regresses Later

1. Run BO7 optimization from app.
2. Compare source and destination hashes:
   - Source: `scripts/BO7BACKUP/s.1.0.cod25.txt0|txt1|m`
   - Destination: `%LOCALAPPDATA%\Activision\Call of Duty\players\...`
3. If hashes differ, the app is mutating files after copy (regression).
4. If hashes match but BO7 still changes settings, BO7/runtime/cloud is overwriting after launch.

PowerShell hash check example:

```powershell
$src = "C:\Path\To\scripts\BO7BACKUP"
$dst = "$env:LOCALAPPDATA\Activision\Call of Duty\players"
"s.1.0.cod25.txt0","s.1.0.cod25.txt1","s.1.0.cod25.m" | ForEach-Object {
  $s = Join-Path $src $_
  $d = Join-Path $dst $_
  [pscustomobject]@{
    File = $_
    SrcHash = (Get-FileHash $s -Algorithm SHA256).Hash
    DstHash = (Get-FileHash $d -Algorithm SHA256).Hash
    Match = ((Get-FileHash $s -Algorithm SHA256).Hash -eq (Get-FileHash $d -Algorithm SHA256).Hash)
  }
}
```

## If This Happens Again

- Do not add BO7 `Set-Content` rewriting on copied template files.
- Keep BO7 template application byte-for-byte.
- If hardware-specific tuning is needed, change templates directly, not via post-copy rewrite.
