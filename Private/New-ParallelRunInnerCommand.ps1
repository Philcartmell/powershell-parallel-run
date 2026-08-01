function New-ParallelRunInnerCommand {
    <#
    .SYNOPSIS
        Builds the inner pwsh -Command string for one service: cd into its working
        directory, set any env vars, then run its command.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [Parameter(Mandatory)]
        [string]$Cwd,

        # A PSCustomObject of env-var-name -> value (as parsed from JSON), or $null.
        [AllowNull()]
        [object]$EnvVars
    )

    $envLines = ''
    if ($EnvVars) {
        foreach ($p in $EnvVars.PSObject.Properties) {
            $envLines += "`$env:$($p.Name) = '$($p.Value)'; "
        }
    }

    "Set-Location '$Cwd'; $envLines$Command"
}
