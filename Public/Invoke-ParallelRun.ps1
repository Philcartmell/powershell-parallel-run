function Invoke-ParallelRun {
    <#
    .SYNOPSIS
        Runs every service in a JSON profile in parallel, merges their live output into
        one terminal with a colored label per line, and tears the whole process tree
        down cleanly on 'q' or Ctrl+C.

    .DESCRIPTION
        Point it at a JSON profile describing an ordered list of services (a name, a
        shell command, and optionally a working directory, environment variables, and a
        color). Each service is launched in a hidden child pwsh, in the order it appears
        in the profile, with a short stagger so startup banners don't collide. All
        stdout/stderr from every service is multiplexed back into this one console, each
        line prefixed with a colored, column-aligned label so you can tell at a glance
        who said what.

        Stop everything with 'q', Ctrl+C, or by creating a `.stop-<profile-name>` file
        next to the profile — a backstop for terminals where key input can't be read
        (some CI runners, redirected consoles).

    .PARAMETER ProfilePath
        Path to a JSON profile file. See examples/profile.example.json for the schema.

    .EXAMPLE
        Invoke-ParallelRun -ProfilePath ./profile.json

        Starts every service in profile.json and streams their combined output until you
        press q or Ctrl+C.

    .NOTES
        Windows only today — teardown shells out to `taskkill /T` to kill each service's
        whole process tree. A cross-platform (pkill-based) teardown is tracked as a
        follow-up; contributions welcome, see CONTRIBUTING.md.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [Alias('Profile')]
        [string]$ProfilePath
    )

    $resolved = Resolve-PspRunProfile -ProfilePath $ProfilePath
    $profileDir = $resolved.ProfileDir
    $svcs = $resolved.Services | ForEach-Object {
        [pscustomobject]@{ Name = $_.Name; Inner = $_.Inner; Color = $_.Color; Proc = $null }
    }

    # ── launch: each service runs in a hidden pwsh whose stdout/stderr stream back here ──
    # OutputDataReceived/ErrorDataReceived fire on background threads, so lines are pushed
    # onto a ConcurrentQueue; the main loop below drains it and prints each line prefixed
    # with its service's colored label.
    $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
    $subscribers = @()
    $labelWidth = ($svcs | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
    $lineFmt = "{0,-$labelWidth} | "
    $sink = {
        if ($null -ne $EventArgs.Data) {
            $m = $Event.MessageData
            $m.Q.Enqueue([pscustomobject]@{ Label = $m.Label; Color = $m.Color; Text = $EventArgs.Data; Err = $m.Err })
        }
    }

    try {
        if ($resolved.Name) { Write-Host "Profile: $($resolved.Name)" -ForegroundColor DarkGray }
        foreach ($s in $svcs) {
            $psi = [System.Diagnostics.ProcessStartInfo]::new()
            $psi.FileName = 'pwsh'
            $psi.ArgumentList.Add('-NoLogo')
            $psi.ArgumentList.Add('-NoProfile')
            $psi.ArgumentList.Add('-Command')
            $psi.ArgumentList.Add($s.Inner)
            $psi.WorkingDirectory = $profileDir
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            # Redirect stdin too, so a child (dotnet/npm/whatever) can't inherit + swallow
            # this console's keystrokes — otherwise 'q' / Ctrl+C get grabbed by a child and
            # never reach the key loop below. We never write to it.
            $psi.RedirectStandardInput = $true

            $proc = [System.Diagnostics.Process]::new()
            $proc.StartInfo = $psi

            $dOut = [pscustomobject]@{ Q = $queue; Label = $s.Name; Color = $s.Color; Err = $false }
            $dErr = [pscustomobject]@{ Q = $queue; Label = $s.Name; Color = $s.Color; Err = $true }
            $subscribers += Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -MessageData $dOut -Action $sink
            $subscribers += Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived  -MessageData $dErr -Action $sink

            $proc.Start() | Out-Null
            $proc.BeginOutputReadLine()
            $proc.BeginErrorReadLine()
            $s.Proc = $proc
            Write-Host ("  started {0,-$labelWidth} pid {1}" -f $s.Name, $proc.Id) -ForegroundColor DarkGray
            Start-Sleep -Milliseconds 400   # small stagger so startup banners don't interleave
        }

        Write-Host ''
        Write-Host '────────────────────────────────────────────────────────────' -ForegroundColor DarkGray
        Write-Host " $($svcs.Count) services up. Combined output follows below." -ForegroundColor Green
        Write-Host ' Press q or Ctrl+C to stop everything (backstop: create a .stop-<profile> file next to the profile).' -ForegroundColor Green
        Write-Host '────────────────────────────────────────────────────────────' -ForegroundColor DarkGray

        # Stop on 'q', Ctrl+C, or a sentinel file. Ctrl+C is claimed via TreatControlCAsInput
        # so it arrives here as a plain key (deterministic teardown) instead of racing
        # PowerShell's default handler; children can't steal it since their stdin is
        # redirected above. The sentinel file is a backstop for hosts where the console
        # can't be read.
        $stopFile = Join-Path $profileDir ".stop-$($resolved.ProfileName)"
        if (Test-Path $stopFile) { Remove-Item $stopFile -Force -ErrorAction SilentlyContinue }
        $interactive = -not [Console]::IsInputRedirected
        if ($interactive) { try { [Console]::TreatControlCAsInput = $true } catch { $interactive = $false } }
        $item = $null
        while ($true) {
            while ($queue.TryDequeue([ref]$item)) {
                Write-Host ($lineFmt -f $item.Label) -ForegroundColor $item.Color -NoNewline
                if ($item.Err) { Write-Host $item.Text -ForegroundColor Red } else { Write-Host $item.Text }
            }
            if ($interactive -and [Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                $isCtrlC = ($key.Key -eq [ConsoleKey]::C) -and (($key.Modifiers -band [ConsoleModifiers]::Control) -ne 0)
                if ($key.Key -eq [ConsoleKey]::Q -or $isCtrlC) {
                    Write-Host ''
                    Write-Host ("Stopping ({0})..." -f $(if ($isCtrlC) { 'Ctrl+C' } else { 'q' })) -ForegroundColor Cyan
                    break
                }
            }
            if (Test-Path $stopFile) {
                Remove-Item $stopFile -Force -ErrorAction SilentlyContinue
                Write-Host ''
                Write-Host "Stopping (.stop-$($resolved.ProfileName))..." -ForegroundColor Cyan
                break
            }
            Start-Sleep -Milliseconds 120
        }
    }
    finally {
        try { [Console]::TreatControlCAsInput = $false } catch {}   # restore normal Ctrl+C for the terminal
        Write-Host ''
        Write-Host 'Shutting down services...' -ForegroundColor Cyan
        foreach ($sub in $subscribers) { Unregister-Event -SourceIdentifier $sub.Name -ErrorAction SilentlyContinue }
        foreach ($s in $svcs) {
            if ($s.Proc -and -not $s.Proc.HasExited) {
                # /T kills the whole tree (hidden pwsh -> the real process it launched -> its children).
                taskkill /PID $s.Proc.Id /T /F 2>$null | Out-Null
            }
        }
        Write-Host 'Done.' -ForegroundColor Cyan
    }
}
