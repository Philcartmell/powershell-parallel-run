# AGENTS.md

Instructions for AI coding agents (GitHub Copilot, Claude, or anything else) working in
this repository. This is the canonical set of conventions — other agent-specific files
(`CLAUDE.md`, `.github/copilot-instructions.md`) point back here rather than repeating
it, so keep this one file up to date rather than editing conventions in multiple places.

## What this project is

`psp-run` is a small, dependency-free PowerShell 7 module with one job: given a JSON
profile describing an ordered list of local processes ("services"), start them all in
parallel, merge their live stdout/stderr into one console with a colored label per line,
and tear the whole tree down on `q` / Ctrl+C. Published to the PowerShell Gallery.

Read `README.md` for what it does from a user's perspective and `PUBLISHING.md` for how
releases reach the Gallery before touching anything release-related.

## Project layout

```
psp-run.psd1                     Module manifest — version, exported functions, metadata
psp-run.psm1                     Root module — dot-sources Private/*.ps1 then Public/*.ps1
Public/Invoke-ParallelRun.ps1    The one exported cmdlet — orchestration (spawns processes, owns the console)
Private/Resolve-PspRunProfile.ps1    Parses + validates a profile, resolves cwd/color/env — pure, unit tested
Private/New-PspRunInnerCommand.ps1   Builds one service's `pwsh -Command` string — pure, unit tested
Tests/psp-run.Tests.ps1          Pester 5 tests
examples/profile.example.json    Reference profile
PSScriptAnalyzerSettings.psd1    Lint config — every exclusion in it is commented with why
.github/workflows/ci.yml         Lint + test on every push/PR
.github/workflows/publish.yml    Gallery publish — GitHub Release trigger only, see PUBLISHING.md
```

## Core design rule: keep orchestration and logic separate

`Invoke-ParallelRun` spawns real processes and reads the live console — it is
deliberately hard to unit test and isn't. Everything that CAN be pure — profile parsing,
schema validation, cwd resolution, color assignment, building the inner command string —
lives in `Private/` as small functions with no side effects, and IS fully covered by
Pester via `InModuleScope`.

When you add a feature: put any new decision-making logic in a private, pure function
first, and test that. Only touch `Invoke-ParallelRun` for the parts that genuinely
require a live process or console (and keep those additions minimal).

## PowerShell conventions

- **Approved verbs only.** Any new exported cmdlet needs a verb from `Get-Verb` (e.g.
  `Start-`, `Invoke-`, `New-`, `Test-` — not `Run-`, `Launch-`, `Create-`). This is a
  hard PowerShell Gallery/module convention, not a style preference — `Import-Module`
  will warn on import if you get it wrong.
- **Full comment-based help on every exported function**: `.SYNOPSIS`, `.DESCRIPTION`,
  one `.PARAMETER` per parameter, at least one `.EXAMPLE`. This is what backs
  `Get-Help Invoke-ParallelRun -Full` — it's the module's actual user-facing
  documentation, not optional decoration.
- **Brace style**: opening brace on the same line as the statement (`if (...) { ... }`,
  `function Foo {`), matching the rest of the codebase. Don't switch to Allman style in
  new code.
- **`Export-ModuleMember` is not used** in `psp-run.psm1` — `FunctionsToExport` in the
  `.psd1` manifest is the single source of truth for the public surface. Add new public
  functions there, not via `Export-ModuleMember`.
- **No new dependencies without discussion.** The module installs and runs with nothing
  beyond PowerShell 7 itself (`ConvertFrom-Json`, `System.Diagnostics.Process`, etc. are
  all built in). Don't add a module dependency, an external binary requirement, or a
  non-JSON config format without raising it as a design question first — it's a
  deliberate, load-bearing property of this project ("install-and-go"), not an oversight.
- **Windows-only today** — teardown shells out to `taskkill /T /F`. If you're adding
  cross-platform support, it needs a real `pkill`/process-group-based equivalent on
  macOS/Linux, tested there, not just "swap the command and hope."

## Before you're done: run what CI runs

```powershell
Test-ModuleManifest -Path ./psp-run.psd1
Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
Invoke-Pester -Path ./Tests
```

All three must pass cleanly (the analyzer step should print nothing). If you need to add
a new lint exclusion, add it to `PSScriptAnalyzerSettings.psd1` with a comment explaining
*why* it's a false positive or a deliberate choice for this codebase — see the existing
entries for the expected level of detail. Don't silence a rule you haven't actually
understood.

## The JSON profile schema is a public contract

`examples/profile.example.json` and the schema table in `README.md` are the source of
truth for what a profile looks like. Changes must be additive (new optional fields) —
don't rename or repurpose an existing field, and don't make anything currently-optional
required. If a breaking change is genuinely necessary, it needs a major version bump and
a call-out in the release notes, not a silent change.

## Things to never touch without explicit human sign-off

- `.github/workflows/publish.yml` and anything in `PUBLISHING.md` — this is the path
  that pushes a real package to the public PowerShell Gallery under a real account. Read
  `PUBLISHING.md` in full before proposing any change here, and flag the change clearly
  in your PR description rather than folding it into an unrelated diff.
- `psp-run.psd1`'s `ModuleVersion` — this is bumped as part of a deliberate release
  process (see `PUBLISHING.md`), not as an incidental part of a feature PR.
- Repository secrets, environment protection rules, or anything under GitHub
  **Settings** — none of that is in this repo's source tree for a reason.
