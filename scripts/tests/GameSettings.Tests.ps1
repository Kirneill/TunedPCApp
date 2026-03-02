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
            $ScriptContent | Should -Match 'SENSEQUALITY_HEADLESS'
        }
    }
}
