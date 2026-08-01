@{
    # Every exclusion below is deliberate and reviewed, not blanket rule-disabling.
    ExcludeRules = @(
        # This repo is UTF-8 (no BOM) throughout, including the box-drawing characters in
        # Invoke-ParallelRun's console banner — standard for a cross-platform git repo; a
        # BOM would just add diff noise.
        'PSUseBOMForUnicodeEncodedFile',

        # New-PspRunInnerCommand is a pure string builder with no side effects, despite
        # the New- verb (it builds the `pwsh -Command` string a service will run — it
        # doesn't run anything itself). ShouldProcess doesn't apply.
        'PSUseShouldProcessForStateChangingFunctions',

        # The one empty catch (Invoke-ParallelRun's `finally` block, restoring
        # [Console]::TreatControlCAsInput) is intentional best-effort cleanup on the way
        # out — it must never throw and mask the real teardown, and there's nothing
        # meaningful to do if resetting console mode fails.
        'PSAvoidUsingEmptyCatchBlock',

        # Pester's `InModuleScope -Parameters @{...} { param($x) ... }` pattern passes
        # values into a nested scriptblock in a way PSScriptAnalyzer's static analysis
        # can't trace — a known false positive with this Pester idiom, not an actual
        # unused parameter. Only fires in Tests/.
        'PSReviewUnusedParameter',

        # Invoke-ParallelRun IS a live, colored console UI, not a pipeline function —
        # Write-Host is the correct tool. The usual reason to avoid it (it breaks output
        # capture/redirection for callers composing your function in a pipeline) doesn't
        # apply to an interactive launcher whose entire purpose is console output.
        'PSAvoidUsingWriteHost'
    )
}
