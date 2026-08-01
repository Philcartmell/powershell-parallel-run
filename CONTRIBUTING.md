# Contributing to ParallelRun

Thanks for considering it — contributions, bug reports, and ideas are all welcome.

## Project layout

```
ParallelRun.psd1              Module manifest (version, exported functions, metadata)
ParallelRun.psm1              Root module — dot-sources everything under Private/ and Public/
Public/Invoke-ParallelRun.ps1   The one exported cmdlet
Private/                  Internal helpers (not exported; unit tested via InModuleScope)
Tests/                    Pester tests
examples/                 Example JSON profile(s)
.github/workflows/        CI (every push/PR) and the Gallery publish workflow (releases only)
```

See [AGENTS.md](AGENTS.md) for the fuller set of conventions this repo follows (also
useful background reading for a human contributor, not just an AI agent).

## Getting set up

You need PowerShell 7+ (`pwsh`). Everything else installs on demand:

```powershell
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
Install-Module -Name Pester -MinimumVersion 5.5.0 -Scope CurrentUser
```

## Making a change

1. Fork + branch from `main`.
2. Make your change. If you're adding a new public cmdlet, give it an [approved
   PowerShell verb](https://learn.microsoft.com/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)
   (`Get-Verb` lists them), full comment-based help (`.SYNOPSIS`/`.DESCRIPTION`/
   `.PARAMETER`/`.EXAMPLE`), and add it to `FunctionsToExport` in `ParallelRun.psd1`.
3. Keep orchestration (process spawning, console I/O) separate from logic that can be
   unit tested — see how `Invoke-ParallelRun` (hard to unit test — it spawns real
   processes and reads the console) delegates parsing/validation to
   `Resolve-ParallelRunProfile` (pure, fully covered by Pester). New logic should follow the
   same split wherever it can.
4. Add/update Pester tests in `Tests/`.
5. Run the same checks CI runs, from the repo root:

   ```powershell
   Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
   Invoke-Pester -Path ./Tests
   Test-ModuleManifest -Path ./ParallelRun.psd1
   ```

6. Open a PR against `main`. CI (`.github/workflows/ci.yml`) runs the same three checks
   automatically.

## Reporting a bug / requesting a feature

Please use the issue templates — they ask for just enough detail (repro profile,
PowerShell version, expected vs. actual) to act on quickly.

## What NOT to do

- Don't add a dependency (a module, an external tool) for something that can be done
  with what PowerShell 7 ships with — this project deliberately stays install-and-go.
  If you think an exception is warranted, open an issue to discuss first.
- Don't silently change the JSON profile schema in a way that breaks existing profiles —
  additive changes only (new optional fields), and document them in the README's schema
  table.
