## What this changes and why

## Checklist

- [ ] Applied a version label — `semver:major` (breaking), `semver:minor` (feature), or `semver:patch` (fix/maintenance; the default). This drives the next release version — see [PUBLISHING.md](../PUBLISHING.md).
- [ ] `Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1` is clean
- [ ] `Invoke-Pester -Path ./Tests` passes
- [ ] New/changed public behaviour has a Pester test
- [ ] New/changed cmdlets have comment-based help (`.SYNOPSIS`/`.DESCRIPTION`/`.PARAMETER`/`.EXAMPLE`)
- [ ] README updated if user-facing behaviour or the profile schema changed
- [ ] Did **not** hand-edit `ModuleVersion` in `ParallelRun.psd1` (versioning is automated)
