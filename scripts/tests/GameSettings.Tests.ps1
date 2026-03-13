<#
.SYNOPSIS
    Pester 5 tests for game optimization scripts.
    Validates that each script produces config files matching the expected format.

.DESCRIPTION
    Run with:  Invoke-Pester scripts/tests/GameSettings.Tests.ps1
    Tag filter: Invoke-Pester scripts/tests/GameSettings.Tests.ps1 -Tag 'tarkov'

    Each test:
    1. Creates a temp sandbox with simulated %APPDATA%
    2. Optionally seeds it with the reference config (to test read-merge-write)
    3. Runs the script headless, capturing stdout
    4. Validates the output config file

    IMPORTANT: Pester 5 runs top-level code during discovery (not execution).
    All path resolution and setup must be inside BeforeAll blocks.
#>

# ===========================================================================
# TARKOV TESTS
# ===========================================================================
Describe "Tarkov Graphics.ini" -Tag "tarkov" {

    BeforeAll {
        # Resolve paths inside BeforeAll — Pester 5 only runs this during execution
        $ProjectRoot = (Get-Location).Path
        $ScriptsDir = Join-Path $ProjectRoot "scripts"
        $ReferenceDir = Join-Path $ScriptsDir "reference-configs"
        $RefFile = Join-Path $ReferenceDir "tarkov-Graphics.ini"

        # Helper: Check if a file starts with UTF-8 BOM (EF BB BF)
        function Test-HasBOM {
            param([string]$Path)
            $bytes = [System.IO.File]::ReadAllBytes($Path)
            return ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        }

        # Load reference config key names
        $raw = [System.IO.File]::ReadAllText($RefFile, [System.Text.UTF8Encoding]::new($false))
        $RefConfig = $raw | ConvertFrom-Json
        $RefKeys = $RefConfig.PSObject.Properties.Name
    }

    Context "Reference config is valid" {
        It "Reference file exists" {
            $RefFile | Should -Exist
        }

        It "Reference file is valid JSON" {
            { [System.IO.File]::ReadAllText($RefFile, [System.Text.UTF8Encoding]::new($false)) | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Reference has structural envelope (Version, Stored, DisplaySettings)" {
            $RefKeys | Should -Contain "Version"
            $RefKeys | Should -Contain "Stored"
            $RefKeys | Should -Contain "DisplaySettings"
        }
    }

    Context "Script competitive settings use valid key names" {
        BeforeAll {
            # Extract the competitive settings keys from the script source
            $scriptContent = Get-Content (Join-Path $ScriptsDir "14_Tarkov_Settings.ps1") -Raw
            # Match lines like:  ShadowsQuality       = [int]0
            $ScriptKeys = [regex]::Matches($scriptContent, '(?m)^\s+(\w+)\s+=\s+\[?') |
                ForEach-Object { $_.Groups[1].Value } |
                Where-Object { $_ -notin @('competitiveSettings', 'aspect', 'config', 'Version',
                    'Stored', 'DisplaySettings', 'GraphicsQuality', 'Index',
                    'FullScreenResolution', 'FullScreenAspectRatio', 'WindowResolution',
                    'WindowAspectRatio', 'Display', 'FullScreenMode', 'Resolution',
                    'AspectRatio', 'Width', 'Height', 'X', 'Y') } |
                Select-Object -Unique
        }

        It "All competitive setting keys exist in the reference config" {
            $missingKeys = @()
            foreach ($key in $ScriptKeys) {
                if ($key -notin $RefKeys) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These keys are not in the reference config: $($missingKeys -join ', ')"
        }
    }

    Context "Script output file format" {
        BeforeAll {
            # Create a temp sandbox
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "sq-test-tarkov-$(Get-Random)"
            $settingsDir = Join-Path $script:TempDir "Battlestate Games\Escape from Tarkov\Settings"
            New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null

            # Seed with reference config to test read-merge-write
            Copy-Item $RefFile (Join-Path $settingsDir "Graphics.ini") -Force

            # Save original APPDATA
            $script:OrigAppData = $env:APPDATA

            # Run the script in headless mode with overridden APPDATA
            $env:SENSEQUALITY_HEADLESS = "1"
            $env:MONITOR_WIDTH = "1920"
            $env:MONITOR_HEIGHT = "1080"
            $env:MONITOR_REFRESH = "240"
            $env:NVIDIA_GPU = "1"
            $env:APPDATA = $script:TempDir

            $scriptPath = Join-Path $ScriptsDir "14_Tarkov_Settings.ps1"
            # *>&1 captures all streams including Write-Host (stream 6)
            $Output = & $scriptPath *>&1 | Out-String
            $OutputFile = Join-Path $settingsDir "Graphics.ini"
        }

        AfterAll {
            # Restore APPDATA and clean up
            $env:APPDATA = $script:OrigAppData
            $env:SENSEQUALITY_HEADLESS = ""
            if ($script:TempDir -and (Test-Path $script:TempDir)) {
                Get-ChildItem $script:TempDir -Recurse -File -ErrorAction SilentlyContinue |
                    ForEach-Object { if ($_.IsReadOnly) { $_.IsReadOnly = $false } }
                Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Output file exists" {
            $OutputFile | Should -Exist
        }

        It "Output file has no UTF-8 BOM" {
            Test-HasBOM $OutputFile | Should -BeFalse -Because "Unity JSON parser rejects BOM"
        }

        It "Output file is valid JSON" {
            {
                [System.IO.File]::ReadAllText($OutputFile, [System.Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
            } | Should -Not -Throw
        }

        It "Output has structural envelope (Version, Stored, DisplaySettings)" {
            $raw = [System.IO.File]::ReadAllText($OutputFile, [System.Text.UTF8Encoding]::new($false))
            $obj = $raw | ConvertFrom-Json
            $keys = $obj.PSObject.Properties.Name
            $keys | Should -Contain "Version"
            $keys | Should -Contain "Stored"
            $keys | Should -Contain "DisplaySettings"
        }

        It "SQ_CHECK markers are emitted for config write" {
            $Output | Should -Match '\[SQ_CHECK_(OK|WARN|FAIL):TARKOV_CONFIG_WRITTEN'
        }

        It "String-typed settings remain strings (not converted to ints)" {
            $raw = [System.IO.File]::ReadAllText($OutputFile, [System.Text.UTF8Encoding]::new($false))
            $obj = $raw | ConvertFrom-Json
            $obj.AntiAliasing | Should -BeOfType [string]
            $obj.SSR | Should -BeOfType [string]
            $obj.Ssao | Should -BeOfType [string]
            $obj.AnisotropicFiltering | Should -BeOfType [string]
        }
    }
}

# ===========================================================================
# RUST TESTS
# ===========================================================================
Describe "Rust client.cfg" -Tag "rust" {

    BeforeAll {
        $ProjectRoot = (Get-Location).Path
        $ScriptsDir = Join-Path $ProjectRoot "scripts"
        $ReferenceDir = Join-Path $ScriptsDir "reference-configs"
        $RefFile = Join-Path $ReferenceDir "rust-client.cfg"
    }

    Context "Reference config is valid" {
        It "Reference file exists" {
            $RefFile | Should -Exist
        }

        It "Reference file uses convar format" {
            $lines = Get-Content $RefFile | Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*//' }
            foreach ($line in $lines) {
                $line | Should -Match '^\S+\s+".*"$' -Because "Each line should be: convar `"value`""
            }
        }
    }

    Context "Script competitive settings use valid convar names" {
        BeforeAll {
            # Load reference convars
            $refLines = Get-Content $RefFile | Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*//' }
            $RefConvars = $refLines | ForEach-Object { ($_ -split '\s+')[0] }

            # Extract convars from the script
            $scriptContent = Get-Content (Join-Path $ScriptsDir "15_Rust_Settings.ps1") -Raw
            $ScriptConvars = [regex]::Matches($scriptContent, '[''"](\w+\.\w+)[''"]') |
                ForEach-Object { $_.Groups[1].Value } |
                Select-Object -Unique
        }

        It "All script convars exist in reference config" {
            $missingKeys = @()
            foreach ($cv in $ScriptConvars) {
                if ($cv -notin $RefConvars) {
                    $missingKeys += $cv
                }
            }
            # Allow up to 5 new keys that may come from newer Rust versions
            $missingKeys.Count | Should -BeLessOrEqual 5 -Because "Too many unknown convars: $($missingKeys -join ', ')"
        }
    }
}

# ===========================================================================
# RAINBOW SIX SIEGE TESTS
# ===========================================================================
Describe "R6 Siege GameSettings.ini" -Tag "r6siege" {

    BeforeAll {
        $ProjectRoot = (Get-Location).Path
        $ScriptsDir = Join-Path $ProjectRoot "scripts"
        $ReferenceDir = Join-Path $ScriptsDir "reference-configs"
        $RefFile = Join-Path $ReferenceDir "r6siege-GameSettings.ini"
    }

    Context "Reference config is valid" {
        It "Reference file exists" {
            $RefFile | Should -Exist
        }

        It "Reference file has INI sections" {
            $content = Get-Content $RefFile -Raw
            $content | Should -Match '\[DISPLAY\]'
            $content | Should -Match '\[GRAPHICS\]'
        }
    }

    Context "Script uses valid key names" {
        BeforeAll {
            # Parse reference INI keys per section
            $RefSections = @{}
            $currentSection = ""
            foreach ($line in (Get-Content $RefFile)) {
                if ($line -match '^\[(.+)\]$') {
                    $currentSection = $Matches[1]
                    $RefSections[$currentSection] = @()
                } elseif ($currentSection -and $line -match '^(.+?)=') {
                    $RefSections[$currentSection] += $Matches[1]
                }
            }
        }

        It "DISPLAY section has required keys" {
            $RefSections["DISPLAY"] | Should -Contain "WindowMode"
            $RefSections["DISPLAY"] | Should -Contain "VSync"
            $RefSections["DISPLAY"] | Should -Contain "FPSLimit"
            $RefSections["DISPLAY"] | Should -Contain "Resolution"
        }

        It "GRAPHICS section has required keys" {
            $RefSections["GRAPHICS"] | Should -Contain "TextureQuality"
            $RefSections["GRAPHICS"] | Should -Contain "ShadowQuality"
            $RefSections["GRAPHICS"] | Should -Contain "AntiAliasingMode"
        }
    }
}

# ===========================================================================
# COD BLACK OPS 7 TESTS
# ===========================================================================
Describe "COD Black Ops 7 template configs" -Tag "cod" {

    BeforeAll {
        $ProjectRoot = (Get-Location).Path
        $ScriptsDir  = Join-Path $ProjectRoot "scripts"
        $BackupDir   = Join-Path $ScriptsDir  "BO7BACKUP"
        $RefDir      = Join-Path $ScriptsDir  "reference-configs"
        $RefFile     = Join-Path $RefDir      "cod-s.1.0.cod25.txt0"
        $Txt0        = Join-Path $BackupDir   "s.1.0.cod25.txt0"
        $Txt1        = Join-Path $BackupDir   "s.1.0.cod25.txt1"
        $DotM        = Join-Path $BackupDir   "s.1.0.cod25.m"
        $ScriptFile  = Join-Path $ScriptsDir  "02_BlackOps7_Settings.ps1"

        # Helper: parse COD config lines into a hashtable of KeyBase -> value
        # Lines look like:  KeyName@scope;hash1;hash2 = value // comment
        # Keys with duplicate base names (e.g. DxrMode@0 and DxrMode@1)
        # are stored as KeyBase@scope -- first occurrence wins for value checks.
        function Parse-CodConfig {
            param([string]$Path)
            $result = [ordered]@{}
            foreach ($line in (Get-Content $Path)) {
                if ($line -match '^(\w+@[\d;]+)\s+=\s+(.+?)(\s+//.+)?$') {
                    $fullKey = $Matches[1]
                    $value   = $Matches[2].Trim()
                    $baseKey = ($fullKey -split '@')[0]
                    # Store full-keyed entry; also store base-keyed entry (first wins)
                    $result[$fullKey] = $value
                    if (-not $result.Contains($baseKey)) {
                        $result[$baseKey] = $value
                    }
                }
            }
            return $result
        }
    }

    # -----------------------------------------------------------------
    Context "Reference config is valid" {
        It "Reference file exists" {
            $RefFile | Should -Exist
        }

        It "Reference file uses COD config line format" {
            $dataLines = Get-Content $RefFile |
                Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*//' -and $_ -notmatch '^\d+$' }
            $dataLines.Count | Should -BeGreaterThan 0 -Because "Should have data lines"
            foreach ($line in $dataLines) {
                $line | Should -Match '^\w+@[\d;]+\s+=\s+' -Because "Each data line should match: Key@scope;h1;h2 = value"
            }
        }

        It "Reference file contains all expected config sections" {
            $content = Get-Content $RefFile -Raw
            $content | Should -Match '// Audio'
            $content | Should -Match '// Display'
            $content | Should -Match '// Graphics'
            $content | Should -Match '// Gameplay'
            $content | Should -Match '// Interface'
            $content | Should -Match '// Mouse and Gamepad'
            $content | Should -Match '// System'
        }
    }

    # -----------------------------------------------------------------
    Context "Template file integrity" {
        It "txt0 template exists" {
            $Txt0 | Should -Exist
        }

        It "txt1 template exists" {
            $Txt1 | Should -Exist
        }

        It ".m template exists" {
            $DotM | Should -Exist
        }

        It "txt0 and txt1 are byte-identical" {
            $hash0 = (Get-FileHash $Txt0 -Algorithm SHA256).Hash
            $hash1 = (Get-FileHash $Txt1 -Algorithm SHA256).Hash
            $hash0 | Should -Be $hash1 -Because "Both profile templates must contain identical optimized settings"
        }

        It ".m file is exactly 2 bytes" {
            (Get-Item $DotM).Length | Should -Be 2
        }

        It "txt0 matches the reference config" {
            $hashTxt0 = (Get-FileHash $Txt0 -Algorithm SHA256).Hash
            $hashRef  = (Get-FileHash $RefFile -Algorithm SHA256).Hash
            $hashTxt0 | Should -Be $hashRef -Because "BO7BACKUP template must match the reference config"
        }

        It "txt0 has no UTF-8 BOM" {
            $bytes = [System.IO.File]::ReadAllBytes($Txt0)
            $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
            $hasBom | Should -BeFalse -Because "COD config parser may reject BOM"
        }

        It "txt0 starts with version number on line 1" {
            $firstLine = (Get-Content $Txt0 -TotalCount 1)
            $firstLine | Should -Match '^\d+$' -Because "First line must be the config version number"
        }
    }

    # -----------------------------------------------------------------
    Context "Competitive settings values" {
        BeforeAll {
            $Settings = Parse-CodConfig -Path $RefFile
        }

        # -- Display --
        It "VSync is disabled" {
            $Settings['VSync'] | Should -Be 'disabled'
        }

        It "DisplayMode is Fullscreen" {
            $Settings['DisplayMode'] | Should -Be 'Fullscreen'
        }

        It "Render resolution is 100 percent" {
            $Settings['ResolutionMultiplier'] | Should -Be '100'
        }

        It "Nvidia Reflex is Enabled" {
            $Settings['NvidiaReflex'] | Should -Be 'Enabled'
        }

        # -- Gameplay --
        It "Depth of Field is off" {
            $Settings['DepthOfField'] | Should -Be 'false'
        }

        It "Motion blur is off" {
            $Settings['EnableVelocityBasedBlur'] | Should -Be 'false'
        }

        It "Custom FPS cap is off (uncapped)" {
            $Settings['CapFps'] | Should -Be 'false'
        }

        # -- Graphics quality --
        It "Shadow quality is Very_Low" {
            $Settings['ShadowQuality'] | Should -Be 'Very_Low'
        }

        It "Screen Space Shadows are Off" {
            $Settings['ScreenSpaceShadowQuality'] | Should -Be 'Off'
        }

        It "SSR quality is Off" {
            $Settings['SSRQuality'] | Should -Be 'Off'
        }

        It "Ambient lighting is Off" {
            $Settings['AmbientLightingQuality'] | Should -Be 'Off'
        }

        It "Weather grid volumes are Off" {
            $Settings['WeatherGridVolumesQuality'] | Should -Be 'Off'
        }

        It "Shader quality is Low" {
            $Settings['ShaderQuality'] | Should -Be 'Low'
        }

        It "Particle quality is very low" {
            $Settings['ParticleQuality'] | Should -Be 'very low'
        }

        It "Volumetric quality is QUALITY_LOW" {
            $Settings['VolumetricQuality'] | Should -Be 'QUALITY_LOW'
        }

        It "Texture quality is 3 (lowest)" {
            $Settings['TextureQuality'] | Should -Be '3'
        }

        It "Texture filter is aniso 2x" {
            $Settings['TextureFilter'] | Should -Be 'aniso 2x'
        }

        It "Tessellation is off" {
            $Settings['Tessellation'] | Should -Be '0_Off'
        }

        It "Water caustics are Off" {
            $Settings['WaterCausticsMode'] | Should -Be 'Off'
        }

        It "Water wave wetness is off" {
            $Settings['WaterWaveWetness'] | Should -Be 'false'
        }

        It "VRS is enabled (free performance)" {
            $Settings['VRS'] | Should -Be 'true'
        }

        It "DXR raytracing is Off" {
            $Settings['DxrMode'] | Should -Be 'Off'
        }

        It "Dynamic scene resolution is off" {
            $Settings['DynamicSceneResolution'] | Should -Be 'false'
        }

        It "DLSS Frame Generation is off" {
            $Settings['DLSSFrameGeneration'] | Should -Be 'false'
        }

        It "FSR Frame Interpolation is off" {
            $Settings['FSRFrameInterpolation'] | Should -Be 'false'
        }

        It "Persistent damage layer is off" {
            $Settings['PersistentDamageLayer'] | Should -Be 'false'
        }

        It "AA technique is SMAA (not upscaler)" {
            $Settings['AATechniquePreferredMP'] | Should -Be 'SMAA'
        }

        # -- Input --
        It "Raw mouse input is enabled" {
            $Settings['MouseUsesRawInput'] | Should -Be 'true'
        }

        # -- Cloud sync --
        It "Cloud storage sync is disabled" {
            $Settings['ConfigCloudStorageEnabled'] | Should -Be 'false'
        }
    }

    # -----------------------------------------------------------------
    Context "Script source code correctness" {
        BeforeAll {
            $ScriptContent = Get-Content $ScriptFile -Raw
        }

        It "Script emits SQ_CHECK marker for COD_EXE_FLAGS" {
            $ScriptContent | Should -Match 'COD_EXE_FLAGS'
        }

        It "Script emits SQ_CHECK marker for COD_GAME_MODE_ON" {
            $ScriptContent | Should -Match 'COD_GAME_MODE_ON'
        }

        It "Script emits SQ_CHECK marker for COD_GAME_DVR_OFF" {
            $ScriptContent | Should -Match 'COD_GAME_DVR_OFF'
        }

        It "Script emits SQ_CHECK marker for COD_CONFIG_FILES_COPIED" {
            $ScriptContent | Should -Match 'COD_CONFIG_FILES_COPIED'
        }

        It "Script emits SQ_CHECK marker for COD_RENDERER_WORKER_COUNT" {
            $ScriptContent | Should -Match 'COD_RENDERER_WORKER_COUNT'
        }

        It "Script does NOT use Set-Content on template files" {
            # v1.0.13 lesson: Set-Content rewrites corrupt BO7 template bytes
            $ScriptContent | Should -Not -Match 'Set-Content.*cod25\.(txt0|txt1|m)' `
                -Because "BO7 templates must be copied byte-for-byte, never rewritten (v1.0.13 regression)"
        }

        It "Script uses Copy-Item for template deployment" {
            $ScriptContent | Should -Match 'Copy-Item'
        }

        It "Script verifies copy via hash comparison" {
            $ScriptContent | Should -Match 'Get-FileHash'
        }

        It "Script references all three required template files" {
            $ScriptContent | Should -Match 's\.1\.0\.cod25\.txt0'
            $ScriptContent | Should -Match 's\.1\.0\.cod25\.txt1'
            $ScriptContent | Should -Match 's\.1\.0\.cod25\.m'
        }

        It "Script runs in headless mode" {
            $ScriptContent | Should -Match 'Initialize-SQEngine|SENSEQUALITY_HEADLESS'
        }
    }
}

# ===========================================================================
# VALORANT TESTS
# ===========================================================================
Describe "Valorant GameUserSettings.ini" -Tag "valorant" {

    BeforeAll {
        $ProjectRoot = (Get-Location).Path
        $ScriptsDir = Join-Path $ProjectRoot "scripts"
        $ReferenceDir = Join-Path $ScriptsDir "reference-configs"
        $RefFile = Join-Path $ReferenceDir "valorant-GameUserSettings.ini"
        $ScriptFile = Join-Path $ScriptsDir "04_Valorant_Settings.ps1"

        # Helper: Check if a file starts with UTF-8 BOM (EF BB BF)
        function Test-HasBOM {
            param([string]$Path)
            $bytes = [System.IO.File]::ReadAllBytes($Path)
            return ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        }

        # Helper: Parse UE4 INI into ordered dict of section -> keys
        function Parse-IniSections {
            param([string]$Path)
            $sections = [ordered]@{}
            $currentSection = ""
            foreach ($line in (Get-Content $Path)) {
                if ($line -match '^\[(.+)\]$') {
                    $currentSection = $Matches[1]
                    if (-not $sections.Contains($currentSection)) {
                        $sections[$currentSection] = [ordered]@{}
                    }
                } elseif ($currentSection -and $line -match '^(.+?)=(.*)$') {
                    $sections[$currentSection][$Matches[1]] = $Matches[2]
                }
            }
            return $sections
        }

        # Parse reference config
        $RefSections = Parse-IniSections -Path $RefFile
    }

    # -----------------------------------------------------------------
    Context "Reference config is valid" {
        It "Reference file exists" {
            $RefFile | Should -Exist
        }

        It "Reference file has all 4 required sections" {
            $RefSections.Keys | Should -Contain '/Script/ShooterGame.ShooterGameUserSettings'
            $RefSections.Keys | Should -Contain '/Script/Engine.GameUserSettings'
            $RefSections.Keys | Should -Contain 'ScalabilityGroups'
            $RefSections.Keys | Should -Contain 'ShaderPipelineCache.CacheFile'
        }

        It "ShooterGame section has expected performance keys" {
            $sg = $RefSections['/Script/ShooterGame.ShooterGameUserSettings']
            $sg.Keys | Should -Contain 'bUseVSync'
            $sg.Keys | Should -Contain 'FrameRateLimit'
            $sg.Keys | Should -Contain 'LastConfirmedFullscreenMode'
            $sg.Keys | Should -Contain 'PreferredFullscreenMode'
            $sg.Keys | Should -Contain 'ResolutionSizeX'
            $sg.Keys | Should -Contain 'ResolutionSizeY'
        }

        It "ScalabilityGroups has all 9 sg. keys" {
            $scal = $RefSections['ScalabilityGroups']
            $scal.Keys | Should -Contain 'sg.ResolutionQuality'
            $scal.Keys | Should -Contain 'sg.ViewDistanceQuality'
            $scal.Keys | Should -Contain 'sg.AntiAliasingQuality'
            $scal.Keys | Should -Contain 'sg.ShadowQuality'
            $scal.Keys | Should -Contain 'sg.PostProcessQuality'
            $scal.Keys | Should -Contain 'sg.TextureQuality'
            $scal.Keys | Should -Contain 'sg.EffectsQuality'
            $scal.Keys | Should -Contain 'sg.FoliageQuality'
            $scal.Keys | Should -Contain 'sg.ShadingQuality'
        }

        It "Reference does NOT contain fake keys (GlobalIlluminationQuality, ReflectionQuality)" {
            $allKeys = @()
            foreach ($section in $RefSections.Keys) {
                $allKeys += $RefSections[$section].Keys
            }
            $allKeys | Should -Not -Contain 'sg.GlobalIlluminationQuality'
            $allKeys | Should -Not -Contain 'sg.ReflectionQuality'
        }

        It "ShaderPipelineCache section has LastOpened=ShooterGame" {
            $RefSections['ShaderPipelineCache.CacheFile']['LastOpened'] | Should -Be 'ShooterGame'
        }
    }

    # -----------------------------------------------------------------
    Context "Script competitive settings use valid key names" {
        BeforeAll {
            $ScriptContent = Get-Content $ScriptFile -Raw

            # Extract all ScalabilityGroups keys from the script overrides hashtable
            $ScriptSgKeys = [regex]::Matches($ScriptContent, "'(sg\.\w+)'") |
                ForEach-Object { $_.Groups[1].Value } |
                Select-Object -Unique

            # Extract ShooterGame override keys from $ShooterGameOverrides block only
            # Match keys on the left side of '=' (pattern: 'KeyName' followed by optional whitespace and =)
            $shooterBlock = [regex]::Match($ScriptContent, '(?s)\$ShooterGameOverrides\s*=\s*@\{(.+?)\}')
            $ScriptShooterKeys = @()
            if ($shooterBlock.Success) {
                $ScriptShooterKeys = [regex]::Matches($shooterBlock.Groups[1].Value, "'(\w+)'\s*=") |
                    ForEach-Object { $_.Groups[1].Value } |
                    Select-Object -Unique
            }

            # All reference ScalabilityGroups keys
            $RefScalKeys = $RefSections['ScalabilityGroups'].Keys

            # All reference ShooterGame keys
            $RefShooterKeys = $RefSections['/Script/ShooterGame.ShooterGameUserSettings'].Keys
        }

        It "All ScalabilityGroups keys in script exist in reference config" {
            $missingKeys = @()
            foreach ($key in $ScriptSgKeys) {
                if ($key -notin $RefScalKeys) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These sg. keys are not in the reference config: $($missingKeys -join ', ')"
        }

        It "All ShooterGame override keys in script exist in reference config" {
            $missingKeys = @()
            foreach ($key in $ScriptShooterKeys) {
                if ($key -notin $RefShooterKeys) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These ShooterGame keys are not in the reference config: $($missingKeys -join ', ')"
        }

        It "Script does NOT write fake keys (GlobalIlluminationQuality, ReflectionQuality)" {
            $ScriptContent | Should -Not -Match 'GlobalIlluminationQuality'
            $ScriptContent | Should -Not -Match 'sg\.ReflectionQuality'
        }
    }

    # -----------------------------------------------------------------
    Context "Script output file format" {
        BeforeAll {
            # Create a temp sandbox simulating Valorant's folder structure:
            # <LOCALAPPDATA>\VALORANT\Saved\Config\<AccountID>\Windows\GameUserSettings.ini
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "sq-test-valorant-$(Get-Random)"
            $accountDir = Join-Path $script:TempDir "VALORANT\Saved\Config\TestAccount123\Windows"
            New-Item -ItemType Directory -Path $accountDir -Force | Out-Null

            # Seed with reference config to test read-merge-write
            Copy-Item $RefFile (Join-Path $accountDir "GameUserSettings.ini") -Force

            # Save original LOCALAPPDATA
            $script:OrigLocalAppData = $env:LOCALAPPDATA

            # Run the script in headless mode with overridden LOCALAPPDATA
            $env:SENSEQUALITY_HEADLESS = "1"
            $env:MONITOR_WIDTH = "1920"
            $env:MONITOR_HEIGHT = "1080"
            $env:MONITOR_REFRESH = "240"
            $env:LOCALAPPDATA = $script:TempDir

            $scriptPath = Join-Path $ScriptsDir "04_Valorant_Settings.ps1"
            # *>&1 captures all streams including Write-Host (stream 6)
            $script:Output = & $scriptPath *>&1 | Out-String
            $script:OutputFile = Join-Path $accountDir "GameUserSettings.ini"
        }

        AfterAll {
            # Restore LOCALAPPDATA and clean up
            $env:LOCALAPPDATA = $script:OrigLocalAppData
            $env:SENSEQUALITY_HEADLESS = ""
            if ($script:TempDir -and (Test-Path $script:TempDir)) {
                Get-ChildItem $script:TempDir -Recurse -File -ErrorAction SilentlyContinue |
                    ForEach-Object { if ($_.IsReadOnly) { $_.IsReadOnly = $false } }
                Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Output file exists" {
            $script:OutputFile | Should -Exist
        }

        It "Output file has no UTF-8 BOM" {
            Test-HasBOM $script:OutputFile | Should -BeFalse -Because "UE4 INI files should not have BOM"
        }

        It "Output file is valid INI with section headers" {
            $content = Get-Content $script:OutputFile -Raw
            $content | Should -Match '\[ScalabilityGroups\]'
            $content | Should -Match '\[/Script/ShooterGame\.ShooterGameUserSettings\]'
            $content | Should -Match '\[/Script/Engine\.GameUserSettings\]'
        }

        It "Output has ShaderPipelineCache section (preserved from seed)" {
            $content = Get-Content $script:OutputFile -Raw
            $content | Should -Match '\[ShaderPipelineCache\.CacheFile\]'
        }

        It "ScalabilityGroups values are correct competitive settings" {
            $outSections = Parse-IniSections -Path $script:OutputFile
            $sg = $outSections['ScalabilityGroups']
            $sg['sg.ShadowQuality'] | Should -Be '0'
            $sg['sg.TextureQuality'] | Should -Be '3'
            $sg['sg.EffectsQuality'] | Should -Be '0'
            $sg['sg.ResolutionQuality'] | Should -Be '100.000000'
        }

        It "FrameRateLimit is uncapped (0)" {
            $outSections = Parse-IniSections -Path $script:OutputFile
            $sg = $outSections['/Script/ShooterGame.ShooterGameUserSettings']
            $sg['FrameRateLimit'] | Should -Be '0.000000'
        }

        It "bUseVSync is False" {
            $outSections = Parse-IniSections -Path $script:OutputFile
            $sg = $outSections['/Script/ShooterGame.ShooterGameUserSettings']
            $sg['bUseVSync'] | Should -Be 'False'
        }

        It "LastConfirmedFullscreenMode is 0 (exclusive fullscreen)" {
            $outSections = Parse-IniSections -Path $script:OutputFile
            $sg = $outSections['/Script/ShooterGame.ShooterGameUserSettings']
            $sg['LastConfirmedFullscreenMode'] | Should -Be '0'
        }

        It "Read-merge-write preserved non-performance keys from seed" {
            $outSections = Parse-IniSections -Path $script:OutputFile
            $sg = $outSections['/Script/ShooterGame.ShooterGameUserSettings']
            # These keys exist in reference config seed and should be preserved
            $sg.Keys | Should -Contain 'DefaultMonitorDeviceID'
            $sg.Keys | Should -Contain 'ResolutionSizeX'
            $sg.Keys | Should -Contain 'bUseHDRDisplayOutput'
            $sg.Keys | Should -Contain 'LastGPUBenchmarkResult'
        }

        It "SQ_CHECK markers are emitted for config write" {
            $script:Output | Should -Match '\[SQ_CHECK_(OK|WARN|FAIL):VALORANT_CONFIG_WRITTEN'
        }

        It "SQ_CHECK markers are emitted for EXE flags" {
            $script:Output | Should -Match '\[SQ_CHECK_(OK|WARN):VALORANT_EXE_FLAGS'
        }

        It "Output file does NOT contain fake keys" {
            $content = Get-Content $script:OutputFile -Raw
            $content | Should -Not -Match 'sg\.GlobalIlluminationQuality'
            $content | Should -Not -Match 'sg\.ReflectionQuality'
            $content | Should -Not -Match 'bColorVisionDeficiency'
            $content | Should -Not -Match 'ControllerVibration'
        }
    }

    # -----------------------------------------------------------------
    Context "Script source code correctness" {
        BeforeAll {
            $ScriptContent = Get-Content $ScriptFile -Raw
        }

        It "Script runs in headless mode" {
            $ScriptContent | Should -Match 'Initialize-SQEngine|SENSEQUALITY_HEADLESS'
        }

        It "Script uses Write-Check or SQ_CHECK markers" {
            $ScriptContent | Should -Match 'Write-Check|SQ_CHECK'
        }

        It "Script enumerates account subdirectories (not hardcoded path)" {
            $ScriptContent | Should -Match 'Get-ChildItem'
            $ScriptContent | Should -Not -Match 'Config\\Windows\\GameUserSettings'
        }

        It "Script uses read-merge-write pattern (not blind overwrite)" {
            $ScriptContent | Should -Match 'Read-IniFile|Merge-IniSection'
            $ScriptContent | Should -Not -Match 'Set-Content.*GameUserSettings'
        }

        It "Script writes UTF-8 without BOM" {
            $ScriptContent | Should -Match 'UTF8Encoding.*\$false'
        }

        It "Script sets config read-only after write" {
            $ScriptContent | Should -Match 'Lock-ConfigFile|IsReadOnly.*\$true'
        }

        It "Script backs up existing config before writing" {
            $ScriptContent | Should -Match 'Backup-ConfigFile|bak_'
        }
    }
}

# ===========================================================================
# FORTNITE TESTS
# ===========================================================================
Describe "Fortnite GameUserSettings.ini" -Tag "fortnite" {

    BeforeAll {
        $ProjectRoot = (Get-Location).Path
        $ScriptsDir = Join-Path $ProjectRoot "scripts"
        $ReferenceDir = Join-Path $ScriptsDir "reference-configs"
        $RefFile = Join-Path $ReferenceDir "fortnite-GameUserSettings.ini"
        $ScriptFile = Join-Path $ScriptsDir "03_Fortnite_Settings.ps1"

        # Helper: Parse UE4 INI file into section -> key names hashtable
        function Parse-FortniteIni {
            param([string]$Path)
            $sections = @{}
            $currentSection = ''
            foreach ($line in (Get-Content $Path)) {
                if ($line -match '^\[(.+)\]$') {
                    $currentSection = $Matches[1]
                    if (-not $sections.ContainsKey($currentSection)) {
                        $sections[$currentSection] = @()
                    }
                } elseif ($currentSection -and $line -match '^([^;=][^=]*)=') {
                    $keyName = $Matches[1].Trim()
                    $sections[$currentSection] += $keyName
                }
            }
            return $sections
        }
    }

    # -----------------------------------------------------------------
    Context "Reference config is valid" {
        It "Reference file exists" {
            $RefFile | Should -Exist
        }

        It "Reference file has required INI sections" {
            $content = Get-Content $RefFile -Raw
            $content | Should -Match '\[/Script/FortniteGame\.FortGameUserSettings\]'
            $content | Should -Match '\[ScalabilityGroups\]'
        }

        It "Reference file has competitive sections (D3DRHIPreference, PerformanceMode)" {
            $content = Get-Content $RefFile -Raw
            $content | Should -Match '\[D3DRHIPreference\]'
            $content | Should -Match '\[PerformanceMode\]'
        }

        It "Reference has all 12 scalability group keys" {
            $ref = Parse-FortniteIni $RefFile
            $sgKeys = $ref['ScalabilityGroups']
            $sgKeys | Should -Contain 'sg.ResolutionQuality'
            $sgKeys | Should -Contain 'sg.ViewDistanceQuality'
            $sgKeys | Should -Contain 'sg.AntiAliasingQuality'
            $sgKeys | Should -Contain 'sg.ShadowQuality'
            $sgKeys | Should -Contain 'sg.GlobalIlluminationQuality'
            $sgKeys | Should -Contain 'sg.ReflectionQuality'
            $sgKeys | Should -Contain 'sg.PostProcessQuality'
            $sgKeys | Should -Contain 'sg.TextureQuality'
            $sgKeys | Should -Contain 'sg.EffectsQuality'
            $sgKeys | Should -Contain 'sg.FoliageQuality'
            $sgKeys | Should -Contain 'sg.ShadingQuality'
            $sgKeys | Should -Contain 'sg.LandscapeQuality'
        }

        It "Reference has UE5 competitive keys (bRayTracing, bUseNanite, FortAntiAliasingMethod)" {
            $ref = Parse-FortniteIni $RefFile
            $fortKeys = $ref['/Script/FortniteGame.FortGameUserSettings']
            $fortKeys | Should -Contain 'bRayTracing'
            $fortKeys | Should -Contain 'bUseNanite'
            $fortKeys | Should -Contain 'FortAntiAliasingMethod'
            $fortKeys | Should -Contain 'LowInputLatencyModeIsEnabled'
            $fortKeys | Should -Contain 'DesiredGlobalIlluminationQuality'
            $fortKeys | Should -Contain 'DesiredReflectionQuality'
        }
    }

    # -----------------------------------------------------------------
    Context "Script uses valid key names from reference config" {
        BeforeAll {
            $ref = Parse-FortniteIni $RefFile
            $scriptContent = Get-Content $ScriptFile -Raw

            # Extract all Set-IniValue calls. The script uses two patterns:
            #   Set-IniValue $ini $fortSection 'Key' 'Value'  (variable section)
            #   Set-IniValue $ini 'Section' 'Key' 'Value'     (literal section)
            # Use single-quoted regex to avoid PS variable expansion.

            # Pattern 1: literal section names like 'ScalabilityGroups'
            $LiteralCalls = [regex]::Matches(
                $scriptContent,
                'Set-IniValue\s+\$ini\s+''([^'']+)''\s+''([^'']+)''\s+'
            )
            # Pattern 2: variable section names like $fortSection
            $VarCalls = [regex]::Matches(
                $scriptContent,
                'Set-IniValue\s+\$ini\s+\$fortSection\s+''([^'']+)''\s+'
            )

            $TotalCallCount = $LiteralCalls.Count + $VarCalls.Count

            # Build a hashtable of section -> keys used by the script
            $ScriptSections = @{}
            foreach ($m in $LiteralCalls) {
                $section = $m.Groups[1].Value
                $key = $m.Groups[2].Value
                if (-not $ScriptSections.ContainsKey($section)) {
                    $ScriptSections[$section] = @()
                }
                $ScriptSections[$section] += $key
            }
            # Variable-section calls map to the FortGameUserSettings section
            $fortSectionName = '/Script/FortniteGame.FortGameUserSettings'
            if (-not $ScriptSections.ContainsKey($fortSectionName)) {
                $ScriptSections[$fortSectionName] = @()
            }
            foreach ($m in $VarCalls) {
                $key = $m.Groups[1].Value
                $ScriptSections[$fortSectionName] += $key
            }
        }

        It "Script Set-IniValue calls were successfully extracted" {
            $TotalCallCount | Should -BeGreaterThan 20 -Because "Script should write 20+ competitive settings"
        }

        It "All FortGameUserSettings keys exist in reference config" {
            $section = '/Script/FortniteGame.FortGameUserSettings'
            $refKeys = $ref[$section]
            $scriptKeys = $ScriptSections[$section]
            $missingKeys = @()
            foreach ($key in $scriptKeys) {
                if ($key -notin $refKeys) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These keys are not in the reference config: $($missingKeys -join ', ')"
        }

        It "All ScalabilityGroups keys exist in reference config" {
            $section = 'ScalabilityGroups'
            $refKeys = $ref[$section]
            $scriptKeys = $ScriptSections[$section]
            $missingKeys = @()
            foreach ($key in $scriptKeys) {
                if ($key -notin $refKeys) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These scalability keys are not in the reference: $($missingKeys -join ', ')"
        }

        It "All D3DRHIPreference keys exist in reference config" {
            $section = 'D3DRHIPreference'
            $refKeys = $ref[$section]
            $scriptKeys = $ScriptSections[$section]
            $missingKeys = @()
            foreach ($key in $scriptKeys) {
                if ($key -notin $refKeys) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These D3DRHIPreference keys are not in the reference: $($missingKeys -join ', ')"
        }

        It "Script does NOT use nonexistent keys (bFullscreenMode, bRunningOnHighEndMachine, etc.)" {
            # These keys were in the old script but do not exist in real Fortnite configs
            $scriptContent | Should -Not -Match 'bFullscreenMode' -Because "Real Fortnite uses PreferredFullscreenMode, not bFullscreenMode"
            $scriptContent | Should -Not -Match 'bRunningOnHighEndMachine' -Because "This key does not exist in real Fortnite configs"
            $scriptContent | Should -Not -Match 'LastConfirmedScalability' -Because "Scalability is in [ScalabilityGroups] section, not as a string"
            $scriptContent | Should -Not -Match 'GameUserSettingsVersion' -Because "This key does not exist in real Fortnite configs"
            $scriptContent | Should -Not -Match 'bCinematicMode' -Because "This key does not exist in real Fortnite configs"
            $scriptContent | Should -Not -Match 'bForceClientExclusive' -Because "This key does not exist in real Fortnite configs"
        }

        It "Script does NOT write a [/Script/Engine.GameUserSettings] section" {
            # Fortnite puts all engine settings in FortGameUserSettings, not a separate Engine section
            $scriptContent | Should -Not -Match 'Engine\.GameUserSettings' -Because "Fortnite does not use a separate Engine.GameUserSettings section"
        }

        It "Script does NOT use named audio volume keys (MusicVolume, SoundFXVolume)" {
            # Real Fortnite uses [/Script/FortniteGame.FortAudioMixSubsystem] with UserMixCurrentValues array
            $scriptContent | Should -Not -Match "'MusicVolume'" -Because "Real Fortnite uses UserMixCurrentValues array, not named volume keys"
            $scriptContent | Should -Not -Match "'SoundFXVolume'" -Because "Real Fortnite uses UserMixCurrentValues array, not named volume keys"
            $scriptContent | Should -Not -Match "'DialogueVolume'" -Because "Real Fortnite uses UserMixCurrentValues array, not named volume keys"
            $scriptContent | Should -Not -Match "'VoiceChatVolume'" -Because "Real Fortnite uses UserMixCurrentValues array, not named volume keys"
        }
    }

    # -----------------------------------------------------------------
    Context "Script output file format (read-merge-write)" {
        BeforeAll {
            # Create temp sandbox simulating %LOCALAPPDATA%
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "sq-test-fortnite-$(Get-Random)"
            $configDir = Join-Path $script:TempDir "FortniteGame\Saved\Config\WindowsClient"
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null

            # Seed with reference config to test read-merge-write preservation
            Copy-Item $RefFile (Join-Path $configDir "GameUserSettings.ini") -Force

            # Save original LOCALAPPDATA
            $script:OrigLocalAppData = $env:LOCALAPPDATA

            # Run the script in headless mode with overridden LOCALAPPDATA
            $env:SENSEQUALITY_HEADLESS = "1"
            $env:MONITOR_WIDTH = "1920"
            $env:MONITOR_HEIGHT = "1080"
            $env:MONITOR_REFRESH = "240"
            $env:NVIDIA_GPU = "1"
            $env:LOCALAPPDATA = $script:TempDir

            $scriptPath = Join-Path $ScriptsDir "03_Fortnite_Settings.ps1"
            $Output = & $scriptPath *>&1 | Out-String
            $OutputFile = Join-Path $configDir "GameUserSettings.ini"
        }

        AfterAll {
            # Restore LOCALAPPDATA and clean up
            $env:LOCALAPPDATA = $script:OrigLocalAppData
            $env:SENSEQUALITY_HEADLESS = ""
            if ($script:TempDir -and (Test-Path $script:TempDir)) {
                Get-ChildItem $script:TempDir -Recurse -File -ErrorAction SilentlyContinue |
                    ForEach-Object { if ($_.IsReadOnly) { $_.IsReadOnly = $false } }
                Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Output file exists" {
            $OutputFile | Should -Exist
        }

        It "Output file has no UTF-8 BOM" {
            $bytes = [System.IO.File]::ReadAllBytes($OutputFile)
            $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
            $hasBom | Should -BeFalse -Because "UE4 INI parser may have issues with BOM"
        }

        It "Output file has [/Script/FortniteGame.FortGameUserSettings] section" {
            $content = Get-Content $OutputFile -Raw
            $content | Should -Match '\[/Script/FortniteGame\.FortGameUserSettings\]'
        }

        It "Output file has [ScalabilityGroups] section" {
            $content = Get-Content $OutputFile -Raw
            $content | Should -Match '\[ScalabilityGroups\]'
        }

        It "Output file has [D3DRHIPreference] section with dx11" {
            $content = Get-Content $OutputFile -Raw
            $content | Should -Match '\[D3DRHIPreference\]'
            $content | Should -Match 'PreferredRHI=dx11'
        }

        It "Output file has [PerformanceMode] section" {
            $content = Get-Content $OutputFile -Raw
            $content | Should -Match '\[PerformanceMode\]'
            $content | Should -Match 'MeshQuality=0'
        }

        It "Competitive scalability groups are set to low/off" {
            $content = Get-Content $OutputFile -Raw
            $content | Should -Match 'sg\.ShadowQuality=0'
            $content | Should -Match 'sg\.EffectsQuality=0'
            $content | Should -Match 'sg\.PostProcessQuality=0'
            $content | Should -Match 'sg\.FoliageQuality=0'
            $content | Should -Match 'sg\.ShadingQuality=0'
            $content | Should -Match 'sg\.LandscapeQuality=2'
        }

        It "Resolution is set to monitor values" {
            $content = Get-Content $OutputFile -Raw
            $content | Should -Match 'ResolutionSizeX=1920'
            $content | Should -Match 'ResolutionSizeY=1080'
        }

        It "Fullscreen mode is exclusive (PreferredFullscreenMode=0)" {
            $content = Get-Content $OutputFile -Raw
            $content | Should -Match 'PreferredFullscreenMode=0'
            $content | Should -Match 'LastConfirmedFullscreenMode=0'
        }

        It "Read-merge-write preserves existing user data (bEulaAccepted, etc.)" {
            $content = Get-Content $OutputFile -Raw
            # These keys exist in the reference config (seeded) and must survive merge
            $content | Should -Match 'bEulaAccepted=True' -Because "Read-merge-write must preserve user account data"
            $content | Should -Match 'FortniteReleaseVersion=' -Because "Read-merge-write must preserve game version"
        }

        It "Read-merge-write preserves [ChatSettings] section" {
            $content = Get-Content $OutputFile -Raw
            $content | Should -Match '\[ChatSettings\]' -Because "Read-merge-write must preserve non-competitive sections"
        }

        It "Output file does NOT have [/Script/Engine.GameUserSettings] section" {
            $content = Get-Content $OutputFile -Raw
            $content | Should -Not -Match '\[/Script/Engine\.GameUserSettings\]'
        }

        It "SQ_CHECK markers are emitted for config write" {
            $Output | Should -Match '\[SQ_CHECK_(OK|WARN|FAIL):FN_CONFIG_FILES_WRITTEN'
        }

        It "SQ_CHECK markers are emitted for writable check" {
            $Output | Should -Match '\[SQ_CHECK_(OK|WARN|FAIL):FN_CONFIG_WRITABLE'
        }
    }

    # -----------------------------------------------------------------
    Context "Script source code correctness" {
        BeforeAll {
            $ScriptContent = Get-Content $ScriptFile -Raw
        }

        It "Script runs in headless mode" {
            $ScriptContent | Should -Match 'Initialize-SQEngine|SENSEQUALITY_HEADLESS'
        }

        It "Script uses read-merge-write pattern (not blind overwrite)" {
            # Should read existing config, not just create from scratch
            $ScriptContent | Should -Match 'Read-FortniteIni' -Because "Script must read existing config before writing"
            $ScriptContent | Should -Match 'Set-IniValue' -Because "Script must merge individual keys, not overwrite entire file"
        }

        It "Script backs up existing config before writing" {
            $ScriptContent | Should -Match 'Backup-ConfigFile|\.bak_'
        }

        It "Script writes UTF-8 without BOM" {
            $ScriptContent | Should -Match 'UTF8Encoding.*\$false' -Because "WriteAllText must use UTF8Encoding without BOM"
        }

        It "Script sets EXE compatibility flags" {
            $ScriptContent | Should -Match 'Set-ExeCompatFlags|HIGHDPIAWARE'
        }

        It "Script forces Performance Mode via D3DRHIPreference section" {
            $ScriptContent | Should -Match "'D3DRHIPreference'"
            $ScriptContent | Should -Match "'PreferredRHI'"
            $ScriptContent | Should -Match "'dx11'"
        }

        It "Guide text matches config values (fullscreen = 0, not 1)" {
            # PreferredFullscreenMode=0 means exclusive fullscreen
            $ScriptContent | Should -Match 'PreferredFullscreenMode=0' -Because "Guide says Fullscreen, so value must be 0 (exclusive)"
        }
    }
}

# ===========================================================================
# ARC RAIDERS TESTS
# ===========================================================================
Describe "Arc Raiders GameUserSettings.ini" -Tag "arcraiders" {

    BeforeAll {
        $ProjectRoot = (Get-Location).Path
        $ScriptsDir = Join-Path $ProjectRoot "scripts"
        $ReferenceDir = Join-Path $ScriptsDir "reference-configs"
        $RefGUS = Join-Path $ReferenceDir "arcraiders-GameUserSettings.ini"
        $RefEngine = Join-Path $ReferenceDir "arcraiders-Engine.ini"
        $ScriptFile = Join-Path $ScriptsDir "06_ArcRaiders_Settings.ps1"

        # Helper: Check if a file starts with UTF-8 BOM (EF BB BF)
        function Test-HasBOM {
            param([string]$Path)
            $bytes = [System.IO.File]::ReadAllBytes($Path)
            return ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        }

        # Helper: Parse UE5 INI into ordered dict of section -> keys
        function Parse-IniSections {
            param([string]$Path)
            $sections = [ordered]@{}
            $currentSection = ""
            foreach ($line in (Get-Content $Path)) {
                if ($line -match '^\[(.+)\]$') {
                    $currentSection = $Matches[1]
                    if (-not $sections.Contains($currentSection)) {
                        $sections[$currentSection] = [ordered]@{}
                    }
                } elseif ($currentSection -and $line -match '^(.+?)=(.*)$') {
                    $sections[$currentSection][$Matches[1]] = $Matches[2]
                }
            }
            return $sections
        }

        # Parse reference configs
        $RefSections = Parse-IniSections -Path $RefGUS
        $RefEngineSections = Parse-IniSections -Path $RefEngine
    }

    # -----------------------------------------------------------------
    Context "Reference configs are valid" {
        It "GameUserSettings.ini reference file exists" {
            $RefGUS | Should -Exist
        }

        It "Engine.ini reference file exists" {
            $RefEngine | Should -Exist
        }

        It "Reference GameUserSettings.ini has Embark section" {
            $RefSections.Keys | Should -Contain '/Script/EmbarkUserSettings.EmbarkGameUserSettings'
        }

        It "Reference GameUserSettings.ini has ScalabilityGroups section" {
            $RefSections.Keys | Should -Contain 'ScalabilityGroups'
        }

        It "Reference GameUserSettings.ini has SystemSettings section" {
            $RefSections.Keys | Should -Contain 'SystemSettings'
        }

        It "Embark section has expected keys" {
            $embark = $RefSections['/Script/EmbarkUserSettings.EmbarkGameUserSettings']
            $embark.Keys | Should -Contain 'DLSSMode'
            $embark.Keys | Should -Contain 'NvReflexMode'
            $embark.Keys | Should -Contain 'FullscreenMode'
            $embark.Keys | Should -Contain 'bUseVSync'
            $embark.Keys | Should -Contain 'FrameRateLimit'
            $embark.Keys | Should -Contain 'MotionBlurEnabled'
            $embark.Keys | Should -Contain 'LensDistortionEnabled'
            $embark.Keys | Should -Contain 'RTXGIQuality'
        }

        It "ScalabilityGroups has all 11 sg. keys" {
            $scal = $RefSections['ScalabilityGroups']
            $scal.Keys | Should -Contain 'sg.ViewDistanceQuality'
            $scal.Keys | Should -Contain 'sg.ShadowQuality'
            $scal.Keys | Should -Contain 'sg.TextureQuality'
            $scal.Keys | Should -Contain 'sg.EffectsQuality'
            $scal.Keys | Should -Contain 'sg.FoliageQuality'
            $scal.Keys | Should -Contain 'sg.PostProcessQuality'
            $scal.Keys | Should -Contain 'sg.ReflectionQuality'
            $scal.Keys | Should -Contain 'sg.ShadingQuality'
            $scal.Keys | Should -Contain 'sg.GlobalIlluminationQuality'
            $scal.Keys | Should -Contain 'sg.AntiAliasingQuality'
            $scal.Keys | Should -Contain 'sg.ResolutionQuality'
        }

        It "SystemSettings has visual clarity keys" {
            $sys = $RefSections['SystemSettings']
            $sys.Keys | Should -Contain 'r.DepthOfFieldQuality'
            $sys.Keys | Should -Contain 'r.BloomQuality'
            $sys.Keys | Should -Contain 'r.LensFlareQuality'
            $sys.Keys | Should -Contain 'r.Tonemapper.Sharpen'
            $sys.Keys | Should -Contain 'r.Tonemapper.GrainQuantization'
        }

        It "Engine.ini reference has SystemSettings section" {
            $RefEngineSections.Keys | Should -Contain 'SystemSettings'
        }

        It "Engine.ini reference has ConsoleVariables section" {
            $RefEngineSections.Keys | Should -Contain 'ConsoleVariables'
        }
    }

    # -----------------------------------------------------------------
    Context "Script competitive settings use valid key names" {
        BeforeAll {
            $ScriptContent = Get-Content $ScriptFile -Raw

            # Extract Embark override keys from the ordered hashtable
            $ScriptEmbarkKeys = [regex]::Matches($ScriptContent, "\`$EmbarkOverrides\['(\w+)'\]") |
                ForEach-Object { $_.Groups[1].Value } |
                Select-Object -Unique

            # Extract ScalabilityGroups keys
            $ScriptSgKeys = [regex]::Matches($ScriptContent, "'(sg\.\w+)'") |
                ForEach-Object { $_.Groups[1].Value } |
                Select-Object -Unique

            # Extract SystemSettings keys from the script
            $ScriptSysKeys = [regex]::Matches($ScriptContent, "'(r\.\w+[\.\w]*)'") |
                ForEach-Object { $_.Groups[1].Value } |
                Select-Object -Unique

            # All reference keys by section
            $RefEmbarkKeys = $RefSections['/Script/EmbarkUserSettings.EmbarkGameUserSettings'].Keys
            $RefScalKeys = $RefSections['ScalabilityGroups'].Keys
            $RefSysKeys = $RefSections['SystemSettings'].Keys
            # Also include Engine.ini SystemSettings keys
            $RefEngSysKeys = $RefEngineSections['SystemSettings'].Keys
        }

        It "All Embark override keys in script exist in reference config" {
            $missingKeys = @()
            foreach ($key in $ScriptEmbarkKeys) {
                if ($key -notin $RefEmbarkKeys) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These Embark keys are not in the reference config: $($missingKeys -join ', ')"
        }

        It "All ScalabilityGroups keys in script exist in reference config" {
            $missingKeys = @()
            foreach ($key in $ScriptSgKeys) {
                if ($key -notin $RefScalKeys) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These sg. keys are not in the reference config: $($missingKeys -join ', ')"
        }

        It "All SystemSettings r.* keys in script exist in reference or Engine.ini" {
            $allRefSysKeys = @()
            if ($RefSysKeys) { $allRefSysKeys += $RefSysKeys }
            if ($RefEngSysKeys) { $allRefSysKeys += $RefEngSysKeys }
            $missingKeys = @()
            foreach ($key in $ScriptSysKeys) {
                if ($key -notin $allRefSysKeys) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These r.* keys are not in any reference config: $($missingKeys -join ', ')"
        }
    }

    # -----------------------------------------------------------------
    Context "Script output file format" {
        BeforeAll {
            # Create temp sandbox simulating PioneerGame config structure
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "sq-test-arcraiders-$(Get-Random)"
            $configDir = Join-Path $script:TempDir "PioneerGame\Saved\Config\WindowsClient"
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null

            # Seed with reference config to test read-merge-write
            Copy-Item $RefGUS (Join-Path $configDir "GameUserSettings.ini") -Force

            # Save original LOCALAPPDATA
            $script:OrigLocalAppData = $env:LOCALAPPDATA

            # Run the script in headless mode
            $env:SENSEQUALITY_HEADLESS = "1"
            $env:MONITOR_WIDTH = "1920"
            $env:MONITOR_HEIGHT = "1080"
            $env:MONITOR_REFRESH = "240"
            $env:NVIDIA_GPU = "1"
            $env:LOCALAPPDATA = $script:TempDir

            $scriptPath = Join-Path $ScriptsDir "06_ArcRaiders_Settings.ps1"
            $script:Output = & $scriptPath *>&1 | Out-String
            $script:GUSFile = Join-Path $configDir "GameUserSettings.ini"
            $script:EngineFile = Join-Path $configDir "Engine.ini"
        }

        AfterAll {
            $env:LOCALAPPDATA = $script:OrigLocalAppData
            $env:SENSEQUALITY_HEADLESS = ""
            if ($script:TempDir -and (Test-Path $script:TempDir)) {
                Get-ChildItem $script:TempDir -Recurse -File -ErrorAction SilentlyContinue |
                    ForEach-Object { if ($_.IsReadOnly) { $_.IsReadOnly = $false } }
                Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "GameUserSettings.ini output file exists" {
            $script:GUSFile | Should -Exist
        }

        It "Engine.ini output file exists" {
            $script:EngineFile | Should -Exist
        }

        It "GameUserSettings.ini has no UTF-8 BOM" {
            Test-HasBOM $script:GUSFile | Should -BeFalse -Because "UE5 INI parser can reject BOM"
        }

        It "Engine.ini has no UTF-8 BOM" {
            Test-HasBOM $script:EngineFile | Should -BeFalse -Because "UE5 INI parser can reject BOM"
        }

        It "GameUserSettings.ini has Embark section" {
            $content = Get-Content $script:GUSFile -Raw
            $content | Should -Match '\[/Script/EmbarkUserSettings\.EmbarkGameUserSettings\]'
        }

        It "GameUserSettings.ini has ScalabilityGroups section" {
            $content = Get-Content $script:GUSFile -Raw
            $content | Should -Match '\[ScalabilityGroups\]'
        }

        It "GameUserSettings.ini has SystemSettings section" {
            $content = Get-Content $script:GUSFile -Raw
            $content | Should -Match '\[SystemSettings\]'
        }

        It "GameUserSettings.ini has InputSettings section" {
            $content = Get-Content $script:GUSFile -Raw
            $content | Should -Match '\[/Script/Engine\.InputSettings\]'
        }

        It "Engine.ini has SystemSettings section" {
            $content = Get-Content $script:EngineFile -Raw
            $content | Should -Match '\[SystemSettings\]'
        }

        It "Engine.ini has ConsoleVariables section" {
            $content = Get-Content $script:EngineFile -Raw
            $content | Should -Match '\[ConsoleVariables\]'
        }

        It "Competitive shadow quality is Medium (sg=1)" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['ScalabilityGroups']['sg.ShadowQuality'] | Should -Be '1'
        }

        It "Texture quality is High (sg=2)" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['ScalabilityGroups']['sg.TextureQuality'] | Should -Be '2'
        }

        It "Effects quality is Low (sg=0)" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['ScalabilityGroups']['sg.EffectsQuality'] | Should -Be '0'
        }

        It "Resolution quality is 100 percent" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['ScalabilityGroups']['sg.ResolutionQuality'] | Should -Be '100.000000'
        }

        It "VSync is False in Embark section" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['/Script/EmbarkUserSettings.EmbarkGameUserSettings']['bUseVSync'] | Should -Be 'False'
        }

        It "Motion blur is disabled" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['/Script/EmbarkUserSettings.EmbarkGameUserSettings']['MotionBlurEnabled'] | Should -Be 'False'
        }

        It "DLSS Frame Generation is Off (NVIDIA test)" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['/Script/EmbarkUserSettings.EmbarkGameUserSettings']['DLSSFrameGenerationMode'] | Should -Be 'Off'
        }

        It "Reflex is Enabled+Boost (NVIDIA test)" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['/Script/EmbarkUserSettings.EmbarkGameUserSettings']['NvReflexMode'] | Should -Be 'Enabled+Boost'
        }

        It "FullscreenMode is 0 (exclusive fullscreen)" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['/Script/EmbarkUserSettings.EmbarkGameUserSettings']['FullscreenMode'] | Should -Be '0'
        }

        It "Mouse smoothing is disabled" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['/Script/Engine.InputSettings']['bEnableMouseSmoothing'] | Should -Be 'False'
        }

        It "Mouse acceleration is disabled" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['/Script/Engine.InputSettings']['bViewAccelerationEnabled'] | Should -Be 'False'
        }

        It "Depth of Field is off in SystemSettings" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['SystemSettings']['r.DepthOfFieldQuality'] | Should -Be '0'
        }

        It "Bloom is off in SystemSettings" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['SystemSettings']['r.BloomQuality'] | Should -Be '0'
        }

        It "Read-merge-write preserved non-performance keys from seed" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            # AudioQualityLevel from the seed should be preserved (not in our override list)
            $embark = $outSections['/Script/EmbarkUserSettings.EmbarkGameUserSettings']
            $embark.Keys | Should -Contain 'AudioQualityLevel'
        }

        It "SQ_CHECK markers emitted for config write" {
            $script:Output | Should -Match '\[SQ_CHECK_(OK|WARN|FAIL):ARC_CONFIG_FILES_WRITTEN'
        }

        It "SQ_CHECK markers emitted for settings applied" {
            $script:Output | Should -Match '\[SQ_CHECK_(OK|WARN|FAIL):ARC_SETTINGS_APPLIED'
        }

        It "SQ_CHECK markers emitted for EXE flags" {
            $script:Output | Should -Match '\[SQ_CHECK_(OK|WARN):ARC_EXE_FLAGS'
        }
    }

    # -----------------------------------------------------------------
    Context "Script source code correctness" {
        BeforeAll {
            $ScriptContent = Get-Content $ScriptFile -Raw
        }

        It "Script runs in headless mode" {
            $ScriptContent | Should -Match 'Initialize-SQEngine|SENSEQUALITY_HEADLESS'
        }

        It "Script uses PioneerGame config path (not ArcRaiders)" {
            $ScriptContent | Should -Match 'PioneerGame\\Saved\\Config'
            $ScriptContent | Should -Not -Match '\$env:LOCALAPPDATA\\ArcRaiders\\Saved'
        }

        It "Script uses read-merge-write pattern (not blind overwrite)" {
            $ScriptContent | Should -Match 'Read-IniFile'
            $ScriptContent | Should -Match 'Merge-IniSection'
        }

        It "Script writes UTF-8 without BOM" {
            $ScriptContent | Should -Match 'UTF8Encoding.*\$false'
        }

        It "Script sets config read-only after write" {
            $ScriptContent | Should -Match 'Lock-ConfigFile|IsReadOnly.*\$true'
        }

        It "Script backs up existing config before writing" {
            $ScriptContent | Should -Match 'Backup-ConfigFile|\.bak_'
        }

        It "Script does not use Set-Content for config files" {
            $ScriptContent | Should -Not -Match 'Set-Content.*GameUserSettings'
        }

        It "Script writes Embark section" {
            $ScriptContent | Should -Match 'EmbarkUserSettings\.EmbarkGameUserSettings'
        }

        It "Script writes ScalabilityGroups section" {
            $ScriptContent | Should -Match 'ScalabilityGroups'
        }

        It "Script sets DISABLEFULLSCREENOPTIMIZATIONS flag" {
            $ScriptContent | Should -Match 'Set-ExeCompatFlags|DISABLEFULLSCREENOPTIMIZATIONS'
        }
    }
}

# ===========================================================================
# ARC RAIDERS TESTS
# ===========================================================================
Describe "Arc Raiders GameUserSettings.ini" -Tag "arcraiders" {

    BeforeAll {
        $ProjectRoot = (Get-Location).Path
        $ScriptsDir = Join-Path $ProjectRoot "scripts"
        $ReferenceDir = Join-Path $ScriptsDir "reference-configs"
        $RefGUS = Join-Path $ReferenceDir "arcraiders-GameUserSettings.ini"
        $RefEngine = Join-Path $ReferenceDir "arcraiders-Engine.ini"
        $ScriptFile = Join-Path $ScriptsDir "06_ArcRaiders_Settings.ps1"

        # Helper: Check if a file starts with UTF-8 BOM (EF BB BF)
        function Test-HasBOM {
            param([string]$Path)
            $bytes = [System.IO.File]::ReadAllBytes($Path)
            return ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        }

        # Helper: Parse UE5 INI into ordered dict of section -> keys
        function Parse-IniSections {
            param([string]$Path)
            $sections = [ordered]@{}
            $currentSection = ""
            foreach ($line in (Get-Content $Path)) {
                if ($line -match '^\[(.+)\]$') {
                    $currentSection = $Matches[1]
                    if (-not $sections.Contains($currentSection)) {
                        $sections[$currentSection] = [ordered]@{}
                    }
                } elseif ($currentSection -and $line -match '^(.+?)=(.*)$') {
                    $sections[$currentSection][$Matches[1]] = $Matches[2]
                }
            }
            return $sections
        }

        # Parse reference configs
        $RefSections = Parse-IniSections -Path $RefGUS
        $RefEngineSections = Parse-IniSections -Path $RefEngine
    }

    # -----------------------------------------------------------------
    Context "Reference configs are valid" {
        It "GameUserSettings.ini reference file exists" {
            $RefGUS | Should -Exist
        }

        It "Engine.ini reference file exists" {
            $RefEngine | Should -Exist
        }

        It "Reference GameUserSettings.ini has Embark section" {
            $RefSections.Keys | Should -Contain '/Script/EmbarkUserSettings.EmbarkGameUserSettings'
        }

        It "Reference GameUserSettings.ini has ScalabilityGroups section" {
            $RefSections.Keys | Should -Contain 'ScalabilityGroups'
        }

        It "Reference GameUserSettings.ini has SystemSettings section" {
            $RefSections.Keys | Should -Contain 'SystemSettings'
        }

        It "Embark section has expected keys" {
            $embark = $RefSections['/Script/EmbarkUserSettings.EmbarkGameUserSettings']
            $embark.Keys | Should -Contain 'DLSSMode'
            $embark.Keys | Should -Contain 'NvReflexMode'
            $embark.Keys | Should -Contain 'FullscreenMode'
            $embark.Keys | Should -Contain 'bUseVSync'
            $embark.Keys | Should -Contain 'FrameRateLimit'
            $embark.Keys | Should -Contain 'MotionBlurEnabled'
            $embark.Keys | Should -Contain 'LensDistortionEnabled'
            $embark.Keys | Should -Contain 'RTXGIQuality'
        }

        It "ScalabilityGroups has all 11 sg. keys" {
            $scal = $RefSections['ScalabilityGroups']
            $scal.Keys | Should -Contain 'sg.ViewDistanceQuality'
            $scal.Keys | Should -Contain 'sg.ShadowQuality'
            $scal.Keys | Should -Contain 'sg.TextureQuality'
            $scal.Keys | Should -Contain 'sg.EffectsQuality'
            $scal.Keys | Should -Contain 'sg.FoliageQuality'
            $scal.Keys | Should -Contain 'sg.PostProcessQuality'
            $scal.Keys | Should -Contain 'sg.ReflectionQuality'
            $scal.Keys | Should -Contain 'sg.ShadingQuality'
            $scal.Keys | Should -Contain 'sg.GlobalIlluminationQuality'
            $scal.Keys | Should -Contain 'sg.AntiAliasingQuality'
            $scal.Keys | Should -Contain 'sg.ResolutionQuality'
        }

        It "SystemSettings has visual clarity keys" {
            $sys = $RefSections['SystemSettings']
            $sys.Keys | Should -Contain 'r.DepthOfFieldQuality'
            $sys.Keys | Should -Contain 'r.BloomQuality'
            $sys.Keys | Should -Contain 'r.LensFlareQuality'
            $sys.Keys | Should -Contain 'r.Tonemapper.Sharpen'
            $sys.Keys | Should -Contain 'r.Tonemapper.GrainQuantization'
        }

        It "Engine.ini reference has SystemSettings section" {
            $RefEngineSections.Keys | Should -Contain 'SystemSettings'
        }

        It "Engine.ini reference has ConsoleVariables section" {
            $RefEngineSections.Keys | Should -Contain 'ConsoleVariables'
        }
    }

    # -----------------------------------------------------------------
    Context "Script competitive settings use valid key names" {
        BeforeAll {
            $ScriptContent = Get-Content $ScriptFile -Raw

            # Extract Embark override keys from the ordered hashtable
            $ScriptEmbarkKeys = [regex]::Matches($ScriptContent, "\`$EmbarkOverrides\['(\w+)'\]") |
                ForEach-Object { $_.Groups[1].Value } |
                Select-Object -Unique

            # Extract ScalabilityGroups keys
            $ScriptSgKeys = [regex]::Matches($ScriptContent, "'(sg\.\w+)'") |
                ForEach-Object { $_.Groups[1].Value } |
                Select-Object -Unique

            # Extract SystemSettings keys from the script
            $ScriptSysKeys = [regex]::Matches($ScriptContent, "'(r\.\w+[\.\w]*)'") |
                ForEach-Object { $_.Groups[1].Value } |
                Select-Object -Unique

            # All reference keys by section
            $RefEmbarkKeys = $RefSections['/Script/EmbarkUserSettings.EmbarkGameUserSettings'].Keys
            $RefScalKeys = $RefSections['ScalabilityGroups'].Keys
            $RefSysKeys = $RefSections['SystemSettings'].Keys
            # Also include Engine.ini SystemSettings keys
            $RefEngSysKeys = $RefEngineSections['SystemSettings'].Keys
        }

        It "All Embark override keys in script exist in reference config" {
            $missingKeys = @()
            foreach ($key in $ScriptEmbarkKeys) {
                if ($key -notin $RefEmbarkKeys) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These Embark keys are not in the reference config: $($missingKeys -join ', ')"
        }

        It "All ScalabilityGroups keys in script exist in reference config" {
            $missingKeys = @()
            foreach ($key in $ScriptSgKeys) {
                if ($key -notin $RefScalKeys) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These sg. keys are not in the reference config: $($missingKeys -join ', ')"
        }

        It "All SystemSettings r.* keys in script exist in reference or Engine.ini" {
            $allRefSysKeys = @()
            if ($RefSysKeys) { $allRefSysKeys += $RefSysKeys }
            if ($RefEngSysKeys) { $allRefSysKeys += $RefEngSysKeys }
            $missingKeys = @()
            foreach ($key in $ScriptSysKeys) {
                if ($key -notin $allRefSysKeys) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These r.* keys are not in any reference config: $($missingKeys -join ', ')"
        }
    }

    # -----------------------------------------------------------------
    Context "Script output file format" {
        BeforeAll {
            # Create temp sandbox simulating PioneerGame config structure
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "sq-test-arcraiders-$(Get-Random)"
            $configDir = Join-Path $script:TempDir "PioneerGame\Saved\Config\WindowsClient"
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null

            # Seed with reference config to test read-merge-write
            Copy-Item $RefGUS (Join-Path $configDir "GameUserSettings.ini") -Force

            # Save original LOCALAPPDATA
            $script:OrigLocalAppData = $env:LOCALAPPDATA

            # Run the script in headless mode
            $env:SENSEQUALITY_HEADLESS = "1"
            $env:MONITOR_WIDTH = "1920"
            $env:MONITOR_HEIGHT = "1080"
            $env:MONITOR_REFRESH = "240"
            $env:NVIDIA_GPU = "1"
            $env:LOCALAPPDATA = $script:TempDir

            $scriptPath = Join-Path $ScriptsDir "06_ArcRaiders_Settings.ps1"
            $script:Output = & $scriptPath *>&1 | Out-String
            $script:GUSFile = Join-Path $configDir "GameUserSettings.ini"
            $script:EngineFile = Join-Path $configDir "Engine.ini"
        }

        AfterAll {
            $env:LOCALAPPDATA = $script:OrigLocalAppData
            $env:SENSEQUALITY_HEADLESS = ""
            if ($script:TempDir -and (Test-Path $script:TempDir)) {
                Get-ChildItem $script:TempDir -Recurse -File -ErrorAction SilentlyContinue |
                    ForEach-Object { if ($_.IsReadOnly) { $_.IsReadOnly = $false } }
                Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "GameUserSettings.ini output file exists" {
            $script:GUSFile | Should -Exist
        }

        It "Engine.ini output file exists" {
            $script:EngineFile | Should -Exist
        }

        It "GameUserSettings.ini has no UTF-8 BOM" {
            Test-HasBOM $script:GUSFile | Should -BeFalse -Because "UE5 INI parser can reject BOM"
        }

        It "Engine.ini has no UTF-8 BOM" {
            Test-HasBOM $script:EngineFile | Should -BeFalse -Because "UE5 INI parser can reject BOM"
        }

        It "GameUserSettings.ini has Embark section" {
            $content = Get-Content $script:GUSFile -Raw
            $content | Should -Match '\[/Script/EmbarkUserSettings\.EmbarkGameUserSettings\]'
        }

        It "GameUserSettings.ini has ScalabilityGroups section" {
            $content = Get-Content $script:GUSFile -Raw
            $content | Should -Match '\[ScalabilityGroups\]'
        }

        It "GameUserSettings.ini has SystemSettings section" {
            $content = Get-Content $script:GUSFile -Raw
            $content | Should -Match '\[SystemSettings\]'
        }

        It "GameUserSettings.ini has InputSettings section" {
            $content = Get-Content $script:GUSFile -Raw
            $content | Should -Match '\[/Script/Engine\.InputSettings\]'
        }

        It "Engine.ini has SystemSettings section" {
            $content = Get-Content $script:EngineFile -Raw
            $content | Should -Match '\[SystemSettings\]'
        }

        It "Engine.ini has ConsoleVariables section" {
            $content = Get-Content $script:EngineFile -Raw
            $content | Should -Match '\[ConsoleVariables\]'
        }

        It "Competitive shadow quality is Medium (sg=1)" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['ScalabilityGroups']['sg.ShadowQuality'] | Should -Be '1'
        }

        It "Texture quality is High (sg=2)" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['ScalabilityGroups']['sg.TextureQuality'] | Should -Be '2'
        }

        It "Effects quality is Low (sg=0)" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['ScalabilityGroups']['sg.EffectsQuality'] | Should -Be '0'
        }

        It "Resolution quality is 100 percent" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['ScalabilityGroups']['sg.ResolutionQuality'] | Should -Be '100.000000'
        }

        It "VSync is False in Embark section" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['/Script/EmbarkUserSettings.EmbarkGameUserSettings']['bUseVSync'] | Should -Be 'False'
        }

        It "Motion blur is disabled" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['/Script/EmbarkUserSettings.EmbarkGameUserSettings']['MotionBlurEnabled'] | Should -Be 'False'
        }

        It "DLSS Frame Generation is Off (NVIDIA test)" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['/Script/EmbarkUserSettings.EmbarkGameUserSettings']['DLSSFrameGenerationMode'] | Should -Be 'Off'
        }

        It "Reflex is Enabled+Boost (NVIDIA test)" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['/Script/EmbarkUserSettings.EmbarkGameUserSettings']['NvReflexMode'] | Should -Be 'Enabled+Boost'
        }

        It "FullscreenMode is 0 (exclusive fullscreen)" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['/Script/EmbarkUserSettings.EmbarkGameUserSettings']['FullscreenMode'] | Should -Be '0'
        }

        It "Mouse smoothing is disabled" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['/Script/Engine.InputSettings']['bEnableMouseSmoothing'] | Should -Be 'False'
        }

        It "Mouse acceleration is disabled" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['/Script/Engine.InputSettings']['bViewAccelerationEnabled'] | Should -Be 'False'
        }

        It "Depth of Field is off in SystemSettings" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['SystemSettings']['r.DepthOfFieldQuality'] | Should -Be '0'
        }

        It "Bloom is off in SystemSettings" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            $outSections['SystemSettings']['r.BloomQuality'] | Should -Be '0'
        }

        It "Read-merge-write preserved non-performance keys from seed" {
            $outSections = Parse-IniSections -Path $script:GUSFile
            # AudioQualityLevel from the seed should be preserved (not in our override list)
            $embark = $outSections['/Script/EmbarkUserSettings.EmbarkGameUserSettings']
            $embark.Keys | Should -Contain 'AudioQualityLevel'
        }

        It "SQ_CHECK markers emitted for config write" {
            $script:Output | Should -Match '\[SQ_CHECK_(OK|WARN|FAIL):ARC_CONFIG_FILES_WRITTEN'
        }

        It "SQ_CHECK markers emitted for settings applied" {
            $script:Output | Should -Match '\[SQ_CHECK_(OK|WARN|FAIL):ARC_SETTINGS_APPLIED'
        }

        It "SQ_CHECK markers emitted for EXE flags" {
            $script:Output | Should -Match '\[SQ_CHECK_(OK|WARN):ARC_EXE_FLAGS'
        }
    }

    # -----------------------------------------------------------------
    Context "Script source code correctness" {
        BeforeAll {
            $ScriptContent = Get-Content $ScriptFile -Raw
        }

        It "Script runs in headless mode" {
            $ScriptContent | Should -Match 'Initialize-SQEngine|SENSEQUALITY_HEADLESS'
        }

        It "Script uses PioneerGame config path (not ArcRaiders)" {
            $ScriptContent | Should -Match 'PioneerGame\\Saved\\Config'
            $ScriptContent | Should -Not -Match '\$env:LOCALAPPDATA\\ArcRaiders\\Saved'
        }

        It "Script uses read-merge-write pattern (not blind overwrite)" {
            $ScriptContent | Should -Match 'Read-IniFile'
            $ScriptContent | Should -Match 'Merge-IniSection'
        }

        It "Script writes UTF-8 without BOM" {
            $ScriptContent | Should -Match 'UTF8Encoding.*\$false'
        }

        It "Script sets config read-only after write" {
            $ScriptContent | Should -Match 'Lock-ConfigFile|IsReadOnly.*\$true'
        }

        It "Script backs up existing config before writing" {
            $ScriptContent | Should -Match 'Backup-ConfigFile|\.bak_'
        }

        It "Script does not use Set-Content for config files" {
            $ScriptContent | Should -Not -Match 'Set-Content.*GameUserSettings'
        }

        It "Script writes Embark section" {
            $ScriptContent | Should -Match 'EmbarkUserSettings\.EmbarkGameUserSettings'
        }

        It "Script writes ScalabilityGroups section" {
            $ScriptContent | Should -Match 'ScalabilityGroups'
        }

        It "Script sets DISABLEFULLSCREENOPTIMIZATIONS flag" {
            $ScriptContent | Should -Match 'Set-ExeCompatFlags|DISABLEFULLSCREENOPTIMIZATIONS'
        }
    }
}

# ===========================================================================
# CS2 TESTS
# ===========================================================================
Describe "CS2 autoexec.cfg" -Tag "cs2" {

    BeforeAll {
        $ProjectRoot = (Get-Location).Path
        $ScriptsDir = Join-Path $ProjectRoot "scripts"
        $ReferenceDir = Join-Path $ScriptsDir "reference-configs"
        $RefFile = Join-Path $ReferenceDir "cs2-autoexec.cfg"
        $ScriptFile = Join-Path $ScriptsDir "05_CS2_Settings.ps1"

        # Helper: Extract command names from CFG content.
        # Filters out comments, empty lines, and the 'echo' command.
        function Get-CfgCommands {
            param([string]$Content)
            $Content -split "`n" |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ -and $_ -notmatch '^\s*//' -and $_ -notmatch '^\s*$' } |
                ForEach-Object { ($_ -split '\s+')[0] } |
                Where-Object { $_ -ne 'echo' } |
                Select-Object -Unique
        }

        # Load reference commands
        $RefContent = Get-Content $RefFile -Raw
        $RefCommands = Get-CfgCommands $RefContent
    }

    # -----------------------------------------------------------------
    Context "Reference config is valid" {
        It "Reference file exists" {
            $RefFile | Should -Exist
        }

        It "Reference file uses valid CFG format (command value per line)" {
            $lines = Get-Content $RefFile |
                Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*//' }
            $lines.Count | Should -BeGreaterThan 0 -Because "Should have command lines"
            foreach ($line in $lines) {
                $line | Should -Match '^\s*\S+\s+.+' -Because "Each non-comment line should be: command value"
            }
        }

        It "Reference file uses no equals signs (CFG uses spaces)" {
            $lines = Get-Content $RefFile |
                Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*//' }
            foreach ($line in $lines) {
                $line | Should -Not -Match '^\w+=\w' -Because "CFG syntax is 'command value', not 'command=value'"
            }
        }

        It "Reference contains core competitive commands" {
            $RefCommands | Should -Contain "fps_max"
            $RefCommands | Should -Contain "rate"
            $RefCommands | Should -Contain "sensitivity"
            $RefCommands | Should -Contain "cl_crosshairstyle"
            $RefCommands | Should -Contain "viewmodel_fov"
            $RefCommands | Should -Contain "snd_mixahead"
        }
    }

    # -----------------------------------------------------------------
    Context "Script autoexec commands use valid names" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptFile -Raw

            # Extract the here-string that becomes autoexec.cfg.
            # The script uses: $AutoExecContent = @"..."@
            $hereStringMatch = [regex]::Match($scriptContent, '(?s)\$AutoExecContent\s*=\s*@"(.+?)"@')
            $autoexecBlock = $hereStringMatch.Groups[1].Value

            # Parse command names from the autoexec content
            $ScriptCommands = Get-CfgCommands $autoexecBlock
        }

        It "Here-string was successfully extracted from script" {
            $autoexecBlock | Should -Not -BeNullOrEmpty -Because "The autoexec here-string must be extractable from the script source"
        }

        It "All autoexec commands exist in the reference config" {
            $missingCmds = @()
            foreach ($cmd in $ScriptCommands) {
                if ($cmd -notin $RefCommands) {
                    $missingCmds += $cmd
                }
            }
            $missingCmds | Should -BeNullOrEmpty -Because "These commands are not in the reference config: $($missingCmds -join ', ')"
        }

        It "Script sets rate to maximum (786432)" {
            $autoexecBlock | Should -Match 'rate\s+786432'
        }

        It "Script sets static crosshair (cl_crosshairstyle 4)" {
            $autoexecBlock | Should -Match 'cl_crosshairstyle\s+4'
        }

        It "Script sets viewmodel_fov to max (68)" {
            $autoexecBlock | Should -Match 'viewmodel_fov\s+68'
        }

        It "Script sets fps_max to 0 (uncapped)" {
            $autoexecBlock | Should -Match 'fps_max\s+0' -Because "fps_max should be uncapped for lowest input latency"
        }
    }

    # -----------------------------------------------------------------
    Context "Script autoexec content format" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptFile -Raw
            $hereStringMatch = [regex]::Match($scriptContent, '(?s)\$AutoExecContent\s*=\s*@"(.+?)"@')
            $autoexecBlock = $hereStringMatch.Groups[1].Value

            # Get non-comment, non-empty command lines
            $CommandLines = $autoexecBlock -split "`n" |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ -and $_ -notmatch '^\s*//' -and $_ -notmatch '^\s*$' }
        }

        It "All command lines use CFG syntax (no equals signs)" {
            foreach ($line in $CommandLines) {
                $line | Should -Not -Match '^\w+=\S' -Because "CFG uses spaces, not equals: $line"
            }
        }

        It "All command lines have a value after the command name" {
            foreach ($line in $CommandLines) {
                $line | Should -Match '^\S+\s+.+' -Because "Each line should be: command value. Got: $line"
            }
        }

        It "Autoexec does not include deprecated launch options as commands" {
            $autoexecBlock | Should -Not -Match '^\s*-tickrate' -Because "-tickrate is a launch option, not a convar"
            $autoexecBlock | Should -Not -Match '^\s*-threads' -Because "-threads is a launch option, not a convar"
            $autoexecBlock | Should -Not -Match '^\s*-novid' -Because "-novid is a launch option, not a convar"
        }
    }

    # -----------------------------------------------------------------
    Context "Script source code correctness" {
        BeforeAll {
            $ScriptContent = Get-Content $ScriptFile -Raw
        }

        It "Script runs in headless mode" {
            $ScriptContent | Should -Match 'Initialize-SQEngine|SENSEQUALITY_HEADLESS'
        }

        It "Script writes autoexec.cfg via Set-Content" {
            $ScriptContent | Should -Match 'Set-Content.*AutoExec'
        }

        It "Script backs up existing autoexec.cfg before writing" {
            $ScriptContent | Should -Match 'Backup-ConfigFile|\.bak_'
        }

        It "Script creates cfg directory if missing" {
            $ScriptContent | Should -Match 'New-Item.*Directory.*CfgDir'
        }

        It "Script sets Steam launch options for CS2 (App ID 730)" {
            $ScriptContent | Should -Match 'Apps\\730'
            $ScriptContent | Should -Match 'LaunchOptions'
        }

        It "Launch options include +exec autoexec.cfg" {
            $ScriptContent | Should -Match '\+exec autoexec\.cfg'
        }

        It "Launch options do NOT include deprecated flags (-tickrate, -threads)" {
            $launchMatch = [regex]::Match($ScriptContent, '\$LaunchOptions\s*=\s*"([^"]+)"')
            $launchOpts = $launchMatch.Groups[1].Value
            $launchOpts | Should -Not -Match '-tickrate'
            $launchOpts | Should -Not -Match '-threads'
            $launchOpts | Should -Not -Match '-freq'
        }

        It "Script sets EXE compatibility flags (HIGHDPIAWARE, DISABLEFULLSCREENOPTIMIZATIONS)" {
            $ScriptContent | Should -Match 'Set-ExeCompatFlags'
        }

        It "Script searches multiple Steam library paths" {
            $ScriptContent | Should -Match 'SteamLibraryPaths'
            $pathCount = [regex]::Matches($ScriptContent, 'Counter-Strike Global Offensive').Count
            $pathCount | Should -BeGreaterOrEqual 3
        }
    }
}

# ===========================================================================
# BATTLEFIELD 6 TESTS
# ===========================================================================
Describe "Battlefield 6 PROFSAVE_profile" -Tag "bf6" {

    BeforeAll {
        $ProjectRoot = (Get-Location).Path
        $ScriptsDir = Join-Path $ProjectRoot "scripts"
        $ReferenceDir = Join-Path $ScriptsDir "reference-configs"
        $RefFile = Join-Path $ReferenceDir "bf6-PROFSAVE_profile"
        $ScriptFile = Join-Path $ScriptsDir "17_Battlefield6_Settings.ps1"

        # Helper: Parse PROFSAVE key-value lines into hashtable
        function Parse-Profsave {
            param([string]$Path)
            $result = @{}
            foreach ($line in (Get-Content $Path)) {
                if ($line -match '^(\S+)\s+(.+)$') {
                    $result[$Matches[1]] = $Matches[2]
                }
            }
            return $result
        }

        # Load reference keys
        $RefSettings = Parse-Profsave -Path $RefFile
        $RefKeys = @($RefSettings.Keys)
    }

    # -----------------------------------------------------------------
    Context "Reference config is valid" {
        It "Reference file exists" {
            $RefFile | Should -Exist
        }

        It "Reference file uses Frostbite key-value format" {
            $lines = Get-Content $RefFile | Where-Object { $_ -match '\S' }
            $lines.Count | Should -BeGreaterThan 0 -Because "Should have settings lines"
            foreach ($line in $lines) {
                $line | Should -Match '^\S+\s+.+$' -Because "Each line should be: GstRender.Key Value"
            }
        }

        It "Reference has core competitive keys" {
            $RefKeys | Should -Contain "GstRender.TextureQuality"
            $RefKeys | Should -Contain "GstRender.ShadowQuality"
            $RefKeys | Should -Contain "GstRender.VSyncMode"
            $RefKeys | Should -Contain "GstRender.FutureFrameRendering"
            $RefKeys | Should -Contain "GstRender.NvidiaLowLatency"
            $RefKeys | Should -Contain "GstRender.MotionBlurWorld"
            $RefKeys | Should -Contain "GstRender.ChromaticAberration"
        }
    }

    # -----------------------------------------------------------------
    Context "Script competitive settings use valid key names" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptFile -Raw
            # Extract keys from the CompetitiveSettings ordered hashtable
            $ScriptKeys = [regex]::Matches($scriptContent, "'(GstRender\.\w+)'") |
                ForEach-Object { $_.Groups[1].Value } |
                Select-Object -Unique
        }

        It "All script GstRender keys exist in reference config" {
            $missingKeys = @()
            foreach ($key in $ScriptKeys) {
                if ($key -notin $RefKeys) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These keys are not in the reference config: $($missingKeys -join ', ')"
        }
    }

    # -----------------------------------------------------------------
    Context "Script output file format" {
        BeforeAll {
            # Create temp sandbox simulating Documents\Battlefield 6\settings\
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "sq-test-bf6-$(Get-Random)"
            $settingsDir = Join-Path $script:TempDir "Documents\Battlefield 6\settings"
            New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null

            # Seed with reference config to test read-merge-write
            Copy-Item $RefFile (Join-Path $settingsDir "PROFSAVE_profile") -Force

            # Save original USERPROFILE
            $script:OrigUserProfile = $env:USERPROFILE

            # Run the script in headless mode with overridden USERPROFILE
            $env:SENSEQUALITY_HEADLESS = "1"
            $env:MONITOR_WIDTH = "1920"
            $env:MONITOR_HEIGHT = "1080"
            $env:MONITOR_REFRESH = "240"
            $env:NVIDIA_GPU = "1"
            $env:USERPROFILE = $script:TempDir

            $scriptPath = Join-Path $ScriptsDir "17_Battlefield6_Settings.ps1"
            $script:Output = & $scriptPath *>&1 | Out-String
            $script:OutputFile = Join-Path $settingsDir "PROFSAVE_profile"
        }

        AfterAll {
            # Restore USERPROFILE and clean up
            $env:USERPROFILE = $script:OrigUserProfile
            $env:SENSEQUALITY_HEADLESS = ""
            if ($script:TempDir -and (Test-Path $script:TempDir)) {
                Get-ChildItem $script:TempDir -Recurse -File -ErrorAction SilentlyContinue |
                    ForEach-Object { if ($_.IsReadOnly) { $_.IsReadOnly = $false } }
                Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Output file exists" {
            $script:OutputFile | Should -Exist
        }

        It "Output file uses key-value format" {
            $lines = Get-Content $script:OutputFile | Where-Object { $_ -match '\S' }
            foreach ($line in $lines) {
                $line | Should -Match '^\S+\s+.+$' -Because "Each line should be: Key Value"
            }
        }

        It "Output has all competitive keys from reference" {
            $outputSettings = Parse-Profsave -Path $script:OutputFile
            $outputKeys = @($outputSettings.Keys)
            foreach ($key in $RefKeys) {
                $outputKeys | Should -Contain $key -Because "$key should be in output config"
            }
        }

        It "SQ_CHECK markers are emitted for config write" {
            $script:Output | Should -Match '\[SQ_CHECK_(OK|WARN|FAIL):BF6_CONFIG_WRITTEN'
        }

        It "SQ_CHECK markers are emitted for EXE flags" {
            $script:Output | Should -Match '\[SQ_CHECK_(OK|WARN|FAIL):BF6_EXE_FLAGS'
        }

        It "VSync is off in output" {
            $outputSettings = Parse-Profsave -Path $script:OutputFile
            $outputSettings['GstRender.VSyncMode'] | Should -Be '0'
        }

        It "Shadow quality is low in output" {
            $outputSettings = Parse-Profsave -Path $script:OutputFile
            $outputSettings['GstRender.ShadowQuality'] | Should -Be '0'
        }

        It "Future frame rendering is on in output" {
            $outputSettings = Parse-Profsave -Path $script:OutputFile
            $outputSettings['GstRender.FutureFrameRendering'] | Should -Be '1'
        }

        It "Motion blur world is off in output" {
            $outputSettings = Parse-Profsave -Path $script:OutputFile
            $outputSettings['GstRender.MotionBlurWorld'] | Should -Be '0.000000'
        }

        It "Frame generation is off in output" {
            $outputSettings = Parse-Profsave -Path $script:OutputFile
            $outputSettings['GstRender.FrameGeneration'] | Should -Be '0'
        }

        It "Output file is read-only" {
            (Get-Item $script:OutputFile).IsReadOnly | Should -BeTrue -Because "Config should be locked after write"
        }
    }
}

# ===========================================================================
# Marvel Rivals (marvelrivals) -- UE5 INI config
# ===========================================================================

Describe "Marvel Rivals GameUserSettings.ini" -Tag "marvelrivals" {

    BeforeAll {
        $ProjectRoot = (Get-Location).Path
        $ScriptsDir = Join-Path $ProjectRoot "scripts"
        $ReferenceDir = Join-Path $ScriptsDir "reference-configs"
        $RefGUS = Join-Path $ReferenceDir "marvelrivals-GameUserSettings.ini"
        $RefEngine = Join-Path $ReferenceDir "marvelrivals-Engine.ini"
        $ScriptFile = Join-Path $ScriptsDir "18_MarvelRivals_Settings.ps1"

        # Helper: Check if a file starts with UTF-8 BOM (EF BB BF)
        function Test-HasBOM {
            param([string]$Path)
            $bytes = [System.IO.File]::ReadAllBytes($Path)
            return ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        }

        # Helper: Parse UE5 INI into ordered dict of section -> keys
        function Parse-IniSections {
            param([string]$Path)
            $sections = [ordered]@{}
            $currentSection = ""
            foreach ($line in (Get-Content $Path)) {
                if ($line -match '^\[(.+)\]$') {
                    $currentSection = $Matches[1]
                    if (-not $sections.Contains($currentSection)) {
                        $sections[$currentSection] = [ordered]@{}
                    }
                } elseif ($currentSection -and $line -match '^(.+?)=(.*)$') {
                    $sections[$currentSection][$Matches[1]] = $Matches[2]
                }
            }
            return $sections
        }

        # Helper: Run the Marvel Rivals script in a temp sandbox
        function Invoke-MarvelRivalsScript {
            param(
                [string]$TempRoot,
                [string]$NvidiaGpu = "1",
                [bool]$SeedConfig = $true
            )
            $configDir = Join-Path $TempRoot "Marvel\Saved\Config\Windows"
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null

            if ($SeedConfig) {
                Copy-Item $RefGUS (Join-Path $configDir "GameUserSettings.ini") -Force
                Copy-Item $RefEngine (Join-Path $configDir "Engine.ini") -Force
            }

            $origLocal = $env:LOCALAPPDATA
            $env:LOCALAPPDATA = $TempRoot
            $env:SENSEQUALITY_HEADLESS = "1"
            $env:MONITOR_WIDTH = "1920"
            $env:MONITOR_HEIGHT = "1080"
            $env:MONITOR_REFRESH = "240"
            $env:NVIDIA_GPU = $NvidiaGpu

            $output = & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $ScriptFile 2>&1

            $env:LOCALAPPDATA = $origLocal
            $env:SENSEQUALITY_HEADLESS = $null
            $env:MONITOR_WIDTH = $null
            $env:MONITOR_HEIGHT = $null
            $env:MONITOR_REFRESH = $null
            $env:NVIDIA_GPU = $null

            return @{
                OutputGUS    = Join-Path $configDir "GameUserSettings.ini"
                OutputEngine = Join-Path $configDir "Engine.ini"
                ScriptOutput = $output
            }
        }

        # Helper: Clean up temp dir (clears read-only flags first)
        function Remove-TempSandbox {
            param([string]$Path)
            if ($Path -and (Test-Path $Path)) {
                Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue |
                    ForEach-Object { if ($_.IsReadOnly) { $_.IsReadOnly = $false } }
                Remove-Item -Recurse -Force $Path -ErrorAction SilentlyContinue
            }
        }

        # Parse reference configs
        $RefSections = Parse-IniSections -Path $RefGUS
        $RefEngineSections = Parse-IniSections -Path $RefEngine
    }

    # -----------------------------------------------------------------
    Context "Reference configs are valid" {
        It "GameUserSettings.ini reference file exists" {
            $RefGUS | Should -Exist
        }

        It "Engine.ini reference file exists" {
            $RefEngine | Should -Exist
        }

        It "Reference GameUserSettings.ini has ScalabilityGroups section" {
            $RefSections.Keys | Should -Contain 'ScalabilityGroups'
        }

        It "Reference GameUserSettings.ini has GameUserSettings section" {
            $RefSections.Keys | Should -Contain '/Script/Engine.GameUserSettings'
        }

        It "Reference GameUserSettings.ini has Marvel section" {
            $RefSections.Keys | Should -Contain '/Script/Marvel.MarvelGameUserSettings'
        }

        It "ScalabilityGroups has all 11 sg. keys" {
            $scal = $RefSections['ScalabilityGroups']
            $scal.Keys | Should -Contain 'sg.ViewDistanceQuality'
            $scal.Keys | Should -Contain 'sg.ShadowQuality'
            $scal.Keys | Should -Contain 'sg.TextureQuality'
            $scal.Keys | Should -Contain 'sg.EffectsQuality'
            $scal.Keys | Should -Contain 'sg.FoliageQuality'
            $scal.Keys | Should -Contain 'sg.PostProcessQuality'
            $scal.Keys | Should -Contain 'sg.ReflectionQuality'
            $scal.Keys | Should -Contain 'sg.ShadingQuality'
            $scal.Keys | Should -Contain 'sg.GlobalIlluminationQuality'
            $scal.Keys | Should -Contain 'sg.AntiAliasingQuality'
            $scal.Keys | Should -Contain 'sg.ResolutionQuality'
        }

        It "Marvel section has display and upscaling keys" {
            $marvel = $RefSections['/Script/Marvel.MarvelGameUserSettings']
            $marvel.Keys | Should -Contain 'bUseVSync'
            $marvel.Keys | Should -Contain 'FullscreenMode'
            $marvel.Keys | Should -Contain 'FrameRateLimit'
            $marvel.Keys | Should -Contain 'ResolutionSizeX'
            $marvel.Keys | Should -Contain 'ResolutionSizeY'
            $marvel.Keys | Should -Contain 'AntiAliasingSuperSamplingMode'
            $marvel.Keys | Should -Contain 'SuperSamplingQuality'
            $marvel.Keys | Should -Contain 'bNvidiaReflex'
            $marvel.Keys | Should -Contain 'bDlssFrameGeneration'
        }

        It "Engine.ini reference has SystemSettings section" {
            $RefEngineSections.Keys | Should -Contain 'SystemSettings'
        }

        It "Engine.ini reference has RendererSettings section" {
            $RefEngineSections.Keys | Should -Contain '/Script/Engine.RendererSettings'
        }

        It "Engine.ini reference has InputSettings section" {
            $RefEngineSections.Keys | Should -Contain '/Script/Engine.InputSettings'
        }
    }

    # -----------------------------------------------------------------
    Context "Script competitive settings use valid key names" {
        BeforeAll {
            $ScriptContent = Get-Content $ScriptFile -Raw

            # Extract ScalabilityGroups keys
            $ScriptSgKeys = [regex]::Matches($ScriptContent, "'(sg\.\w+)'") |
                ForEach-Object { $_.Groups[1].Value } |
                Select-Object -Unique

            # Extract Marvel override keys from the ordered hashtable
            $ScriptMarvelKeys = [regex]::Matches($ScriptContent, "\`$MarvelOverrides\s*=\s*\[ordered\]@\{([\s\S]*?)\}") |
                ForEach-Object { $_.Groups[1].Value } |
                ForEach-Object {
                    [regex]::Matches($_, "'(\w+)'\s*=") |
                        ForEach-Object { $_.Groups[1].Value }
                } |
                Select-Object -Unique

            # All reference keys by section
            $RefScalKeys = $RefSections['ScalabilityGroups'].Keys
            $RefMarvelKeys = $RefSections['/Script/Marvel.MarvelGameUserSettings'].Keys
        }

        It "Extracted ScalabilityGroups keys are non-empty" {
            $ScriptSgKeys.Count | Should -BeGreaterThan 0 -Because "Regex must extract sg. keys from script"
        }

        It "Extracted Marvel override keys are non-empty" {
            $ScriptMarvelKeys.Count | Should -BeGreaterThan 0 -Because "Regex must extract Marvel keys from script"
        }

        It "All ScalabilityGroups keys in script exist in reference config" {
            $missingKeys = @()
            foreach ($key in $ScriptSgKeys) {
                if ($key -notin $RefScalKeys) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These sg. keys are not in the reference config: $($missingKeys -join ', ')"
        }

        It "All Marvel override keys in script exist in reference config" {
            $missingKeys = @()
            foreach ($key in $ScriptMarvelKeys) {
                if ($key -notin $RefMarvelKeys) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These Marvel keys are not in the reference config: $($missingKeys -join ', ')"
        }
    }

    # -----------------------------------------------------------------
    Context "Script output -- NVIDIA GPU (seeded config)" {
        BeforeAll {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "sq-test-mr-nvidia-$(Get-Random)"
            $script:Result = Invoke-MarvelRivalsScript -TempRoot $script:TempDir -NvidiaGpu "1" -SeedConfig $true
        }

        AfterAll { Remove-TempSandbox -Path $script:TempDir }

        It "GameUserSettings.ini output file exists" {
            $script:Result.OutputGUS | Should -Exist
        }

        It "Engine.ini output file exists" {
            $script:Result.OutputEngine | Should -Exist
        }

        It "GameUserSettings.ini has no UTF-8 BOM" {
            Test-HasBOM -Path $script:Result.OutputGUS | Should -BeFalse -Because "UE5 INI should be UTF-8 without BOM"
        }

        It "Engine.ini has no UTF-8 BOM" {
            Test-HasBOM -Path $script:Result.OutputEngine | Should -BeFalse -Because "UE5 INI should be UTF-8 without BOM"
        }

        It "Output GameUserSettings.ini is parseable" {
            { Parse-IniSections -Path $script:Result.OutputGUS } | Should -Not -Throw
        }

        It "Output has ScalabilityGroups section" {
            $output = Parse-IniSections -Path $script:Result.OutputGUS
            $output.Keys | Should -Contain 'ScalabilityGroups'
        }

        It "Output has Marvel section" {
            $output = Parse-IniSections -Path $script:Result.OutputGUS
            $output.Keys | Should -Contain '/Script/Marvel.MarvelGameUserSettings'
        }

        It "Output has Engine GameUserSettings section" {
            $output = Parse-IniSections -Path $script:Result.OutputGUS
            $output.Keys | Should -Contain '/Script/Engine.GameUserSettings'
        }

        It "Shadow quality is Low (0)" {
            $output = Parse-IniSections -Path $script:Result.OutputGUS
            $output['ScalabilityGroups']['sg.ShadowQuality'] | Should -Be '0'
        }

        It "Post processing is Low (0)" {
            $output = Parse-IniSections -Path $script:Result.OutputGUS
            $output['ScalabilityGroups']['sg.PostProcessQuality'] | Should -Be '0'
        }

        It "V-Sync is off" {
            $output = Parse-IniSections -Path $script:Result.OutputGUS
            $output['/Script/Marvel.MarvelGameUserSettings']['bUseVSync'] | Should -Be 'False'
        }

        It "Fullscreen mode is exclusive (0)" {
            $output = Parse-IniSections -Path $script:Result.OutputGUS
            $output['/Script/Marvel.MarvelGameUserSettings']['FullscreenMode'] | Should -Be '0'
        }

        It "Frame rate limit is uncapped" {
            $output = Parse-IniSections -Path $script:Result.OutputGUS
            $output['/Script/Marvel.MarvelGameUserSettings']['FrameRateLimit'] | Should -Be '0.000000'
        }

        It "DLSS mode is set to 2 (NVIDIA)" {
            $output = Parse-IniSections -Path $script:Result.OutputGUS
            $output['/Script/Marvel.MarvelGameUserSettings']['AntiAliasingSuperSamplingMode'] | Should -Be '2'
        }

        It "Upscaling quality is Quality (3)" {
            $output = Parse-IniSections -Path $script:Result.OutputGUS
            $output['/Script/Marvel.MarvelGameUserSettings']['SuperSamplingQuality'] | Should -Be '3'
        }

        It "NVIDIA Reflex is enabled" {
            $output = Parse-IniSections -Path $script:Result.OutputGUS
            $output['/Script/Marvel.MarvelGameUserSettings']['bNvidiaReflex'] | Should -Be 'True'
        }

        It "XeLowLatency is disabled" {
            $output = Parse-IniSections -Path $script:Result.OutputGUS
            $output['/Script/Marvel.MarvelGameUserSettings']['bXeLowLatency'] | Should -Be 'False'
        }

        It "Frame generation is off" {
            $output = Parse-IniSections -Path $script:Result.OutputGUS
            $output['/Script/Marvel.MarvelGameUserSettings']['bDlssFrameGeneration'] | Should -Be 'False'
        }

        It "GameUserSettings.ini is read-only" {
            (Get-Item $script:Result.OutputGUS).IsReadOnly | Should -BeTrue -Because "Config should be locked after write"
        }

        It "Engine.ini is NOT read-only (game does not rewrite it)" {
            (Get-Item $script:Result.OutputEngine).IsReadOnly | Should -BeFalse -Because "Engine.ini does not need read-only lock"
        }

        It "Engine.ini has motion blur disabled" {
            $eng = Parse-IniSections -Path $script:Result.OutputEngine
            $eng['/Script/Engine.RendererSettings']['r.MotionBlurQuality'] | Should -Be '0'
        }

        It "Engine.ini has volumetric fog disabled" {
            $eng = Parse-IniSections -Path $script:Result.OutputEngine
            $eng['SystemSettings']['r.VolumetricFog'] | Should -Be '0'
        }

        It "Engine.ini has mouse smoothing disabled" {
            $eng = Parse-IniSections -Path $script:Result.OutputEngine
            $eng['/Script/Engine.InputSettings']['bEnableMouseSmoothing'] | Should -Be 'False'
        }

        It "Read-merge-write preserves seeded Internationalization section" {
            $output = Parse-IniSections -Path $script:Result.OutputGUS
            $output.Keys | Should -Contain 'Internationalization'
            $output['Internationalization']['Culture'] | Should -Be 'en'
        }

        It "Script emitted MR_EXE_FLAGS marker" {
            $script:Result.ScriptOutput -join "`n" | Should -Match '\[SQ_CHECK_(OK|WARN):MR_EXE_FLAGS'
        }

        It "Script emitted MR_CONFIG_WRITTEN OK marker" {
            $script:Result.ScriptOutput -join "`n" | Should -Match '\[SQ_CHECK_OK:MR_CONFIG_WRITTEN\]'
        }

        It "Script emitted MR_SETTINGS_APPLIED OK marker" {
            $script:Result.ScriptOutput -join "`n" | Should -Match '\[SQ_CHECK_OK:MR_SETTINGS_APPLIED\]'
        }
    }

    # -----------------------------------------------------------------
    Context "Script output -- AMD GPU path" {
        BeforeAll {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "sq-test-mr-amd-$(Get-Random)"
            $script:Result = Invoke-MarvelRivalsScript -TempRoot $script:TempDir -NvidiaGpu "0" -SeedConfig $true
        }

        AfterAll { Remove-TempSandbox -Path $script:TempDir }

        It "FSR mode is set to 3 (AMD)" {
            $output = Parse-IniSections -Path $script:Result.OutputGUS
            $output['/Script/Marvel.MarvelGameUserSettings']['AntiAliasingSuperSamplingMode'] | Should -Be '3'
        }

        It "NVIDIA Reflex is disabled for AMD" {
            $output = Parse-IniSections -Path $script:Result.OutputGUS
            $output['/Script/Marvel.MarvelGameUserSettings']['bNvidiaReflex'] | Should -Be 'False'
        }

        It "Script emitted MR_CONFIG_WRITTEN OK marker" {
            $script:Result.ScriptOutput -join "`n" | Should -Match '\[SQ_CHECK_OK:MR_CONFIG_WRITTEN\]'
        }
    }

    # -----------------------------------------------------------------
    Context "Script output -- fresh config (no seeded files)" {
        BeforeAll {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "sq-test-mr-fresh-$(Get-Random)"
            $script:Result = Invoke-MarvelRivalsScript -TempRoot $script:TempDir -NvidiaGpu "1" -SeedConfig $false
        }

        AfterAll { Remove-TempSandbox -Path $script:TempDir }

        It "GameUserSettings.ini is created from scratch" {
            $script:Result.OutputGUS | Should -Exist
        }

        It "Engine.ini is created from scratch" {
            $script:Result.OutputEngine | Should -Exist
        }

        It "Fresh config has ScalabilityGroups section" {
            $output = Parse-IniSections -Path $script:Result.OutputGUS
            $output.Keys | Should -Contain 'ScalabilityGroups'
        }

        It "Fresh config has Marvel section" {
            $output = Parse-IniSections -Path $script:Result.OutputGUS
            $output.Keys | Should -Contain '/Script/Marvel.MarvelGameUserSettings'
        }

        It "Script emitted MR_CONFIG_WRITTEN OK marker" {
            $script:Result.ScriptOutput -join "`n" | Should -Match '\[SQ_CHECK_OK:MR_CONFIG_WRITTEN\]'
        }

        It "Script emitted MR_SETTINGS_APPLIED OK marker" {
            $script:Result.ScriptOutput -join "`n" | Should -Match '\[SQ_CHECK_OK:MR_SETTINGS_APPLIED\]'
        }
    }
}

# ===========================================================================
# LEAGUE OF LEGENDS TESTS
# ===========================================================================
Describe "League of Legends game.cfg" -Tag "lol" {

    BeforeAll {
        $ProjectRoot = (Get-Location).Path
        $ScriptsDir = Join-Path $ProjectRoot "scripts"
        $ReferenceDir = Join-Path $ScriptsDir "reference-configs"
        $RefFile = Join-Path $ReferenceDir "lol-game.cfg"
        $ScriptFile = Join-Path $ScriptsDir "19_LeagueOfLegends_Settings.ps1"

        # Helper: Check if a file starts with UTF-8 BOM (EF BB BF)
        function Test-HasBOM {
            param([string]$Path)
            $bytes = [System.IO.File]::ReadAllBytes($Path)
            return ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        }

        # Helper: Parse INI into ordered dict of section -> keys
        function Parse-IniSections {
            param([string]$Path)
            $sections = [ordered]@{}
            $currentSection = ""
            foreach ($line in (Get-Content $Path)) {
                if ($line -match '^\[(.+)\]$') {
                    $currentSection = $Matches[1]
                    if (-not $sections.Contains($currentSection)) {
                        $sections[$currentSection] = [ordered]@{}
                    }
                } elseif ($currentSection -and $line -match '^(.+?)=(.*)$') {
                    $sections[$currentSection][$Matches[1]] = $Matches[2]
                }
            }
            return $sections
        }

        # Helper: Run the LoL script in a temp sandbox
        function Invoke-LolScript {
            param(
                [string]$TempRoot,
                [bool]$SeedConfig = $true
            )
            # LoL config is at <install>\Game\Config\game.cfg
            $configDir = Join-Path $TempRoot "Game\Config"
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null

            if ($SeedConfig) {
                Copy-Item $RefFile (Join-Path $configDir "game.cfg") -Force
            }

            $origLolPath = $env:LOL_PATH
            $env:LOL_PATH = $TempRoot
            $env:SENSEQUALITY_HEADLESS = "1"
            $env:MONITOR_WIDTH = "1920"
            $env:MONITOR_HEIGHT = "1080"
            $env:MONITOR_REFRESH = "240"
            $env:NVIDIA_GPU = "1"

            $output = & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $ScriptFile 2>&1

            $env:LOL_PATH = $origLolPath
            $env:SENSEQUALITY_HEADLESS = $null
            $env:MONITOR_WIDTH = $null
            $env:MONITOR_HEIGHT = $null
            $env:MONITOR_REFRESH = $null
            $env:NVIDIA_GPU = $null

            return @{
                OutputCfg    = Join-Path $configDir "game.cfg"
                ScriptOutput = $output
            }
        }

        # Helper: Clean up temp dir (clears read-only flags first)
        function Remove-TempSandbox {
            param([string]$Path)
            if ($Path -and (Test-Path $Path)) {
                Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue |
                    ForEach-Object { if ($_.IsReadOnly) { $_.IsReadOnly = $false } }
                Remove-Item -Recurse -Force $Path -ErrorAction SilentlyContinue
            }
        }

        # Parse reference config
        $RefSections = Parse-IniSections -Path $RefFile
    }

    # -----------------------------------------------------------------
    Context "Reference config is valid" {
        It "Reference file exists" {
            $RefFile | Should -Exist
        }

        It "Reference file has General section" {
            $RefSections.Keys | Should -Contain 'General'
        }

        It "Reference file has Performance section" {
            $RefSections.Keys | Should -Contain 'Performance'
        }

        It "Reference file has HUD section" {
            $RefSections.Keys | Should -Contain 'HUD'
        }

        It "General section has display keys" {
            $gen = $RefSections['General']
            $gen.Keys | Should -Contain 'WindowMode'
            $gen.Keys | Should -Contain 'Width'
            $gen.Keys | Should -Contain 'Height'
            $gen.Keys | Should -Contain 'WaitForVerticalSync'
        }

        It "Performance section has all expected keys" {
            $perf = $RefSections['Performance']
            $perf.Keys | Should -Contain 'ShadowsEnabled'
            $perf.Keys | Should -Contain 'ShadowQuality'
            $perf.Keys | Should -Contain 'CharacterQuality'
            $perf.Keys | Should -Contain 'EnvironmentQuality'
            $perf.Keys | Should -Contain 'EffectsQuality'
            $perf.Keys | Should -Contain 'FrameCapType'
            $perf.Keys | Should -Contain 'GraphicsSlider'
            $perf.Keys | Should -Contain 'EnableParticleOptimizations'
            $perf.Keys | Should -Contain 'BudgetOverdrawAverage'
        }
    }

    # -----------------------------------------------------------------
    Context "Script competitive settings use valid key names" {
        BeforeAll {
            $ScriptContent = Get-Content $ScriptFile -Raw

            # Extract General override keys
            $generalBlock = [regex]::Match($ScriptContent, '(?s)\$GeneralOverrides\s*=\s*@\{(.+?)\}')
            $ScriptGeneralKeys = @()
            if ($generalBlock.Success) {
                $ScriptGeneralKeys = [regex]::Matches($generalBlock.Groups[1].Value, "'(\w+)'\s*=") |
                    ForEach-Object { $_.Groups[1].Value } |
                    Select-Object -Unique
            }

            # Extract Performance override keys
            $perfBlock = [regex]::Match($ScriptContent, '(?s)\$PerformanceOverrides\s*=\s*@\{(.+?)\}')
            $ScriptPerfKeys = @()
            if ($perfBlock.Success) {
                $ScriptPerfKeys = [regex]::Matches($perfBlock.Groups[1].Value, "'(\w+)'\s*=") |
                    ForEach-Object { $_.Groups[1].Value } |
                    Select-Object -Unique
            }

            # Extract HUD override keys
            $hudBlock = [regex]::Match($ScriptContent, '(?s)\$HudOverrides\s*=\s*@\{(.+?)\}')
            $ScriptHudKeys = @()
            if ($hudBlock.Success) {
                $ScriptHudKeys = [regex]::Matches($hudBlock.Groups[1].Value, "'(\w+)'\s*=") |
                    ForEach-Object { $_.Groups[1].Value } |
                    Select-Object -Unique
            }

            $RefGeneralKeys = $RefSections['General'].Keys
            $RefPerfKeys = $RefSections['Performance'].Keys
            $RefHudKeys = $RefSections['HUD'].Keys
        }

        It "Extracted General override keys are non-empty" {
            $ScriptGeneralKeys.Count | Should -BeGreaterThan 0 -Because "Regex must extract General keys from script"
        }

        It "Extracted Performance override keys are non-empty" {
            $ScriptPerfKeys.Count | Should -BeGreaterThan 0 -Because "Regex must extract Performance keys from script"
        }

        It "All General override keys exist in reference config" {
            $missingKeys = @()
            foreach ($key in $ScriptGeneralKeys) {
                if ($key -notin $RefGeneralKeys) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These General keys are not in the reference config: $($missingKeys -join ', ')"
        }

        It "All Performance override keys exist in reference config" {
            $missingKeys = @()
            foreach ($key in $ScriptPerfKeys) {
                if ($key -notin $RefPerfKeys) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These Performance keys are not in the reference config: $($missingKeys -join ', ')"
        }

        It "All HUD override keys exist in reference config" {
            $missingKeys = @()
            foreach ($key in $ScriptHudKeys) {
                if ($key -notin $RefHudKeys) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These HUD keys are not in the reference config: $($missingKeys -join ', ')"
        }
    }

    # -----------------------------------------------------------------
    Context "Script output -- seeded config (read-merge-write)" {
        BeforeAll {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "sq-test-lol-seeded-$(Get-Random)"
            $script:Result = Invoke-LolScript -TempRoot $script:TempDir -SeedConfig $true
        }

        AfterAll { Remove-TempSandbox -Path $script:TempDir }

        It "game.cfg output file exists" {
            $script:Result.OutputCfg | Should -Exist
        }

        It "game.cfg has no UTF-8 BOM" {
            Test-HasBOM -Path $script:Result.OutputCfg | Should -BeFalse -Because "INI should be UTF-8 without BOM"
        }

        It "Output is parseable" {
            { Parse-IniSections -Path $script:Result.OutputCfg } | Should -Not -Throw
        }

        It "Output has General section" {
            $output = Parse-IniSections -Path $script:Result.OutputCfg
            $output.Keys | Should -Contain 'General'
        }

        It "Output has Performance section" {
            $output = Parse-IniSections -Path $script:Result.OutputCfg
            $output.Keys | Should -Contain 'Performance'
        }

        It "Output has HUD section" {
            $output = Parse-IniSections -Path $script:Result.OutputCfg
            $output.Keys | Should -Contain 'HUD'
        }

        It "Shadows are disabled (ShadowsEnabled=0)" {
            $output = Parse-IniSections -Path $script:Result.OutputCfg
            $output['Performance']['ShadowsEnabled'] | Should -Be '0'
        }

        It "FPS is uncapped (FrameCapType=10)" {
            $output = Parse-IniSections -Path $script:Result.OutputCfg
            $output['Performance']['FrameCapType'] | Should -Be '10'
        }

        It "V-Sync is off" {
            $output = Parse-IniSections -Path $script:Result.OutputCfg
            $output['General']['WaitForVerticalSync'] | Should -Be '0'
        }

        It "Window mode is fullscreen (0)" {
            $output = Parse-IniSections -Path $script:Result.OutputCfg
            $output['General']['WindowMode'] | Should -Be '0'
        }

        It "GraphicsSlider is Custom (-1)" {
            $output = Parse-IniSections -Path $script:Result.OutputCfg
            $output['Performance']['GraphicsSlider'] | Should -Be '-1'
        }

        It "Auto performance settings is off" {
            $output = Parse-IniSections -Path $script:Result.OutputCfg
            $output['Performance']['AutoPerformanceSettings'] | Should -Be '0'
        }

        It "Character quality is Low (1)" {
            $output = Parse-IniSections -Path $script:Result.OutputCfg
            $output['Performance']['CharacterQuality'] | Should -Be '1'
        }

        It "Particle optimizations are enabled" {
            $output = Parse-IniSections -Path $script:Result.OutputCfg
            $output['Performance']['EnableParticleOptimizations'] | Should -Be '1'
        }

        It "game.cfg is read-only" {
            (Get-Item $script:Result.OutputCfg).IsReadOnly | Should -BeTrue -Because "Config should be locked to prevent LoL from overwriting"
        }

        It "Read-merge-write preserves seeded Volume section" {
            $output = Parse-IniSections -Path $script:Result.OutputCfg
            $output.Keys | Should -Contain 'Volume'
            $output['Volume']['MasterVolume'] | Should -Be '0.5000'
        }

        It "Read-merge-write preserves seeded FloatingText section" {
            $output = Parse-IniSections -Path $script:Result.OutputCfg
            $output.Keys | Should -Contain 'FloatingText'
        }

        It "Read-merge-write preserves Width and Height" {
            $output = Parse-IniSections -Path $script:Result.OutputCfg
            $output['General']['Width'] | Should -Be '1920'
            $output['General']['Height'] | Should -Be '1080'
        }

        It "Read-merge-write preserves CfgVersion" {
            $output = Parse-IniSections -Path $script:Result.OutputCfg
            $output['General']['CfgVersion'] | Should -Not -BeNullOrEmpty
        }

        It "Script emitted LOL_EXE_FLAGS marker" {
            $script:Result.ScriptOutput -join "`n" | Should -Match '\[SQ_CHECK_(OK|WARN):LOL_EXE_FLAGS'
        }

        It "Script emitted LOL_CONFIG_WRITTEN OK marker" {
            $script:Result.ScriptOutput -join "`n" | Should -Match '\[SQ_CHECK_OK:LOL_CONFIG_WRITTEN\]'
        }
    }

    # -----------------------------------------------------------------
    Context "Script output -- fresh config (no existing game.cfg)" {
        BeforeAll {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "sq-test-lol-fresh-$(Get-Random)"
            $script:Result = Invoke-LolScript -TempRoot $script:TempDir -SeedConfig $false
        }

        AfterAll { Remove-TempSandbox -Path $script:TempDir }

        It "game.cfg is created from scratch" {
            $script:Result.OutputCfg | Should -Exist
        }

        It "Fresh config has General section" {
            $output = Parse-IniSections -Path $script:Result.OutputCfg
            $output.Keys | Should -Contain 'General'
        }

        It "Fresh config has Performance section" {
            $output = Parse-IniSections -Path $script:Result.OutputCfg
            $output.Keys | Should -Contain 'Performance'
        }

        It "Fresh config has shadows disabled" {
            $output = Parse-IniSections -Path $script:Result.OutputCfg
            $output['Performance']['ShadowsEnabled'] | Should -Be '0'
        }

        It "Fresh config has uncapped FPS" {
            $output = Parse-IniSections -Path $script:Result.OutputCfg
            $output['Performance']['FrameCapType'] | Should -Be '10'
        }

        It "Script emitted LOL_CONFIG_WRITTEN OK marker" {
            $script:Result.ScriptOutput -join "`n" | Should -Match '\[SQ_CHECK_OK:LOL_CONFIG_WRITTEN\]'
        }
    }
}

# ===========================================================================
# DOTA 2 TESTS -- VIDEO.TXT (KeyValues format)
# ===========================================================================
Describe "Dota 2 video.txt" -Tag "dota2" {

    BeforeAll {
        $ProjectRoot = (Get-Location).Path
        $ScriptsDir = Join-Path $ProjectRoot "scripts"
        $ReferenceDir = Join-Path $ScriptsDir "reference-configs"
        $RefVideoFile = Join-Path $ReferenceDir "dota2-video.txt"
        $RefAutoexecFile = Join-Path $ReferenceDir "dota2-autoexec.cfg"
        $ScriptFile = Join-Path $ScriptsDir "20_Dota2_Settings.ps1"

        # Helper: Parse KeyValues format into hashtable
        function Get-KeyValuesConfig {
            param([string]$Content)
            $config = @{}
            $kvMatches = [regex]::Matches($Content, '"([^"]+)"\s+"([^"]*)"')
            foreach ($match in $kvMatches) {
                $key = $match.Groups[1].Value
                $value = $match.Groups[2].Value
                if ($key -ne "VideoConfig") {
                    $config[$key] = $value
                }
            }
            return $config
        }

        # Helper: Extract command names from CFG content
        function Get-CfgCommands {
            param([string]$Content)
            $Content -split "`n" |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ -and $_ -notmatch '^\s*//' -and $_ -notmatch '^\s*$' } |
                ForEach-Object { ($_ -split '\s+')[0] } |
                Where-Object { $_ -ne 'echo' } |
                Select-Object -Unique
        }

        # Load reference configs
        $RefVideoContent = Get-Content $RefVideoFile -Raw
        $RefVideoKeys = (Get-KeyValuesConfig $RefVideoContent).Keys
        $RefAutoexecContent = Get-Content $RefAutoexecFile -Raw
        $RefAutoexecCommands = Get-CfgCommands $RefAutoexecContent
    }

    # -----------------------------------------------------------------
    Context "Reference video.txt is valid" {
        It "Reference video.txt file exists" {
            $RefVideoFile | Should -Exist
        }

        It "Reference video.txt uses KeyValues format" {
            $RefVideoContent | Should -Match '"VideoConfig"'
            $RefVideoContent | Should -Match '\{'
            $RefVideoContent | Should -Match '\}'
        }

        It "Reference video.txt contains core competitive keys" {
            $RefVideoKeys | Should -Contain "setting.mat_vsync"
            $RefVideoKeys | Should -Contain "setting.fullscreen"
            $RefVideoKeys | Should -Contain "setting.gpu_mem_level"
            $RefVideoKeys | Should -Contain "setting.cpu_level"
            $RefVideoKeys | Should -Contain "setting.r_ambient_occlusion"
            $RefVideoKeys | Should -Contain "setting.r_grass"
            $RefVideoKeys | Should -Contain "setting.mat_queue_mode"
        }

        It "Reference video.txt has resolution keys" {
            $RefVideoKeys | Should -Contain "setting.defaultres"
            $RefVideoKeys | Should -Contain "setting.defaultresheight"
        }
    }

    # -----------------------------------------------------------------
    Context "Reference autoexec.cfg is valid" {
        It "Reference autoexec.cfg file exists" {
            $RefAutoexecFile | Should -Exist
        }

        It "Reference autoexec.cfg uses CFG format (command value per line)" {
            $lines = Get-Content $RefAutoexecFile |
                Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*//' }
            $lines.Count | Should -BeGreaterThan 0
            foreach ($line in $lines) {
                $line | Should -Match '^\s*\S+\s+.+' -Because "Each non-comment line should be: command value"
            }
        }

        It "Reference autoexec.cfg contains core competitive commands" {
            $RefAutoexecCommands | Should -Contain "fps_max"
            $RefAutoexecCommands | Should -Contain "rate"
            $RefAutoexecCommands | Should -Contain "cl_cmdrate"
            $RefAutoexecCommands | Should -Contain "cl_updaterate"
            $RefAutoexecCommands | Should -Contain "mat_vsync"
            $RefAutoexecCommands | Should -Contain "mat_queue_mode"
        }
    }

    # -----------------------------------------------------------------
    Context "Script video.txt settings use valid key names" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptFile -Raw

            # Extract the competitiveSettings ordered hashtable keys
            $settingsBlock = [regex]::Match($scriptContent, '(?s)\$competitiveSettings\s*=\s*\[ordered\]@\{(.+?)\}')
            $ScriptVideoKeys = @()
            if ($settingsBlock.Success) {
                $ScriptVideoKeys = [regex]::Matches($settingsBlock.Groups[1].Value, '"(setting\.[^"]+)"') |
                    ForEach-Object { $_.Groups[1].Value } |
                    Select-Object -Unique
            }
        }

        It "Extracted video.txt setting keys from script" {
            $ScriptVideoKeys.Count | Should -BeGreaterThan 0 -Because "Regex must extract setting keys from competitiveSettings"
        }

        It "All video.txt setting keys exist in the reference config" {
            $missingKeys = @()
            foreach ($key in $ScriptVideoKeys) {
                if ($key -notin $RefVideoKeys) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These keys are not in the reference video.txt: $($missingKeys -join ', ')"
        }
    }

    # -----------------------------------------------------------------
    Context "Script autoexec commands use valid names" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptFile -Raw

            # Extract the here-string that becomes autoexec.cfg
            $hereStringMatch = [regex]::Match($scriptContent, '(?s)\$AutoExecContent\s*=\s*@"(.+?)"@')
            $autoexecBlock = $hereStringMatch.Groups[1].Value

            # Parse command names from the autoexec content
            $ScriptAutoexecCommands = Get-CfgCommands $autoexecBlock
        }

        It "Here-string was successfully extracted from script" {
            $autoexecBlock | Should -Not -BeNullOrEmpty -Because "The autoexec here-string must be extractable from the script source"
        }

        It "All autoexec commands exist in the reference config" {
            $missingCmds = @()
            foreach ($cmd in $ScriptAutoexecCommands) {
                if ($cmd -notin $RefAutoexecCommands) {
                    $missingCmds += $cmd
                }
            }
            $missingCmds | Should -BeNullOrEmpty -Because "These commands are not in the reference autoexec.cfg: $($missingCmds -join ', ')"
        }

        It "Script sets fps_max to 0 (uncapped)" {
            $autoexecBlock | Should -Match 'fps_max\s+0' -Because "fps_max should be uncapped for lowest input latency"
        }

        It "Script sets rate to maximum (786432)" {
            $autoexecBlock | Should -Match 'rate\s+786432'
        }

        It "Script sets mat_vsync to 0" {
            $autoexecBlock | Should -Match 'mat_vsync\s+0'
        }
    }

    # -----------------------------------------------------------------
    Context "Script autoexec content format" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptFile -Raw
            $hereStringMatch = [regex]::Match($scriptContent, '(?s)\$AutoExecContent\s*=\s*@"(.+?)"@')
            $autoexecBlock = $hereStringMatch.Groups[1].Value

            $CommandLines = $autoexecBlock -split "`n" |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ -and $_ -notmatch '^\s*//' -and $_ -notmatch '^\s*$' }
        }

        It "All command lines use CFG syntax (no equals signs)" {
            foreach ($line in $CommandLines) {
                $line | Should -Not -Match '^\w+=\S' -Because "CFG uses spaces, not equals: $line"
            }
        }

        It "All command lines have a value after the command name" {
            foreach ($line in $CommandLines) {
                $line | Should -Match '^\S+\s+.+' -Because "Each line should be: command value. Got: $line"
            }
        }
    }

    # -----------------------------------------------------------------
    Context "Script source code correctness" {
        BeforeAll {
            $ScriptContent = Get-Content $ScriptFile -Raw
        }

        It "Script runs in headless mode" {
            $ScriptContent | Should -Match 'Initialize-SQEngine|SENSEQUALITY_HEADLESS'
        }

        It "Script writes video.txt (read-merge-write)" {
            $ScriptContent | Should -Match 'VideoTxtPath|video\.txt'
        }

        It "Script writes autoexec.cfg via Set-Content" {
            $ScriptContent | Should -Match 'Set-Content.*AutoExec'
        }

        It "Script backs up existing configs before writing" {
            $ScriptContent | Should -Match 'Backup-ConfigFile'
        }

        It "Script creates cfg directory if missing" {
            $ScriptContent | Should -Match 'New-Item.*Directory.*CfgDir'
        }

        It "Script sets Steam launch options for Dota 2 (App ID 570)" {
            $ScriptContent | Should -Match 'Apps\\570'
            $ScriptContent | Should -Match 'LaunchOptions'
        }

        It "Launch options include +exec autoexec.cfg" {
            $ScriptContent | Should -Match '\+exec autoexec\.cfg'
        }

        It "Script sets EXE compatibility flags" {
            $ScriptContent | Should -Match 'Set-ExeCompatFlags'
        }

        It "Script searches multiple Steam library paths" {
            $ScriptContent | Should -Match 'SteamLibraryPaths'
            $pathCount = [regex]::Matches($ScriptContent, 'dota 2 beta').Count
            $pathCount | Should -BeGreaterOrEqual 3
        }

        It "Script does NOT set video.txt to read-only" {
            $ScriptContent | Should -Not -Match 'Lock-ConfigFile.*VideoTxt'
        }

        It "Script preserves user resolution (read-merge-write)" {
            $ScriptContent | Should -Match 'existingConfig'
            $ScriptContent | Should -Match 'mergedConfig'
        }

        It "Script emits all expected SQ_CHECK markers" {
            $ScriptContent | Should -Match 'DOTA2_CONFIG_WRITTEN'
            $ScriptContent | Should -Match 'DOTA2_AUTOEXEC_WRITTEN'
            $ScriptContent | Should -Match 'DOTA2_EXE_FLAGS'
            $ScriptContent | Should -Match 'DOTA2_LAUNCH_OPTIONS'
        }
    }
}

# ===========================================================================
# EA SPORTS FC 26 TESTS
# ===========================================================================
Describe "EA Sports FC 26 fcsetup.ini" -Tag "eafc26" {

    BeforeAll {
        $ProjectRoot = (Get-Location).Path
        $ScriptsDir = Join-Path $ProjectRoot "scripts"
        $ReferenceDir = Join-Path $ScriptsDir "reference-configs"
        $RefFile = Join-Path $ReferenceDir "eafc26-fcsetup.ini"
        $ScriptFile = Join-Path $ScriptsDir "24_EAFC26_Settings.ps1"

        # Helper: Parse fcsetup.ini key-value lines into hashtable
        function Parse-FcSetup {
            param([string]$Path)
            $result = @{}
            foreach ($line in (Get-Content $Path)) {
                if ($line -match '^\s*(\S+)\s*=\s*(.+?)\s*$') {
                    $result[$Matches[1]] = $Matches[2]
                }
            }
            return $result
        }

        # Load reference keys
        $RefSettings = Parse-FcSetup -Path $RefFile
        $RefKeys = @($RefSettings.Keys)
    }

    # -----------------------------------------------------------------
    Context "Reference config is valid" {
        It "Reference file exists" {
            $RefFile | Should -Exist
        }

        It "Reference file uses KEY = VALUE format" {
            $lines = Get-Content $RefFile | Where-Object { $_ -match '\S' }
            $lines.Count | Should -BeGreaterThan 0 -Because "Should have settings lines"
            foreach ($line in $lines) {
                $line | Should -Match '^\s*\S+\s*=\s*.+$' -Because "Each line should be: KEY = VALUE"
            }
        }

        It "Reference has core competitive keys" {
            $RefKeys | Should -Contain "WAITFORVSYNC"
            $RefKeys | Should -Contain "MAX_FRAME_RATE"
            $RefKeys | Should -Contain "RENDERING_QUALITY"
            $RefKeys | Should -Contain "DYNAMIC_AO_QUALITY"
            $RefKeys | Should -Contain "MOTION_BLUR"
            $RefKeys | Should -Contain "STRAND_BASED_HAIR"
            $RefKeys | Should -Contain "RENDERING_SCALE"
        }
    }

    # -----------------------------------------------------------------
    Context "Script competitive settings use valid key names" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptFile -Raw
            # Extract keys from the CompetitiveSettings ordered hashtable
            # Matches lines like: 'WAITFORVSYNC' = '0'
            $ScriptKeys = [regex]::Matches($scriptContent, "'([A-Z_]+)'\s*=") |
                ForEach-Object { $_.Groups[1].Value } |
                Select-Object -Unique
        }

        It "All script config keys exist in reference config" {
            $missingKeys = @()
            foreach ($key in $ScriptKeys) {
                if ($key -notin $RefKeys) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These keys are not in the reference config: $($missingKeys -join ', ')"
        }
    }

    # -----------------------------------------------------------------
    Context "Script output file format" {
        BeforeAll {
            # Create temp sandbox simulating %LOCALAPPDATA%\EA SPORTS FC 26\
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "sq-test-eafc26-$(Get-Random)"
            $configDir = Join-Path $script:TempDir "EA SPORTS FC 26"
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null

            # Seed with reference config to test read-merge-write
            Copy-Item $RefFile (Join-Path $configDir "fcsetup.ini") -Force

            # Save original LOCALAPPDATA
            $script:OrigLocalAppData = $env:LOCALAPPDATA

            # Run the script in headless mode with overridden LOCALAPPDATA
            $env:SENSEQUALITY_HEADLESS = "1"
            $env:MONITOR_WIDTH = "1920"
            $env:MONITOR_HEIGHT = "1080"
            $env:MONITOR_REFRESH = "240"
            $env:NVIDIA_GPU = "1"
            $env:LOCALAPPDATA = $script:TempDir

            $scriptPath = Join-Path $ScriptsDir "24_EAFC26_Settings.ps1"
            $script:Output = & $scriptPath *>&1 | Out-String
            $script:OutputFile = Join-Path $configDir "fcsetup.ini"
        }

        AfterAll {
            # Restore LOCALAPPDATA and clean up
            $env:LOCALAPPDATA = $script:OrigLocalAppData
            $env:SENSEQUALITY_HEADLESS = ""
            if ($script:TempDir -and (Test-Path $script:TempDir)) {
                Get-ChildItem $script:TempDir -Recurse -File -ErrorAction SilentlyContinue |
                    ForEach-Object { if ($_.IsReadOnly) { $_.IsReadOnly = $false } }
                Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Output file exists" {
            $script:OutputFile | Should -Exist
        }

        It "Output file uses KEY = VALUE format" {
            $lines = Get-Content $script:OutputFile | Where-Object { $_ -match '\S' }
            $lines.Count | Should -BeGreaterThan 0
            foreach ($line in $lines) {
                $line | Should -Match '^\s*\S+\s*=\s*.+$' -Because "Each line should be: KEY = VALUE"
            }
        }

        It "Output file has no UTF-8 BOM" {
            $bytes = [System.IO.File]::ReadAllBytes($script:OutputFile)
            ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -Be $false
        }

        It "Output has VSync off" {
            $settings = Parse-FcSetup -Path $script:OutputFile
            $settings['WAITFORVSYNC'] | Should -Be '0'
        }

        It "Output has uncapped frame rate" {
            $settings = Parse-FcSetup -Path $script:OutputFile
            $settings['MAX_FRAME_RATE'] | Should -Be '0'
        }

        It "Output has Medium rendering quality" {
            $settings = Parse-FcSetup -Path $script:OutputFile
            $settings['RENDERING_QUALITY'] | Should -Be '1'
        }

        It "Output has motion blur off" {
            $settings = Parse-FcSetup -Path $script:OutputFile
            $settings['MOTION_BLUR'] | Should -Be '0'
        }

        It "Output has ambient occlusion low" {
            $settings = Parse-FcSetup -Path $script:OutputFile
            $settings['DYNAMIC_AO_QUALITY'] | Should -Be '0'
        }

        It "Output has strand-based hair off" {
            $settings = Parse-FcSetup -Path $script:OutputFile
            $settings['STRAND_BASED_HAIR'] | Should -Be '0'
        }

        It "Output has render scale at native" {
            $settings = Parse-FcSetup -Path $script:OutputFile
            $settings['RENDERING_SCALE'] | Should -Be '1.0'
        }

        It "Output has fullscreen exclusive" {
            $settings = Parse-FcSetup -Path $script:OutputFile
            $settings['FULLSCREEN'] | Should -Be '1'
            $settings['WINDOWED_BORDERLESS'] | Should -Be '0'
        }

        It "Output has refresh rate matching monitor" {
            $settings = Parse-FcSetup -Path $script:OutputFile
            $settings['REFRESH_RATE'] | Should -Be '240'
        }

        It "Output file is read-only" {
            (Get-Item $script:OutputFile).IsReadOnly | Should -Be $true
        }

        It "Script emitted SQ_CHECK markers" {
            $script:Output | Should -Match '\[SQ_CHECK_(OK|WARN):EAFC26_EXE_FLAGS'
            $script:Output | Should -Match '\[SQ_CHECK_OK:EAFC26_CONFIG_WRITTEN\]'
        }
    }

    # -----------------------------------------------------------------
    Context "Script structure validation" {
        BeforeAll {
            $ScriptContent = Get-Content $ScriptFile -Raw
        }

        It "Script uses SQEngine shared module" {
            $ScriptContent | Should -Match 'SQEngine\.ps1'
            $ScriptContent | Should -Match 'Initialize-SQEngine'
        }

        It "Script uses read-merge-write pattern" {
            $ScriptContent | Should -Match 'existingSettings'
            $ScriptContent | Should -Match 'CompetitiveSettings'
        }

        It "Script sets config to read-only" {
            $ScriptContent | Should -Match 'Lock-ConfigFile'
        }

        It "Script creates backup before writing" {
            $ScriptContent | Should -Match 'Backup-ConfigFile'
        }

        It "Script writes UTF-8 without BOM" {
            $ScriptContent | Should -Match 'UTF8Encoding.*\$false'
        }

        It "Script emits all expected SQ_CHECK markers" {
            $ScriptContent | Should -Match 'EAFC26_CONFIG_WRITTEN'
            $ScriptContent | Should -Match 'EAFC26_EXE_FLAGS'
        }

        It "Guide text matches config values" {
            # VSync Off matches WAITFORVSYNC = 0
            $ScriptContent | Should -Match "VSync\s+:\s+Off"
            # Rendering Quality Medium matches RENDERING_QUALITY = 1
            $ScriptContent | Should -Match "Rendering Quality\s+:\s+Medium"
            # Motion Blur Off matches MOTION_BLUR = 0
            $ScriptContent | Should -Match "Motion Blur\s+:\s+Off"
            # Ambient Occlusion Low matches DYNAMIC_AO_QUALITY = 0
            $ScriptContent | Should -Match "Ambient Occlusion\s+:\s+Low"
            # Strand-Based Hair Off matches STRAND_BASED_HAIR = 0
            $ScriptContent | Should -Match "Strand-Based Hair\s+:\s+Off"
        }
    }
}

# ===========================================================================
# MARATHON TESTS
# ===========================================================================
Describe "Marathon cvars.xml" -Tag "marathon" {

    BeforeAll {
        $ProjectRoot = (Get-Location).Path
        $ScriptsDir = Join-Path $ProjectRoot "scripts"
        $ReferenceDir = Join-Path $ScriptsDir "reference-configs"
        $RefFile = Join-Path $ReferenceDir "marathon-cvars.xml"
        $ScriptFile = Join-Path $ScriptsDir "25_Marathon_Settings.ps1"
    }

    # -----------------------------------------------------------------
    Context "Reference config is valid" {
        It "Reference file exists" {
            $RefFile | Should -Exist
        }

        It "Reference file is valid XML" {
            { [xml](Get-Content $RefFile -Raw) } | Should -Not -Throw
        }

        It "Reference has <body> root element" {
            $xml = [xml](Get-Content $RefFile -Raw)
            $xml.body | Should -Not -BeNullOrEmpty
        }

        It "Reference has graphics namespace" {
            $xml = [xml](Get-Content $RefFile -Raw)
            $graphicsNs = $xml.body.namespace | Where-Object { $_.name -eq 'graphics' }
            $graphicsNs | Should -Not -BeNullOrEmpty
        }

        It "Reference has audio namespace" {
            $xml = [xml](Get-Content $RefFile -Raw)
            $audioNs = $xml.body.namespace | Where-Object { $_.name -eq 'audio' }
            $audioNs | Should -Not -BeNullOrEmpty
        }

        It "Reference has gameplay namespace" {
            $xml = [xml](Get-Content $RefFile -Raw)
            $gameplayNs = $xml.body.namespace | Where-Object { $_.name -eq 'gameplay' }
            $gameplayNs | Should -Not -BeNullOrEmpty
        }

        It "Reference graphics namespace has expected performance keys" {
            $xml = [xml](Get-Content $RefFile -Raw)
            $graphicsNs = $xml.body.namespace | Where-Object { $_.name -eq 'graphics' }
            $cvarNames = @($graphicsNs.cvar | ForEach-Object { $_.name })

            $expectedKeys = @(
                'master', 'anti_aliasing_mode', 'ssao_mode', 'ssao_async_mode',
                'shadow_quality', 'environment_detail', 'character_detail',
                'texture_quality', 'texture_anisotropy_level', 'foliage_detail',
                'local_light_shadows', 'foliage_shadows_mode', 'hdr_output',
                'atmosphere_lighting_detail', 'framerate_cap_enabled',
                'low_latency_mode', 'lighting_resolution',
                'render_resolution_scaling_mode', 'render_resolution_percentage',
                'framerate_cap', 'target_framerate'
            )

            foreach ($key in $expectedKeys) {
                $cvarNames | Should -Contain $key -Because "Performance key '$key' must exist in reference config"
            }
        }

        It "Reference graphics namespace has resolution and display keys" {
            $xml = [xml](Get-Content $RefFile -Raw)
            $graphicsNs = $xml.body.namespace | Where-Object { $_.name -eq 'graphics' }
            $cvarNames = @($graphicsNs.cvar | ForEach-Object { $_.name })

            $preserveKeys = @(
                'fullscreen_resolution_width', 'fullscreen_resolution_height',
                'fullscreen_refresh_rate_numerator', 'fullscreen_refresh_rate_denominator',
                'windowed_resolution_width', 'windowed_resolution_height',
                'window_mode', 'gamma_control', 'version'
            )

            foreach ($key in $preserveKeys) {
                $cvarNames | Should -Contain $key -Because "Preserve key '$key' must exist in reference config"
            }
        }
    }

    # -----------------------------------------------------------------
    Context "Script competitive settings use valid key names" {
        BeforeAll {
            $ScriptContent = Get-Content $ScriptFile -Raw

            # Extract competitive setting keys from the ordered hashtable
            # Matches lines like:  master                        = '0'
            #                      anti_aliasing_mode            = '2'
            $ScriptKeys = [regex]::Matches($ScriptContent, "(?m)^\s+(\w+)\s+=\s+'[^']*'") |
                ForEach-Object { $_.Groups[1].Value } |
                Where-Object { $_ -notin @('CompetitiveSettings', 'low_latency_mode') } |
                Select-Object -Unique

            # Also capture the low_latency_mode key set conditionally
            if ($ScriptContent -match "CompetitiveSettings\['low_latency_mode'\]") {
                $ScriptKeys += 'low_latency_mode'
            }

            # Load reference cvar names from graphics namespace
            $refXml = [xml](Get-Content $RefFile -Raw)
            $refGraphicsNs = $refXml.body.namespace | Where-Object { $_.name -eq 'graphics' }
            $RefCvarNames = @($refGraphicsNs.cvar | ForEach-Object { $_.name })
        }

        It "Script extracted competitive setting keys" {
            $ScriptKeys.Count | Should -BeGreaterThan 15 -Because "Script should write 15+ competitive settings"
        }

        It "All competitive setting keys exist in the reference config" {
            $missingKeys = @()
            foreach ($key in $ScriptKeys) {
                if ($key -notin $RefCvarNames) {
                    $missingKeys += $key
                }
            }
            $missingKeys | Should -BeNullOrEmpty -Because "These keys are not in the reference config: $($missingKeys -join ', ')"
        }
    }

    # -----------------------------------------------------------------
    Context "Script output file format (read-merge-write)" {
        BeforeAll {
            # Create temp sandbox simulating %APPDATA%\Bungie\Marathon\prefs
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "sq-test-marathon-$(Get-Random)"
            $prefsDir = Join-Path $script:TempDir "Bungie\Marathon\prefs"
            New-Item -ItemType Directory -Path $prefsDir -Force | Out-Null

            # Seed with reference config to test read-merge-write
            Copy-Item $RefFile (Join-Path $prefsDir "cvars.xml") -Force

            # Save original APPDATA
            $script:OrigAppData = $env:APPDATA

            # Run the script in headless mode with overridden APPDATA
            $env:SENSEQUALITY_HEADLESS = "1"
            $env:MONITOR_WIDTH = "1920"
            $env:MONITOR_HEIGHT = "1080"
            $env:MONITOR_REFRESH = "240"
            $env:NVIDIA_GPU = "1"
            $env:APPDATA = $script:TempDir

            $scriptPath = Join-Path $ScriptsDir "25_Marathon_Settings.ps1"
            $script:Output = & $scriptPath *>&1 | Out-String
            $script:OutputFile = Join-Path $prefsDir "cvars.xml"
        }

        AfterAll {
            # Restore APPDATA and clean up
            $env:APPDATA = $script:OrigAppData
            $env:SENSEQUALITY_HEADLESS = ""
            if ($script:TempDir -and (Test-Path $script:TempDir)) {
                Get-ChildItem $script:TempDir -Recurse -File -ErrorAction SilentlyContinue |
                    ForEach-Object { if ($_.IsReadOnly) { $_.IsReadOnly = $false } }
                Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Output file exists" {
            $script:OutputFile | Should -Exist
        }

        It "Output file has no UTF-8 BOM" {
            $bytes = [System.IO.File]::ReadAllBytes($script:OutputFile)
            $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
            $hasBom | Should -BeFalse -Because "XML files should not have a UTF-8 BOM"
        }

        It "Output file is valid XML" {
            { [xml](Get-Content $script:OutputFile -Raw) } | Should -Not -Throw
        }

        It "Output file has <body> root" {
            $xml = [xml](Get-Content $script:OutputFile -Raw)
            $xml.body | Should -Not -BeNullOrEmpty
        }

        It "Output file has graphics namespace" {
            $xml = [xml](Get-Content $script:OutputFile -Raw)
            $graphicsNs = $xml.body.namespace | Where-Object { $_.name -eq 'graphics' }
            $graphicsNs | Should -Not -BeNullOrEmpty
        }

        It "Competitive settings are applied (shadow_quality=1, ssao_mode=0)" {
            $xml = [xml](Get-Content $script:OutputFile -Raw)
            $graphicsNs = $xml.body.namespace | Where-Object { $_.name -eq 'graphics' }
            $shadowQ = ($graphicsNs.cvar | Where-Object { $_.name -eq 'shadow_quality' }).value
            $ssao = ($graphicsNs.cvar | Where-Object { $_.name -eq 'ssao_mode' }).value
            $shadowQ | Should -Be '1'
            $ssao | Should -Be '0'
        }

        It "FPS is uncapped (framerate_cap_enabled=0, framerate_cap=0)" {
            $xml = [xml](Get-Content $script:OutputFile -Raw)
            $graphicsNs = $xml.body.namespace | Where-Object { $_.name -eq 'graphics' }
            $capEnabled = ($graphicsNs.cvar | Where-Object { $_.name -eq 'framerate_cap_enabled' }).value
            $cap = ($graphicsNs.cvar | Where-Object { $_.name -eq 'framerate_cap' }).value
            $capEnabled | Should -Be '0'
            $cap | Should -Be '0'
        }

        It "NVIDIA Reflex is On+Boost (low_latency_mode=2)" {
            $xml = [xml](Get-Content $script:OutputFile -Raw)
            $graphicsNs = $xml.body.namespace | Where-Object { $_.name -eq 'graphics' }
            $reflex = ($graphicsNs.cvar | Where-Object { $_.name -eq 'low_latency_mode' }).value
            $reflex | Should -Be '2'
        }

        It "Render resolution is native (render_resolution_scaling_mode=0, percentage=100)" {
            $xml = [xml](Get-Content $script:OutputFile -Raw)
            $graphicsNs = $xml.body.namespace | Where-Object { $_.name -eq 'graphics' }
            $mode = ($graphicsNs.cvar | Where-Object { $_.name -eq 'render_resolution_scaling_mode' }).value
            $pct = ($graphicsNs.cvar | Where-Object { $_.name -eq 'render_resolution_percentage' }).value
            $mode | Should -Be '0'
            $pct | Should -Be '100'
        }

        It "Read-merge-write preserves resolution settings" {
            $xml = [xml](Get-Content $script:OutputFile -Raw)
            $graphicsNs = $xml.body.namespace | Where-Object { $_.name -eq 'graphics' }
            $width = ($graphicsNs.cvar | Where-Object { $_.name -eq 'fullscreen_resolution_width' }).value
            $height = ($graphicsNs.cvar | Where-Object { $_.name -eq 'fullscreen_resolution_height' }).value
            # Should preserve the original values from the reference config
            $width | Should -Be '1920'
            $height | Should -Be '1080'
        }

        It "Read-merge-write preserves gamma_control" {
            $xml = [xml](Get-Content $script:OutputFile -Raw)
            $graphicsNs = $xml.body.namespace | Where-Object { $_.name -eq 'graphics' }
            $gamma = ($graphicsNs.cvar | Where-Object { $_.name -eq 'gamma_control' }).value
            $gamma | Should -Be '3'
        }

        It "Read-merge-write preserves version" {
            $xml = [xml](Get-Content $script:OutputFile -Raw)
            $graphicsNs = $xml.body.namespace | Where-Object { $_.name -eq 'graphics' }
            $version = ($graphicsNs.cvar | Where-Object { $_.name -eq 'version' }).value
            $version | Should -Be '12'
        }

        It "Read-merge-write preserves audio namespace" {
            $xml = [xml](Get-Content $script:OutputFile -Raw)
            $audioNs = $xml.body.namespace | Where-Object { $_.name -eq 'audio' }
            $audioNs | Should -Not -BeNullOrEmpty
            $musicVol = ($audioNs.cvar | Where-Object { $_.name -eq 'cached_music_volume' }).value
            $musicVol | Should -Be '3'
        }

        It "Read-merge-write preserves gameplay namespace" {
            $xml = [xml](Get-Content $script:OutputFile -Raw)
            $gameplayNs = $xml.body.namespace | Where-Object { $_.name -eq 'gameplay' }
            $gameplayNs | Should -Not -BeNullOrEmpty
            $mouseSmoothing = ($gameplayNs.cvar | Where-Object { $_.name -eq 'mouse_smoothing_mode' }).value
            $mouseSmoothing | Should -Be '0'
        }

        It "Output XML declaration matches original format (no encoding attribute)" {
            $firstLine = (Get-Content $script:OutputFile)[0]
            $firstLine | Should -Not -Match 'encoding="utf-16"'
            $firstLine | Should -Match '<\?xml version="1\.0"\?>'
        }

        It "SQ_CHECK markers are emitted for config write" {
            $script:Output | Should -Match '\[SQ_CHECK_(OK|WARN|FAIL):MARATHON_CONFIG_WRITTEN'
        }

        It "SQ_CHECK markers are emitted for EXE flags" {
            $script:Output | Should -Match '\[SQ_CHECK_(OK|WARN|FAIL):MARATHON_EXE_FLAGS'
        }

        It "SQ_CHECK markers are emitted for MARATHON_SETTINGS_APPLIED" {
            $script:Output | Should -Match '\[SQ_CHECK_(OK|WARN):MARATHON_SETTINGS_APPLIED'
        }
    }

    # -----------------------------------------------------------------
    Context "Script output with non-NVIDIA GPU (AMD/Intel path)" {
        BeforeAll {
            # Create temp sandbox simulating %APPDATA%\Bungie\Marathon\prefs
            $script:TempDirAMD = Join-Path ([System.IO.Path]::GetTempPath()) "sq-test-marathon-amd-$(Get-Random)"
            $prefsDirAMD = Join-Path $script:TempDirAMD "Bungie\Marathon\prefs"
            New-Item -ItemType Directory -Path $prefsDirAMD -Force | Out-Null

            # Seed with reference config
            Copy-Item $RefFile (Join-Path $prefsDirAMD "cvars.xml") -Force

            # Save original APPDATA
            $script:OrigAppDataAMD = $env:APPDATA

            # Run the script with NVIDIA_GPU=0
            $env:SENSEQUALITY_HEADLESS = "1"
            $env:MONITOR_WIDTH = "1920"
            $env:MONITOR_HEIGHT = "1080"
            $env:MONITOR_REFRESH = "144"
            $env:NVIDIA_GPU = "0"
            $env:APPDATA = $script:TempDirAMD

            $scriptPath = Join-Path $ScriptsDir "25_Marathon_Settings.ps1"
            $script:OutputAMD = & $scriptPath *>&1 | Out-String
            $script:OutputFileAMD = Join-Path $prefsDirAMD "cvars.xml"
        }

        AfterAll {
            $env:APPDATA = $script:OrigAppDataAMD
            $env:SENSEQUALITY_HEADLESS = ""
            $env:NVIDIA_GPU = ""
            if ($script:TempDirAMD -and (Test-Path $script:TempDirAMD)) {
                Get-ChildItem $script:TempDirAMD -Recurse -File -ErrorAction SilentlyContinue |
                    ForEach-Object { if ($_.IsReadOnly) { $_.IsReadOnly = $false } }
                Remove-Item $script:TempDirAMD -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Output file exists" {
            $script:OutputFileAMD | Should -Exist
        }

        It "low_latency_mode is 0 for non-NVIDIA GPU" {
            $xml = [xml](Get-Content $script:OutputFileAMD -Raw)
            $graphicsNs = $xml.body.namespace | Where-Object { $_.name -eq 'graphics' }
            $reflex = ($graphicsNs.cvar | Where-Object { $_.name -eq 'low_latency_mode' }).value
            $reflex | Should -Be '0'
        }
    }

    # -----------------------------------------------------------------
    Context "Script source code correctness" {
        BeforeAll {
            $ScriptContent = Get-Content $ScriptFile -Raw
        }

        It "Script runs in headless mode" {
            $ScriptContent | Should -Match 'Initialize-SQEngine'
        }

        It "Script uses SQEngine shared module" {
            $ScriptContent | Should -Match '\. "\$PSScriptRoot\\SQEngine\.ps1"'
        }

        It "Script uses read-merge-write pattern (not blind overwrite)" {
            $ScriptContent | Should -Match '\[xml\]' -Because "Script must parse existing XML"
            $ScriptContent | Should -Match 'CompetitiveSettings' -Because "Script must define competitive settings to merge"
        }

        It "Script backs up existing config before writing" {
            $ScriptContent | Should -Match 'Backup-ConfigFile'
        }

        It "Script writes UTF-8 without BOM" {
            $ScriptContent | Should -Match 'UTF8Encoding.*\$false'
        }

        It "Script sets EXE compatibility flags" {
            $ScriptContent | Should -Match 'Set-ExeCompatFlags'
        }

        It "Script emits all expected SQ_CHECK markers" {
            $ScriptContent | Should -Match 'MARATHON_CONFIG_WRITTEN'
            $ScriptContent | Should -Match 'MARATHON_EXE_FLAGS'
        }

        It "Script does not cap FPS" {
            $ScriptContent | Should -Match "framerate_cap_enabled.*=.*'0'" -Because "FPS must be uncapped"
            $ScriptContent | Should -Match "framerate_cap\b.*=.*'0'" -Because "FPS cap must be 0 (uncapped)"
        }

        It "Script preserves non-graphics namespaces" {
            # Script should only modify the graphics namespace, not touch audio/gameplay/key bindings
            $ScriptContent | Should -Match "name -eq 'graphics'" -Because "Script must target only the graphics namespace"
            $ScriptContent | Should -Not -Match "name -eq 'audio'" -Because "Script must not modify the audio namespace"
            $ScriptContent | Should -Not -Match "name -eq 'gameplay'" -Because "Script must not modify the gameplay namespace"
        }

        It "Guide text matches config values" {
            # SSAO Off matches ssao_mode = 0
            $ScriptContent | Should -Match "SSAO\s+:\s+Off"
            # Shadow Quality Low matches shadow_quality = 1
            $ScriptContent | Should -Match "Shadow Quality\s+:\s+Low"
            # FPS Cap Uncapped matches framerate_cap_enabled = 0
            $ScriptContent | Should -Match "FPS Cap\s+:\s+Uncapped"
            # Anti-Aliasing SMAA matches anti_aliasing_mode = 2
            $ScriptContent | Should -Match "Anti-Aliasing\s+:\s+SMAA"
        }

        It "Script does not use em dashes or bare ampersands in comments" {
            # Em dashes and bare ampersands cause Pester parse errors
            $ScriptContent | Should -Not -Match [char]0x2014 -Because "Em dashes break Pester parsing"
        }
    }
}
