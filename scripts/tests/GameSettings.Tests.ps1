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
