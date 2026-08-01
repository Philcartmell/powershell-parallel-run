# CLAUDE.md

This file is intentionally short. **[AGENTS.md](AGENTS.md) is the canonical set of
project conventions** — project layout, the orchestration/logic split, PowerShell style,
the lint/test commands to run before finishing a change, and what never to touch without
explicit sign-off. Read it before making changes here; this file only adds notes
specific to working in Claude Code.

## Claude Code-specific notes

- Use the PowerShell tool for anything PowerShell-specific (`Invoke-Pester`,
  `Invoke-ScriptAnalyzer`, `Import-Module`, `Test-ModuleManifest`) rather than shelling
  out through Bash — this is a `pwsh` project and the PowerShell tool gives real
  PowerShell semantics (typed errors, `$LASTEXITCODE`, etc.).
- When you change `Private/` or `Public/*.ps1`, re-import the module with `-Force`
  before re-running tests — `ParallelRun.psm1` dot-sources on import, so a stale imported
  session won't pick up edits otherwise: `Import-Module ./ParallelRun.psd1 -Force`.
- Never run `Publish-PSResource` / `Publish-Module` in a session, against any
  repository, real or `-WhatIf`. Publishing only ever happens through
  `.github/workflows/publish.yml`, gated by a human-reviewed GitHub Release — see
  `PUBLISHING.md`.
- This repo has no remote configured yet and nothing should be pushed anywhere without
  the user explicitly asking — creating a GitHub remote, pushing, or opening a PR are
  all actions to confirm first, not infer from context.
- If you add or change a Pester test, actually run it (`Invoke-Pester -Path ./Tests`)
  before calling the work done — don't hand back untested test code.
