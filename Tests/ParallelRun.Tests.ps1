BeforeAll {
    $script:ModuleRoot = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $script:ModuleRoot 'ParallelRun.psd1') -Force

    $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "ParallelRun-tests-$([guid]::NewGuid())"
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
}

AfterAll {
    Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Module ParallelRun -Force -ErrorAction SilentlyContinue
}

Describe 'Module manifest' {
    It 'is valid' {
        { Test-ModuleManifest -Path (Join-Path $script:ModuleRoot 'ParallelRun.psd1') } | Should -Not -Throw
    }

    It 'exports exactly Invoke-ParallelRun' {
        $manifest = Test-ModuleManifest -Path (Join-Path $script:ModuleRoot 'ParallelRun.psd1')
        $manifest.ExportedFunctions.Keys | Should -Be @('Invoke-ParallelRun')
    }
}

Describe 'Resolve-ParallelRunProfile' {
    It 'throws when the profile file does not exist' {
        InModuleScope ParallelRun {
            { Resolve-ParallelRunProfile -ProfilePath (Join-Path $script:TempDir 'missing.json') } | Should -Throw
        }
    }

    It 'throws when the services array is missing' {
        $path = Join-Path $script:TempDir 'no-services.json'
        '{}' | Set-Content -Path $path
        InModuleScope ParallelRun -Parameters @{ Path = $path } {
            param($Path)
            { Resolve-ParallelRunProfile -ProfilePath $Path } | Should -Throw "*services*"
        }
    }

    It 'throws when a service is missing a command' {
        $path = Join-Path $script:TempDir 'missing-command.json'
        '{"services":[{"name":"A"}]}' | Set-Content -Path $path
        InModuleScope ParallelRun -Parameters @{ Path = $path } {
            param($Path)
            { Resolve-ParallelRunProfile -ProfilePath $Path } | Should -Throw
        }
    }

    It 'throws when a service is missing a name' {
        $path = Join-Path $script:TempDir 'missing-name.json'
        '{"services":[{"command":"echo hi"}]}' | Set-Content -Path $path
        InModuleScope ParallelRun -Parameters @{ Path = $path } {
            param($Path)
            { Resolve-ParallelRunProfile -ProfilePath $Path } | Should -Throw
        }
    }

    It 'assigns palette colors in order when no color is specified' {
        $path = Join-Path $script:TempDir 'colors.json'
        '{"services":[{"name":"A","command":"echo a"},{"name":"B","command":"echo b"}]}' | Set-Content -Path $path
        InModuleScope ParallelRun -Parameters @{ Path = $path } {
            param($Path)
            $resolved = Resolve-ParallelRunProfile -ProfilePath $Path
            $resolved.Services[0].Color | Should -Be 'Cyan'
            $resolved.Services[1].Color | Should -Be 'Green'
        }
    }

    It 'honors an explicit color over the palette' {
        $path = Join-Path $script:TempDir 'explicit-color.json'
        '{"services":[{"name":"A","command":"echo a","color":"Red"}]}' | Set-Content -Path $path
        InModuleScope ParallelRun -Parameters @{ Path = $path } {
            param($Path)
            (Resolve-ParallelRunProfile -ProfilePath $Path).Services[0].Color | Should -Be 'Red'
        }
    }

    It 'resolves a relative cwd against the profile directory, not the current directory' {
        $path = Join-Path $script:TempDir 'relative-cwd.json'
        '{"services":[{"name":"A","command":"echo a","cwd":"./sub"}]}' | Set-Content -Path $path
        InModuleScope ParallelRun -Parameters @{ Path = $path; Dir = $script:TempDir } {
            param($Path, $Dir)
            $expected = [System.IO.Path]::GetFullPath((Join-Path $Dir 'sub'))
            (Resolve-ParallelRunProfile -ProfilePath $Path).Services[0].Cwd | Should -Be $expected
        }
    }

    It 'defaults an omitted cwd to the profile directory' {
        $path = Join-Path $script:TempDir 'default-cwd.json'
        '{"services":[{"name":"A","command":"echo a"}]}' | Set-Content -Path $path
        InModuleScope ParallelRun -Parameters @{ Path = $path; Dir = $script:TempDir } {
            param($Path, $Dir)
            (Resolve-ParallelRunProfile -ProfilePath $Path).Services[0].Cwd | Should -Be $Dir
        }
    }

    It 'keeps an absolute cwd as-is' {
        $absolute = ($IsWindows -or $null -eq $IsWindows) ? 'C:\some\absolute\path' : '/some/absolute/path'
        $path = Join-Path $script:TempDir 'absolute-cwd.json'
        $json = @{ services = @(@{ name = 'A'; command = 'echo a'; cwd = $absolute }) } | ConvertTo-Json
        $json | Set-Content -Path $path
        InModuleScope ParallelRun -Parameters @{ Path = $path; Absolute = $absolute } {
            param($Path, $Absolute)
            (Resolve-ParallelRunProfile -ProfilePath $Path).Services[0].Cwd | Should -Be $Absolute
        }
    }

    It 'folds env vars into the inner command' {
        $path = Join-Path $script:TempDir 'env-vars.json'
        '{"services":[{"name":"A","command":"echo a","env":{"FOO":"bar"}}]}' | Set-Content -Path $path
        InModuleScope ParallelRun -Parameters @{ Path = $path } {
            param($Path)
            $pattern = [regex]::Escape("`$env:FOO = 'bar'")
            (Resolve-ParallelRunProfile -ProfilePath $Path).Services[0].Inner | Should -Match $pattern
        }
    }
}

Describe 'New-ParallelRunInnerCommand' {
    It 'sets the working directory before running the command' {
        InModuleScope ParallelRun {
            New-ParallelRunInnerCommand -Command 'echo hi' -Cwd 'C:\work' -EnvVars $null |
                Should -Be "Set-Location 'C:\work'; echo hi"
        }
    }

    It 'emits one env-var assignment per property, in order' {
        InModuleScope ParallelRun {
            $envVars = [pscustomobject]@{ A = '1'; B = '2' }
            $inner = New-ParallelRunInnerCommand -Command 'run' -Cwd 'C:\work' -EnvVars $envVars
            $inner | Should -Be "Set-Location 'C:\work'; `$env:A = '1'; `$env:B = '2'; run"
        }
    }
}
