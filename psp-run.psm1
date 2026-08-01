$here = $PSScriptRoot

foreach ($folder in 'Private', 'Public') {
    $path = Join-Path $here $folder
    if (Test-Path $path) {
        Get-ChildItem -Path $path -Filter '*.ps1' | ForEach-Object {
            . $_.FullName
        }
    }
}

# Exported functions are declared in psp-run.psd1 (FunctionsToExport) — the manifest is
# the single source of truth for the module's public surface, so nothing to do here.
