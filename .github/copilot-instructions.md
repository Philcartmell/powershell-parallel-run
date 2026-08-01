# Copilot instructions

This file is intentionally short. **[AGENTS.md](../AGENTS.md) is the canonical set of
project conventions** — project layout, the orchestration/logic split, PowerShell style
(approved verbs, comment-based help, brace style), the lint/test commands to run before
finishing a change, and what never to touch without explicit human sign-off. Read it
before proposing changes, whether you're Copilot Chat suggesting an edit or the Copilot
coding agent working a full issue.

## Copilot-specific notes

- Before opening a PR (or finishing a coding-agent session), run and confirm clean:
  `Test-ModuleManifest -Path ./ParallelRun.psd1`,
  `Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1`,
  `Invoke-Pester -Path ./Tests`. CI runs the same three checks and will fail the PR
  otherwise.
- This is a PowerShell 7 module with **no runtime dependencies beyond PowerShell
  itself**. Don't suggest adding an npm/pip/NuGet package, an external CLI tool, or a
  YAML/TOML config format to solve something `ConvertFrom-Json` or a built-in .NET type
  already solves — see AGENTS.md's "no new dependencies without discussion" note.
- Do not modify `.github/workflows/publish.yml`, `PUBLISHING.md`, or
  `ParallelRun.psd1`'s `ModuleVersion` as an incidental part of an unrelated change — these
  gate what actually reaches the public PowerShell Gallery. Flag any genuinely-needed
  change to them explicitly in the PR description.
