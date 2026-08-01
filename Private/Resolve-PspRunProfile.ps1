function Resolve-PspRunProfile {
    <#
    .SYNOPSIS
        Parses and validates a psp-run JSON profile, returning fully-resolved service
        definitions (name, inner shell command, working directory, color) ready to launch.

    .DESCRIPTION
        Kept separate from Invoke-ParallelRun so the parsing/validation/resolution logic
        (relative-cwd handling, color assignment, env-var folding) can be unit tested
        without spawning any processes.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProfilePath
    )

    if (-not (Test-Path $ProfilePath)) {
        throw "Profile not found: $ProfilePath"
    }

    $resolvedPath = (Resolve-Path $ProfilePath).Path
    $profileDir = Split-Path $resolvedPath -Parent
    $config = Get-Content $resolvedPath -Raw | ConvertFrom-Json

    if (-not $config.services -or $config.services.Count -eq 0) {
        throw "Profile has no 'services' array — see examples/profile.example.json."
    }

    # Default palette; a service can pin its own color in the profile (e.g. to keep a
    # service's color stable across profiles that add/remove other services).
    $palette = @('Cyan', 'Green', 'Yellow', 'Magenta', 'Blue', 'DarkCyan', 'DarkYellow', 'DarkGreen', 'Red')

    $services = [System.Collections.Generic.List[object]]::new()
    $i = 0
    foreach ($s in $config.services) {
        if (-not $s.name -or -not $s.command) {
            throw "Every service needs a 'name' and a 'command'."
        }

        # Relative `cwd`s resolve against the profile file's own folder, not wherever
        # Invoke-ParallelRun happens to be called from — keeps profiles portable.
        $cwd =
            if ([string]::IsNullOrWhiteSpace($s.cwd)) { $profileDir }
            elseif ([System.IO.Path]::IsPathRooted($s.cwd)) { $s.cwd }
            else { [System.IO.Path]::GetFullPath((Join-Path $profileDir $s.cwd)) }

        $services.Add([pscustomobject]@{
            Name  = $s.name
            Cwd   = $cwd
            Inner = New-PspRunInnerCommand -Command $s.command -Cwd $cwd -EnvVars $s.env
            Color = if ($s.color) { $s.color } else { $palette[$i % $palette.Count] }
        })
        $i++
    }

    [pscustomobject]@{
        Name        = $config.name
        ProfileDir  = $profileDir
        ProfileName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedPath)
        Services    = $services
    }
}
