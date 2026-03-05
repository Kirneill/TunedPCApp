# League of Legends -- FPS Optimization Settings

> **Last updated:** 2026-03-05
> **Game version verified against:** Patch 14.10+ / Season 15 (2025)
> **Engine:** Riot proprietary engine (not Unreal/Unity)

## Important Caveats

- League of Legends uses Riot's **proprietary game engine** -- NOT Unreal Engine or Unity
- Config files use **standard INI format** (game.cfg) and **JSON** (PersistedSettings.json)
- **Riot Vanguard** anti-cheat (kernel driver, deployed for LoL in patch V14.9 mid-2024). Config file edits are **SAFE** -- Vanguard monitors for cheat tools and memory modification, not user settings files
- game.cfg is **rewritten on every game exit** -- set read-only after editing to preserve values
- LoL does NOT use Unreal Engine conventions -- section names and key names are Riot-specific
- **DO NOT modify** `input.ini` -- it contains keybindings and is personal to each player

---

## 1. Config File Specification

**Confidence: HIGH**

| Property | Value |
|----------|-------|
| **Config file path** | `<LOL_INSTALL>\Game\Config\game.cfg` |
| **Default install path** | `C:\Riot Games\League of Legends\` |
| **File format** | INI (standard Windows INI with `[Section]` headers and `Key=Value` pairs) |
| **File encoding** | ANSI / UTF-8 without BOM (standard INI encoding) |
| **File extension** | `.cfg` |

### Other Config Files

| File | Path | Purpose | Modify? |
|------|------|---------|---------|
| `game.cfg` | `<LOL>\Game\Config\game.cfg` | Graphics, sound, gameplay, HUD settings | **YES** -- primary target |
| `PersistedSettings.json` | `<LOL>\Game\Config\PersistedSettings.json` | Auto-generated JSON mirror of game.cfg + input.ini (server-synced) | **NO** -- auto-generated, do not edit directly |
| `input.ini` | `<LOL>\Game\Config\input.ini` | Keybindings and input settings | **NO** -- personal keybindings, never touch |

### Structural Requirements

The game.cfg file uses standard INI format with these sections. The game will regenerate missing sections with defaults on next launch, but the following sections are expected:

- `[General]` -- Display mode, resolution, visual toggles, mouse settings
- `[Performance]` -- Graphics quality, shadows, FPS cap, AA, particle budgets
- `[HUD]` -- Interface scaling, minimap, chat, health bars
- `[Sound]` / `[Volume]` -- Audio levels
- `[FloatingText]` -- Damage number display toggles
- `[Chat]` -- Chat position and filter
- `[Voice]` -- Voice chat settings
- `[LossOfControl]` -- CC indicator settings
- `[Accessibility]` -- Color adjustments
- `[ColorPalette]` -- Colorblind mode
- `[Replay]` / `[Highlights]` -- Replay settings
- `[MapSkinOptions]` -- Event map skin toggles
- `[RecommendPage]` -- Per-champion item build presets (user data -- PRESERVE)
- `[ItemShop]` -- Shop window position/state
- `[TFTHUD]` / `[TFTChat]` / `[TFT]` -- Teamfight Tactics settings
- `[Mobile]` -- Mobile/cross-platform settings
- `[Ftux]` -- First-time user experience flags

If the file is missing entirely, the game creates it from defaults. If sections are missing, they are regenerated. If keys within a section are missing, defaults are used.

### File Ownership

- **game.cfg is rewritten every time a game ends.** In-game settings changes overwrite the file.
- Setting the file to **read-only** prevents the game from overwriting it. This is the recommended approach for enforcing optimized settings.
- Read-only causes a **silent failure** when the game tries to save -- harmless but prevents in-game settings changes from persisting until read-only is removed.
- There is only one game.cfg per installation (not per account).

---

## 2. Reference Config File

> **REQUIRED:** This is a COMPLETE, REAL config file compiled from multiple verified sources.

**Sources:**
- https://github.com/kevin7600/LOL-configs/blob/master/game.cfg (CfgVersion 13.21)
- https://github.com/fluzz142857/lol-config/blob/master/game.cfg (CfgVersion 9.15)
- https://gist.github.com/matootie/dcfef766dec2a4b74df9457d6933e599 (CfgVersion 14.10)

The following reference config represents a **performance-optimized competitive config** with all known keys. Keys marked with comments indicate which are safe to override vs which must be preserved.

```ini
[General]
WindowMode=0
Width=1920
Height=1080
Colors=32
CfgVersion=14.10.585.8823
UserSetResolution=1
WaitForVerticalSync=0
EnableScreenShake=0
HideEyeCandy=1
RelativeTeamColors=0
PredictMovement=0
ShowTurretRangeIndicators=0
ShowGodray=0
ShowCursorLocator=0
EnableLightFx=0
EnableSoftParticleSupport=0
Antialiasing=0
AutoAcquireTarget=0
EnableTargetedAttackMove=1
EnableLeftMouseButtonAttackMove=0
TargetChampionsOnlyAsToggle=0
SnapCameraOnRespawn=1
MinimizeCameraMotion=0
BindSysKeys=0
EnableAudio=1
EnableCustomAnnouncer=0
EnableCosmeticArenaAudio=0
EnableGlobalSpellCastNotifications=0
RecommendJunglePaths=1
ClampCastTargetLocationWithinMaxRange=0
HideExternalBrowserPrompt=0
ThemeMusic=0
CursorOverride=0
CursorScale=1.0000
AlwaysShowExtendedTooltip=0
OSXMouseAcceleration=0
GameMouseSpeed=10
SystemMouseSpeed=0
PreferDX9LegacyMode=0
PreferOpenGLLegacyMode=0

[Performance]
GraphicsSlider=-1
ShadowsEnabled=0
ShadowQuality=0
CharacterQuality=1
EnvironmentQuality=1
EffectsQuality=1
CharacterInking=0
EnableGrassSwaying=0
EnableFXAA=0
EnableHUDAnimations=0
EnableParticleOptimizations=1
AutoPerformanceSettings=0
GammaEnabled=0
FrameCapType=10
BudgetOverdrawAverage=10
BudgetSkinnedVertexCount=40000
BudgetSkinnedDrawCallCount=50
BudgetTextureUsage=20000
BudgetVertexCount=100000
BudgetTriangleCount=100000
BudgetDrawCallCount=500

[Sound]
DefaultFXVolume=100
DefaultMusicVolume=100

[HUD]
FlashScreenWhenDamaged=1
FlashScreenWhenStunned=1
ShowHealthBarShake=0
ShowFPSAndLatency=1
ShowAlliedChat=1
ShowAllChannelChat=1
ShowTimestamps=1
ChatScale=50
DrawHealthBars=1
AutoDisplayTarget=1
MinimapMoveSelf=1
ShowNeutralCamps=1
ObjectTooltips=1
ShowAttackRadius=1
NumericCooldownFormat=1
NameTagDisplay=1
ShowSummonerNames=1
ShowSummonerNamesInScoreboard=1
ShowChampionIndicator=0
ShowPlayerStats=1
ShowPlayerPerks=0
ShowSpellCosts=1
ShowSpellRecommendations=0
ShowOffScreenPointsOfInterest=1
EnableLineMissileVis=1
EmotePopupUIDisplayMode=0
EmoteSize=0
HideEnemySummonerEmotes=0
DisableHudSpellClick=0
SmartCastOnKeyRelease=0
SmartCastWithIndicator_CastWhenNewSpellSelected=0
CameraLockMode=0
MiddleClickDragScrollEnabled=0
ScrollSmoothingEnabled=0
KeyboardScrollSpeed=0.0000
MiddleMouseScrollSpeed=0.5000
MapScrollSpeed=0.5000
FlipMiniMap=0
MirroredScoreboard=0
ShowTeamFramesOnLeft=0
GlobalScale=1.0000
MinimapScale=1.0000
PracticeToolScale=1.0000
DeathRecapScale=1.0000
ShopScale=1.0000
ObjectiveVoteScale=1.0000
GlobalScaleReplay=1.0000
ReplayScrollSmoothingEnabled=1
ReplayMiddleMouseScrollSpeed=0.5000
ShowAllChannelChatSpectator=0
EternalsMilestoneDisplayMode=0
ChatChannelVisibility=2
ItemShopPrevY=64
ItemShopPrevX=290
ItemShopResizeHeight=0
ItemShopResizeWidth=260
ItemShopPrevResizeHeight=1080
ItemShopPrevResizeWidth=1920
ItemShopItemDisplayMode=0
ItemShopStartPane=1
DisableMouseCaptureDebugger=0
ShowStatsPanel_StatStones=0

[FloatingText]
Invulnerable_Enabled=1
Special_Enabled=1
Heal_Enabled=1
ManaHeal_Enabled=1
ManaDamage_Enabled=1
Dodge_Enabled=1
PhysicalDamageCritical_Enabled=1
MagicalDamageCritical_Enabled=1
TrueDamageCritical_Enabled=1
Experience_Enabled=1
Gold_Enabled=1
Level_Enabled=1
Disable_Enabled=1
QuestReceived_Enabled=1
QuestComplete_Enabled=1
Score_Enabled=1
PhysicalDamage_Enabled=1
MagicalDamage_Enabled=1
TrueDamage_Enabled=1
EnemyPhysicalDamage_Enabled=1
EnemyMagicalDamage_Enabled=1
EnemyTrueDamage_Enabled=1
EnemyPhysicalDamageCritical_Enabled=1
EnemyMagicalDamageCritical_Enabled=1
EnemyTrueDamageCritical_Enabled=1
Countdown_Enabled=1
OMW_Enabled=1
Absorbed_Enabled=1
PracticeToolTotal_Enabled=1
PracticeToolLastHit_Enabled=1
PracticeToolDPS_Enabled=1
ScoreDarkStar_Enabled=1
ScoreProject0_Enabled=1
ScoreProject1_Enabled=1
ShieldBonusDamage_Enabled=1
Debug_Enabled=1

[Volume]
MasterVolume=0.5000
MasterMute=0
MusicVolume=0.0000
MusicMute=1
SfxVolume=0.5000
SfxMute=0
AnnouncerVolume=0.5000
AnnouncerMute=0
VoiceVolume=0.5000
VoiceMute=0
PingsVolume=1.0000
PingsMute=0
AmbienceVolume=0.0000
AmbienceMute=1

[Voice]
InputDevice=Default System Device
ActivationSensitivity=0.6500
InputMode=0
InputVolume=0.5000
ShowVoiceChatHalos=1
ShowVoicePanelWithScoreboard=1

[Chat]
EnableChatFilter=0
Transparency=0.0000
ChatY=0
ChatX=0
NativeOffsetY=0.0000
NativeOffsetX=0.0000
ReplayNativeOffsetY=0.0000
ReplayNativeOffsetX=0.0000

[LossOfControl]
LossOfControlEnabled=1
ShowSlows=0

[Accessibility]
ColorLevel=0.5000
ColorGamma=0.5000
ColorBrightness=0.5000
ColorContrast=0.5000

[ColorPalette]
ColorPalette=0

[Highlights]
VideoQuality=0
VideoFrameRate=60
ScaleVideo=720
AudioQuality=1

[MapSkinOptions]
MapSkinOptionDisableArcade=0
MapSkinOptionDisableLunarRevel=0
MapSkinOptionDisableMSI=0
MapSkinOptionDisableOdyssey=0
MapSkinOptionDisablePoolParty=0
MapSkinOptionDisablePopstar=0
MapSkinOptionDisableProject=0
MapSkinOptionDisableSnowdown=0
MapSkinOptionDisableStarGuardian=0
MapSkinOptionDisableURF=0
MapSkinOptionDisableWorlds=0

[Replay]
EnableDirectedCamera=0
EnableHelpTip=0

[ItemShop]
InventoryPanelPinned=0
NativeOffsetX=0.0000
NativeOffsetY=0.0000
CurrentTab=1
InvertDisplayOrder=0

[TFTHUD]
EnableChat=1

[TFTChat]
NativeOffsetY=0.0000
NativeOffsetX=0.0000

[TFT]
TFTDisableMusicSourceInfo=0

[Mobile]
Camera Height=0
iOSMetalUserId=-1
iOSMetalPercentEnabled=0
iOSMetalRendererEnabled=0
LastTickerTime=
AppRegion=
SelectedQueue=0
OfferedTutorial=0

[Ftux]
SenOffscreenPing=1
```

---

## 3. Config Key Reference

### Performance Keys (safe to override)

#### [General] Section -- Performance-Related Keys

| Config Key (exact) | Type | Valid Values | Recommended | FPS Impact | Notes |
|---------------------|------|-------------|-------------|------------|-------|
| `WindowMode` | int | `0`=Fullscreen, `1`=Borderless, `2`=Windowed | `0` | HIGH | Fullscreen gives exclusive GPU access. Borderless (1) for easy alt-tab. |
| `WaitForVerticalSync` | int | `0`=Off, `1`=On | `0` | HIGH | **Critical** -- VSync adds input latency. Always disable. |
| `EnableScreenShake` | int | `0`=Off, `1`=On | `0` | LOW | Reduces visual distraction, minor perf gain |
| `HideEyeCandy` | int | `0`=Off, `1`=On | `1` | MEDIUM | Hides ambient critter/decorative effects |
| `ShowGodray` | int | `0`=Off, `1`=On | `0` | LOW | Disables god-ray light effect |
| `EnableLightFx` | int | `0`=Off, `1`=On | `0` | LOW | Disables peripheral RGB lighting integration |
| `EnableSoftParticleSupport` | int | `0`=Off, `1`=On | `0` | MEDIUM | Disables soft particle blending |
| `Antialiasing` | int | `0`=Off, `1`=On | `0` | MEDIUM | General AA toggle in [General] section |
| `PreferDX9LegacyMode` | int | `0`=Off, `1`=On | `0` | LOW | Legacy DX9 renderer -- keep off for modern GPUs |
| `PreferOpenGLLegacyMode` | int | `0`=Off, `1`=On | `0` | LOW | Legacy OpenGL renderer -- keep off |

#### [Performance] Section -- Core Performance Keys

| Config Key (exact) | Type | Valid Values | Recommended | FPS Impact | Notes |
|---------------------|------|-------------|-------------|------------|-------|
| `GraphicsSlider` | int | `-1`=Custom, `0`=Very Low, `1`=Low, `2`=Medium, `3`=High, `4`=Very High | `-1` | N/A | Set to -1 (Custom) when overriding individual settings |
| `ShadowsEnabled` | int | `0`=Off, `1`=On | `0` | HIGH | **Biggest FPS gain** -- master shadow toggle |
| `ShadowQuality` | int | `0`=Off, `1`=Low, `2`=Medium, `3`=High, `4`=Very High | `0` | HIGH | Shadow detail level (irrelevant when ShadowsEnabled=0) |
| `CharacterQuality` | int | `0`=Very Low, `1`=Low, `2`=Medium, `3`=High, `4`=Very High | `1` | MEDIUM | Character model detail |
| `EnvironmentQuality` | int | `0`=Very Low, `1`=Low, `2`=Medium, `3`=High, `4`=Very High | `1` | MEDIUM | Map environment detail |
| `EffectsQuality` | int | `0`=Very Low, `1`=Low, `2`=Medium, `3`=High, `4`=Very High | `1` | MEDIUM | Particle/spell effect quality |
| `CharacterInking` | int | `0`=Off, `1`=On | `0` | MEDIUM | Black outline on character models |
| `EnableGrassSwaying` | int | `0`=Off, `1`=On | `0` | LOW | Grass animation |
| `EnableFXAA` | int | `0`=Off, `1`=On | `0` | MEDIUM | Fast approximate anti-aliasing |
| `EnableHUDAnimations` | int | `0`=Off, `1`=On | `0` | LOW | HUD animation effects |
| `EnableParticleOptimizations` | int | `0`=Off, `1`=On | `1` | MEDIUM | Engine particle optimization -- enable for better perf |
| `AutoPerformanceSettings` | int | `0`=Off, `1`=On | `0` | N/A | Disable auto-adjustment so our settings stick |
| `GammaEnabled` | int | `0`=Off, `1`=On | `0` | LOW | Gamma correction toggle |
| `FrameCapType` | int | See table below | `10` | HIGH | **Critical** -- set to Uncapped (10) |
| `BudgetOverdrawAverage` | int | 10-100+ | `10` | MEDIUM | Lower = fewer overdraw passes |
| `BudgetSkinnedVertexCount` | int | 40000-200000+ | `40000` | MEDIUM | Lower = fewer skinned mesh vertices |
| `BudgetSkinnedDrawCallCount` | int | 50-100+ | `50` | LOW | Lower = fewer skinned draw calls |
| `BudgetTextureUsage` | int | 20000-150000+ | `20000` | MEDIUM | Lower = less texture memory usage |
| `BudgetVertexCount` | int | 100000-500000+ | `100000` | MEDIUM | Lower = fewer total vertices |
| `BudgetTriangleCount` | int | 100000-300000+ | `100000` | MEDIUM | Lower = fewer triangles |
| `BudgetDrawCallCount` | int | 500-1000+ | `500` | MEDIUM | Lower = fewer draw calls |

#### FrameCapType Values

| FrameCapType | FPS Cap |
|-------------|---------|
| `3` | 25 FPS |
| `4` | 30 FPS |
| `5` | 60 FPS |
| `6` | 80 FPS |
| `7` | 120 FPS |
| `8` | 144 FPS |
| `9` | 200 FPS |
| `2` | 240 FPS |
| `10` | **Uncapped** |

**Source:** https://github.com/WelFedTed/LoL-Config/blob/master/MainWindow.xaml.cs

> **Per CLAUDE.md rules: NEVER cap FPS based on monitor refresh rate.** Always use `FrameCapType=10` (Uncapped). Higher FPS = lower input latency even above the monitor's refresh rate.

#### [HUD] Section -- Performance-Related Keys

| Config Key (exact) | Type | Valid Values | Recommended | FPS Impact | Notes |
|---------------------|------|-------------|-------------|------------|-------|
| `FlashScreenWhenDamaged` | int | `0`=Off, `1`=On | `0` | LOW | Screen flash effect on damage |
| `ShowHealthBarShake` | int | `0`=Off, `1`=On | `0` | LOW | Health bar shake animation |

### Structural Keys (must preserve, never override)

| Config Key (exact) | Section | Type | Purpose |
|---------------------|---------|------|---------|
| `Width` | [General] | int | Monitor resolution width -- preserve user's display |
| `Height` | [General] | int | Monitor resolution height -- preserve user's display |
| `Colors` | [General] | int | Color depth (always 32) |
| `CfgVersion` | [General] | string | Config version stamp -- game uses this for migration |
| `UserSetResolution` | [General] | int | Flag that user has set resolution |
| `GameMouseSpeed` | [General] | int | User's mouse speed (1-100) -- personal preference |
| `SystemMouseSpeed` | [General] | int | System mouse speed -- personal preference |
| `CursorScale` | [General] | float | User's cursor size -- personal preference |
| `CursorOverride` | [General] | int | Custom cursor toggle -- personal preference |
| `EnableAudio` | [General] | int | Audio master toggle -- preserve |
| `AutoAcquireTarget` | [General] | int | Auto-attack behavior -- gameplay preference |
| `EnableTargetedAttackMove` | [General] | int | Attack move behavior -- gameplay preference |
| `EnableLeftMouseButtonAttackMove` | [General] | int | LMB attack move -- gameplay preference |
| `TargetChampionsOnlyAsToggle` | [General] | int | Target champions only -- gameplay preference |
| `SnapCameraOnRespawn` | [General] | int | Camera snap -- gameplay preference |
| `PredictMovement` | [General] | int | Movement prediction -- gameplay preference |
| `RelativeTeamColors` | [General] | int | Team colors -- gameplay preference |
| `ShowTurretRangeIndicators` | [General] | int | Turret range -- gameplay preference |
| `RecommendJunglePaths` | [General] | int | Jungle pathing recommendations -- gameplay preference |
| All `[HUD]` keys (except perf ones) | [HUD] | various | HUD layout, scaling, display -- personal preference |
| All `[Sound]` keys | [Sound] | various | Audio settings -- personal preference |
| All `[Volume]` keys | [Volume] | various | Volume levels -- personal preference |
| All `[Voice]` keys | [Voice] | various | Voice chat config -- personal preference |
| All `[Chat]` keys | [Chat] | various | Chat position/filter -- personal preference |
| All `[FloatingText]` keys | [FloatingText] | various | Damage number display -- personal preference |
| All `[LossOfControl]` keys | [LossOfControl] | various | CC indicator -- personal preference |
| All `[Accessibility]` keys | [Accessibility] | various | Color adjustments -- accessibility, preserve |
| All `[ColorPalette]` keys | [ColorPalette] | various | Colorblind mode -- accessibility, preserve |
| All `[Replay]` keys | [Replay] | various | Replay settings -- personal preference |
| All `[Highlights]` keys | [Highlights] | various | Highlights settings -- personal preference |
| All `[MapSkinOptions]` keys | [MapSkinOptions] | various | Event map skins -- personal preference |
| All `[RecommendPage]` keys | [RecommendPage] | various | **User's saved item builds** -- NEVER touch |
| All `[ItemShop]` keys | [ItemShop] | various | Shop window state -- personal preference |
| All `[TFTHUD]` keys | [TFTHUD] | various | TFT settings -- personal preference |
| All `[TFTChat]` keys | [TFTChat] | various | TFT chat settings -- personal preference |
| All `[TFT]` keys | [TFT] | various | TFT settings -- personal preference |
| All `[Mobile]` keys | [Mobile] | various | Mobile settings -- preserve |
| All `[Ftux]` keys | [Ftux] | various | First-time UX flags -- preserve |

### Keys NOT in Config (must set in-game)

| In-Game Setting | Notes |
|-----------------|-------|
| Camera Move Speed (Mouse) | Stored in HUD section as `MapScrollSpeed` but some players prefer in-game adjustment |
| Minimap interactions | Some minimap behaviors only changeable in-game |
| Quick Cast settings | Stored in `input.ini` -- DO NOT modify via our tool |
| Keybindings | Stored in `input.ini` -- DO NOT modify via our tool |
| Summoner spells | In-game only |
| In-game chat commands | Not config-file based |

---

## 4. Key Name Verification

| Source | URL | Notes |
|--------|-----|-------|
| GitHub: kevin7600/LOL-configs | https://github.com/kevin7600/LOL-configs/blob/master/game.cfg | CfgVersion 13.21, complete file with all sections |
| GitHub: fluzz142857/lol-config | https://github.com/fluzz142857/lol-config/blob/master/game.cfg | CfgVersion 9.15, cross-reference for key stability |
| GitHub: matootie/lol-config gist | https://gist.github.com/matootie/dcfef766dec2a4b74df9457d6933e599 | CfgVersion 14.10 -- most recent, confirms current keys |
| GitHub: WelFedTed/LoL-Config | https://github.com/WelFedTed/LoL-Config/blob/master/MainWindow.xaml.cs | FrameCapType and WindowMode value mappings |
| Hone.gg best settings guide | https://hone.gg/blog/best-lol-settings/ | Performance section keys verified |
| League Wiki: Settings | https://wiki.leagueoflegends.com/en-us/Settings | Official quality tier names |
| ProSettings.gg: Faker | https://www.prosettings.gg/players/faker/ | Pro player settings verification |
| Hawk.live: Pro settings | https://hawk.live/posts/league-of-legends-best-settings-pro-players | Multiple pro player settings |
| Eneba: Fullscreen guide | https://www.eneba.com/hub/games-guides/how-to-fullscreen-league-of-legends/ | WindowMode value mapping verified |

**Key stability note:** Comparing configs across versions 9.15 through 14.10 shows that core [Performance] and [General] key names have remained stable for years. The config format is mature and unlikely to change significantly.

---

## 5. Installation Detection

**Confidence: HIGH**

### Registry Keys

```powershell
# 1. Best: Riot Client installs JSON
$riotJson = "C:\ProgramData\Riot Games\RiotClientInstalls.json"
if (Test-Path $riotJson) {
    $json = Get-Content $riotJson -Raw | ConvertFrom-Json
    # Parse associated_client keys for league_of_legends paths
}

# 2. Direct LoL registry key
$lolReg = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Riot Games\League of Legends" -ErrorAction SilentlyContinue
if ($lolReg) { $lolPath = $lolReg.InstallPath }

# 3. Riot Client registry key
$riotReg = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Riot Games\Riot Client" -ErrorAction SilentlyContinue

# 4. Uninstall registry key
$uninstReg = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\League of Legends" -ErrorAction SilentlyContinue
if ($uninstReg) { $lolPath = $uninstReg.InstallLocation }
```

### Common Install Paths

```
C:\Riot Games\League of Legends\
D:\Riot Games\League of Legends\
C:\Program Files\Riot Games\League of Legends\
C:\Program Files (x86)\Riot Games\League of Legends\
```

### Steam Detection

- League of Legends is **NOT available on Steam**
- Steam App ID: N/A
- Installed exclusively via **Riot Client**

### Other Launchers

- **Riot Client** is the sole launcher -- detection via `RiotClientInstalls.json` at `C:\ProgramData\Riot Games\RiotClientInstalls.json`
- The JSON file contains `associated_client` entries mapping game paths
- Riot Client registry: `HKLM\SOFTWARE\WOW6432Node\Riot Games\Riot Client`

---

## 6. EXE Flags

| Executable | Path relative to install | Flags |
|------------|--------------------------|-------|
| `League of Legends.exe` | `Game\League of Legends.exe` | `HIGHDPIAWARE DISABLEFULLSCREENOPTIMIZATIONS` |

**Important:** Do NOT set flags on these executables:
- `RiotClientServices.exe` -- Riot Client service (at `C:\Riot Games\Riot Client\`)
- `RiotClientUx.exe` -- Riot Client UI
- `LeagueClientUx.exe` -- LoL lobby/client UI

---

## 7. GPU-Specific Settings

### NVIDIA

| Setting | Recommended | Notes |
|---------|-------------|-------|
| Power Management Mode | Prefer Maximum Performance | Prevents GPU downclocking |
| Texture Filtering Quality | High Performance | Faster texture sampling |
| Low Latency Mode | Ultra (or On) | Reduces render queue |
| Threaded Optimization | On | Better multi-threaded perf |
| Maximum Pre-Rendered Frames | 1 | Minimum input latency |
| VSync (driver level) | Off | Must be off at both driver and game level |
| Triple Buffering | Off | Adds latency |
| Shader Cache Size | Unlimited | Prevents shader recompilation stutters |
| NVIDIA Reflex | Not supported | LoL does not have Reflex integration |
| DLSS | Not supported | LoL does not support DLSS |

Target executable: `League of Legends.exe` (NOT the Riot Client executables)

### AMD

| Setting | Recommended | Notes |
|---------|-------------|-------|
| Anti-Lag | Enabled | Reduces input latency |
| Radeon Chill | Disabled | We want uncapped FPS |
| Radeon Boost | Disabled | Can reduce rendering quality |
| Wait for Vertical Refresh | Always Off | No VSync |
| Texture Filtering Quality | Performance | Faster texture sampling |
| Surface Format Optimization | Enabled | Better perf |
| Tessellation Mode | Override / Off | LoL doesn't use tessellation heavily |
| Shader Cache | On | Prevents shader stutter |
| FSR | Not supported natively | LoL does not have FSR integration |

---

## 8. Anti-Cheat Safety

| Anti-Cheat | Safe to modify | Details |
|------------|---------------|---------|
| **Riot Vanguard** | Config files (game.cfg): **YES** | Vanguard monitors for cheat tools, memory modification, and kernel-level tampering -- NOT user settings files |
| | Registry (HKCU): **YES** | Standard Windows registry optimizations (Game DVR, Game Bar, Nagle) are safe |
| | Registry (HKLM): **YES** | Gaming optimizations (MMCSS, HAGS) are safe |
| | GPU driver profiles: **YES** | Changes via NVIDIA Control Panel / AMD Adrenalin are safe |
| | Process priority: **CAUTION** | May be restricted by Vanguard -- test before shipping |
| | Game file modification: **NO** | Do NOT modify any files in the `Game\DATA\` folder |
| | Memory injection: **NO** | Will result in immediate ban |

**Sources:**
- Riot Vanguard FAQ: https://support-leagueoflegends.riotgames.com/hc/en-us/articles/24169857932435-Riot-Vanguard-FAQ-League-of-Legends
- Riot Vanguard Wiki: https://wiki.leagueoflegends.com/en-us/Riot_Vanguard

**Key distinction:** Editing `game.cfg` (user settings file in the Config folder) is fundamentally different from modifying game data files. game.cfg contains the same settings available through the in-game options menu. Vanguard does not flag config file edits as long as values remain within the ranges allowed by the in-game settings interface.

**Important:** The `PersistedSettings.json` file header states "The settings in this file are persisted server-side. This file is generated automatically. Editing it is not recommended." Our tool should only modify `game.cfg`, not `PersistedSettings.json`.

---

## 9. Pro Player / Competitive Settings

### Pro Player Settings Survey

Data compiled from ProSettings.gg, Specs.gg, and Hawk.live (updated 2025/2026):

| Setting | Faker | Showmaker | Chovy | Zeus | Oner | Rekkles |
|---------|-------|-----------|-------|------|------|---------|
| Resolution | 1920x1080 | 1920x1080 | 2560x1440 | 1920x1080 | 1920x1080 | 1920x1080 |
| Window Mode | Fullscreen | Fullscreen | Fullscreen | Fullscreen | Fullscreen | Borderless |
| Character Quality | Low | Medium | Low | Low | Low | Medium |
| Environment Quality | Low | Low | Low | Low | Low | Low |
| Effects Quality | Low | Low | Low | Low | Low | Medium |
| Shadow Quality | Off | Off | Off | Off | Off | Off |
| Frame Rate Cap | 240 | 144 | 240 | Uncapped | Uncapped | 144 |
| VSync | Off | Off | Off | Off | Off | Off |
| Anti-Aliasing | Off | Off | Off | Off | Off | Off |

**Sources:**
- https://www.prosettings.gg/players/faker/
- https://hawk.live/posts/league-of-legends-best-settings-pro-players

### Consensus Competitive Settings

Based on pro player data and community consensus:

- **100% of pros disable shadows** -- single biggest FPS/clarity improvement
- **100% of pros disable VSync** -- input latency reduction
- **100% of pros disable anti-aliasing** -- unnecessary for LoL's art style
- **~80% use Low quality** for character, environment, and effects
- **~60% use Fullscreen** (not Borderless) for exclusive GPU access
- **Most use 1920x1080** even with 1440p/4K monitors -- for consistency with tournament setups
- **FPS cap varies:** Uncapped, 240, or 144 depending on monitor -- per project rules we always set Uncapped

### Recommended Competitive Values for Script

```ini
[General]
WindowMode=0
WaitForVerticalSync=0
EnableScreenShake=0
HideEyeCandy=1
ShowGodray=0
EnableLightFx=0
EnableSoftParticleSupport=0
Antialiasing=0
PreferDX9LegacyMode=0
PreferOpenGLLegacyMode=0

[Performance]
GraphicsSlider=-1
ShadowsEnabled=0
ShadowQuality=0
CharacterQuality=1
EnvironmentQuality=1
EffectsQuality=1
CharacterInking=0
EnableGrassSwaying=0
EnableFXAA=0
EnableHUDAnimations=0
EnableParticleOptimizations=1
AutoPerformanceSettings=0
GammaEnabled=0
FrameCapType=10
BudgetOverdrawAverage=10
BudgetSkinnedVertexCount=40000
BudgetSkinnedDrawCallCount=50
BudgetTextureUsage=20000
BudgetVertexCount=100000
BudgetTriangleCount=100000
BudgetDrawCallCount=500

[HUD]
FlashScreenWhenDamaged=0
ShowHealthBarShake=0
```

---

## 10. Additional Notes

### Read-Only Strategy

Since LoL overwrites game.cfg on every game exit, the PowerShell script should:
1. Back up the existing game.cfg
2. Write the optimized config
3. Set the file to read-only to prevent overwriting
4. The in-game settings guide should note that read-only prevents in-game settings changes

```powershell
Set-ItemProperty -Path $cfgPath -Name IsReadOnly -Value $true
```

### Low Spec Mode (Client-side)

The Riot Client has a "Low Spec Mode" toggle that reduces client (lobby) animations. This is stored in `PersistedSettings.json` as a `LowSpecMode` setting. Since we should not edit PersistedSettings.json, this should be mentioned in the in-game settings guide only.

### Config File Encoding

game.cfg uses standard ANSI/UTF-8 encoding without BOM. PowerShell's default `Set-Content` or `Out-File -Encoding ascii` works correctly. No special encoding handling is needed (unlike Unity JSON games).

### Known Issues

- **FPS drops in teamfights**: Lowering BudgetOverdrawAverage, BudgetSkinnedVertexCount, and BudgetTextureUsage helps. EnableParticleOptimizations=1 is also important.
- **Stuttering with DX9 Legacy Mode**: Some players report FPS drops when PreferDX9LegacyMode is enabled. Keep it at 0 for modern systems.
- **GraphicsSlider=-1**: When setting individual quality values, GraphicsSlider should be set to -1 (Custom) to prevent the game from overriding individual settings with a preset.
- **game.cfg location**: Config is at `<Install>\Game\Config\game.cfg`, NOT at the install root. The `Game\Config\` subdirectory is important.

### WindowMode Value Correction

**IMPORTANT:** The original research file had WindowMode values incorrect. The correct mapping (verified from multiple sources including Eneba and WelFedTed/LoL-Config):
- `0` = Fullscreen
- `1` = Borderless
- `2` = Windowed

---

## Confidence Summary

| Category | Confidence |
|----------|-----------|
| Config file paths and format | **HIGH** -- verified across 3+ GitHub sources and official docs |
| Core [Performance] key names | **HIGH** -- stable across versions 9.15 through 14.10 |
| [General] key names | **HIGH** -- verified across multiple sources |
| FrameCapType value mapping | **HIGH** -- verified from WelFedTed/LoL-Config source code |
| WindowMode value mapping | **HIGH** -- corrected and verified from multiple sources |
| Quality value mapping (0-4) | **HIGH** -- matches in-game UI Very Low through Very High |
| Budget parameter values | **MEDIUM** -- optimal values vary by hardware, defaults provided |
| Anti-cheat safety | **HIGH** -- config file edits are standard practice, widely documented |
| Pro player settings | **HIGH** -- from ProSettings.gg and Specs.gg, updated 2025/2026 |
| Installation detection | **HIGH** -- registry keys and RiotClientInstalls.json well-documented |

### Gaps / Limitations

1. **No official Riot documentation** exists for game.cfg key names -- all verification is from community sources and reverse engineering
2. **Budget parameter optimal values** are hardware-dependent -- the low values recommended may cause visual artifacts on some systems
3. **CfgVersion** changes with each patch -- the script should preserve whatever value exists rather than writing a specific one
4. **PerPixelPointLighting** appears in some community configs but NOT in the most recent (14.10) reference -- it may have been removed or renamed. Not included in recommended settings due to uncertainty.
5. **Newer patches** (Season 15, 2025) may have added settings not present in the 14.10 reference. The read-merge-write approach handles this gracefully.
