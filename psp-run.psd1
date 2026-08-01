@{
    RootModule        = 'psp-run.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '78039b46-cd42-45ac-8ac1-55c77c64a2df'
    Author            = 'Phil Cartmell'
    Copyright         = '(c) Phil Cartmell. All rights reserved.'
    Description       = 'Run multiple local processes in parallel from a declarative JSON profile, with merged colour-coded live output and one-key teardown of the whole process tree.'
    PowerShellVersion = '7.0'

    FunctionsToExport = @('Invoke-ParallelRun')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('ParallelProcessing', 'DevTools', 'Launcher', 'Windows', 'Automation', 'MultiService')
            LicenseUri   = 'https://github.com/Philcartmell/powershell-parallel-run/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/Philcartmell/powershell-parallel-run'
            ReleaseNotes = 'Initial release: Invoke-ParallelRun.'
        }
    }
}
