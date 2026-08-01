## What this changes and why

## Checklist

- [ ] `Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1` is clean
- [ ] `Invoke-Pester -Path ./Tests` passes
- [ ] New/changed public behaviour has a Pester test
- [ ] New/changed cmdlets have comment-based help (`.SYNOPSIS`/`.DESCRIPTION`/`.PARAMETER`/`.EXAMPLE`)
- [ ] README updated if user-facing behaviour or the profile schema changed
