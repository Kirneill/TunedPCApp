<#
.SYNOPSIS
    Pester 5 tests for SQEngine.ps1 shared module.

.DESCRIPTION
    Run with:  Invoke-Pester scripts/tests/SQEngine.Tests.ps1
    Tests each shared function in isolation.
#>

Describe 'SQEngine shared module' -Tag 'sqengine' {

    BeforeAll {
        $enginePath = Join-Path $PSScriptRoot '..\SQEngine.ps1'
        . $enginePath
    }

    # =========================================================================
    # Initialize-SQEngine
    # =========================================================================
    Describe 'Initialize-SQEngine' {

        AfterEach {
            $env:SENSEQUALITY_HEADLESS = $null
            $env:MONITOR_WIDTH = $null
            $env:MONITOR_HEIGHT = $null
            $env:MONITOR_REFRESH = $null
            $env:NVIDIA_GPU = $null
        }

        It 'reads headless mode environment variables' {
            $env:SENSEQUALITY_HEADLESS = '1'
            $env:MONITOR_WIDTH = '2560'
            $env:MONITOR_HEIGHT = '1440'
            $env:MONITOR_REFRESH = '165'
            $env:NVIDIA_GPU = '1'

            Initialize-SQEngine

            $script:Headless | Should -BeTrue
            $script:MonitorWidth | Should -Be 2560
            $script:MonitorHeight | Should -Be 1440
            $script:MonitorRefresh | Should -Be 165
            $script:NvidiaGPU | Should -BeTrue
            $script:ValidationFailed | Should -BeFalse
        }

        It 'uses defaults when not in headless mode' {
            $env:SENSEQUALITY_HEADLESS = '0'
            $env:MONITOR_WIDTH = $null

            Initialize-SQEngine

            $script:Headless | Should -BeFalse
            $script:MonitorWidth | Should -Be 1920
            $script:MonitorHeight | Should -Be 1080
            $script:MonitorRefresh | Should -Be 240
            $script:NvidiaGPU | Should -BeTrue
        }

        It 'uses defaults when headless but no MONITOR_WIDTH' {
            $env:SENSEQUALITY_HEADLESS = '1'
            $env:MONITOR_WIDTH = $null

            Initialize-SQEngine

            $script:Headless | Should -BeTrue
            $script:MonitorWidth | Should -Be 1920
        }

        It 'detects AMD GPU when NVIDIA_GPU is 0' {
            $env:SENSEQUALITY_HEADLESS = '1'
            $env:MONITOR_WIDTH = '1920'
            $env:MONITOR_HEIGHT = '1080'
            $env:MONITOR_REFRESH = '144'
            $env:NVIDIA_GPU = '0'

            Initialize-SQEngine

            $script:NvidiaGPU | Should -BeFalse
        }

        It 'resets ValidationFailed on each call' {
            $script:ValidationFailed = $true
            Initialize-SQEngine
            $script:ValidationFailed | Should -BeFalse
        }
    }

    # =========================================================================
    # Write-Check
    # =========================================================================
    Describe 'Write-Check' {

        BeforeEach {
            $script:ValidationFailed = $false
        }

        It 'emits OK marker without detail' {
            $output = Write-Check -Status 'OK' -Key 'TEST_KEY' 6>&1
            "$output" | Should -BeLike '*[SQ_CHECK_OK:TEST_KEY]*'
        }

        It 'emits OK marker with detail' {
            $output = Write-Check -Status 'OK' -Key 'TEST_KEY' -Detail 'some info' 6>&1
            "$output" | Should -BeLike '*[SQ_CHECK_OK:TEST_KEY:some info]*'
        }

        It 'emits WARN marker with detail' {
            $output = Write-Check -Status 'WARN' -Key 'TEST_KEY' -Detail 'some reason' 6>&1
            "$output" | Should -BeLike '*[SQ_CHECK_WARN:TEST_KEY:some reason]*'
        }

        It 'emits FAIL marker and sets ValidationFailed' {
            $output = Write-Check -Status 'FAIL' -Key 'TEST_KEY' -Detail 'error' 6>&1
            "$output" | Should -BeLike '*[SQ_CHECK_FAIL:TEST_KEY:error]*'
            $script:ValidationFailed | Should -BeTrue
        }

        It 'does not set ValidationFailed for OK or WARN' {
            Write-Check -Status 'OK' -Key 'TEST_KEY' 6>&1 | Out-Null
            $script:ValidationFailed | Should -BeFalse

            Write-Check -Status 'WARN' -Key 'TEST_KEY' 6>&1 | Out-Null
            $script:ValidationFailed | Should -BeFalse
        }

        It 'collapses newlines in detail text' {
            $output = Write-Check -Status 'OK' -Key 'TEST_KEY' -Detail "line1`r`nline2" 6>&1
            "$output" | Should -BeLike '*[SQ_CHECK_OK:TEST_KEY:line1 line2]*'
        }
    }

    # =========================================================================
    # Write-SQHeader
    # =========================================================================
    Describe 'Write-SQHeader' {

        It 'outputs title line' {
            $output = Write-SQHeader -Title 'Test Game - Optimization Script' 6>&1
            $text = ($output | ForEach-Object { "$_" }) -join "`n"
            $text | Should -Match 'Test Game - Optimization Script'
        }

        It 'outputs subtitle when provided' {
            $output = Write-SQHeader -Title 'Test Game' -Subtitle 'March 2026 | Engine' 6>&1
            $text = ($output | ForEach-Object { "$_" }) -join "`n"
            $text | Should -Match 'March 2026'
        }

        It 'outputs banner separators' {
            $output = Write-SQHeader -Title 'X' 6>&1
            $text = ($output | ForEach-Object { "$_" }) -join "`n"
            $text | Should -Match '======'
        }
    }

    # =========================================================================
    # Get-FrameRateLimit
    # =========================================================================
    Describe 'Get-FrameRateLimit' {

        It 'always returns 0 (uncapped) regardless of refresh rate' {
            Get-FrameRateLimit -RefreshRate 60  | Should -Be 0
            Get-FrameRateLimit -RefreshRate 144 | Should -Be 0
            Get-FrameRateLimit -RefreshRate 165 | Should -Be 0
            Get-FrameRateLimit -RefreshRate 240 | Should -Be 0
            Get-FrameRateLimit -RefreshRate 360 | Should -Be 0
        }

        It 'returns 0 regardless of $script:MonitorRefresh' {
            $script:MonitorRefresh = 165
            Get-FrameRateLimit | Should -Be 0

            $script:MonitorRefresh = 240
            Get-FrameRateLimit | Should -Be 0
        }
    }

    # =========================================================================
    # Backup-ConfigFile
    # =========================================================================
    Describe 'Backup-ConfigFile' {

        BeforeAll {
            $testDir = Join-Path $TestDrive 'backup-test'
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        }

        It 'creates timestamped backup of existing file' {
            $testFile = Join-Path $testDir 'test.ini'
            Set-Content -Path $testFile -Value 'test=value'

            $result = Backup-ConfigFile -Path $testFile 6>&1 | Where-Object { $_ -is [string] }
            # The function returns the backup path as last pipeline output
            $backups = Get-ChildItem $testDir -Filter '*.bak_*'
            $backups.Count | Should -BeGreaterThan 0
        }

        It 'clears read-only before backup' {
            $testFile = Join-Path $testDir 'readonly.ini'
            Set-Content -Path $testFile -Value 'readonly content'
            Set-ItemProperty -Path $testFile -Name IsReadOnly -Value $true

            Backup-ConfigFile -Path $testFile 6>&1 | Out-Null

            (Get-Item $testFile).IsReadOnly | Should -BeFalse
        }

        It 'returns null for non-existent file' {
            $result = Backup-ConfigFile -Path (Join-Path $testDir 'nonexistent.ini')
            $result | Should -BeNullOrEmpty
        }
    }

    # =========================================================================
    # Lock-ConfigFile / Unlock-ConfigFile
    # =========================================================================
    Describe 'Lock-ConfigFile and Unlock-ConfigFile' {

        It 'Lock-ConfigFile sets read-only' {
            $testFile = Join-Path $TestDrive 'lock-test.ini'
            Set-Content -Path $testFile -Value 'test=value'

            Lock-ConfigFile -Path $testFile 6>&1 | Out-Null

            (Get-Item $testFile).IsReadOnly | Should -BeTrue
        }

        It 'Unlock-ConfigFile clears read-only' {
            $testFile = Join-Path $TestDrive 'unlock-test.ini'
            Set-Content -Path $testFile -Value 'test=value'
            Set-ItemProperty -Path $testFile -Name IsReadOnly -Value $true

            Unlock-ConfigFile -Path $testFile

            (Get-Item $testFile).IsReadOnly | Should -BeFalse
        }

        It 'round-trips lock then unlock' {
            $testFile = Join-Path $TestDrive 'roundtrip.ini'
            Set-Content -Path $testFile -Value 'test=value'

            Lock-ConfigFile -Path $testFile 6>&1 | Out-Null
            (Get-Item $testFile).IsReadOnly | Should -BeTrue

            Unlock-ConfigFile -Path $testFile
            (Get-Item $testFile).IsReadOnly | Should -BeFalse
        }
    }
}
