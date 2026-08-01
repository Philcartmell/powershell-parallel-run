# ParallelRun

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/ParallelRun?logo=powershell)](https://www.powershellgallery.com/packages/ParallelRun)
[![PowerShell Gallery downloads](https://img.shields.io/powershellgallery/dt/ParallelRun)](https://www.powershellgallery.com/packages/ParallelRun)
[![CI](https://github.com/Philcartmell/powershell-parallel-run/actions/workflows/ci.yml/badge.svg)](https://github.com/Philcartmell/powershell-parallel-run/actions/workflows/ci.yml)

A PowerShell module that starts every service in a local dev stack at once, streams
their combined output live in one terminal, and stops everything with one keypress.

No extra terminal tabs, no manually killing five processes when you're done, no
dependency beyond PowerShell 7 itself. Describe your stack in a small JSON file; run one
cmdlet.

## Demo

```powershell
Invoke-ParallelRun -ProfilePath ./examples/profile.example.json
```

```
Profile: Example dev stack
  started API    pid 21344
  started Worker pid 21402
  started Web    pid 21408
  started Redis  pid 21455

────────────────────────────────────────────────────────────
 4 services up. Combined output follows below.
 Press q or Ctrl+C to stop everything (backstop: create a .stop-<profile> file next to the profile).
────────────────────────────────────────────────────────────
API    | Now listening on http://localhost:5100
Redis  | Ready to accept connections
Web    | webpack compiled successfully in 812ms
Worker | Listening for jobs on queue 'default'
API    | GET /health 200 3ms
Web    | webpack compiled successfully in 224ms
Worker | Processed job 7f2a9c (14ms)
API    | GET /health 200 2ms

Stopping (q)...

Shutting down services...
Done.
```

(In a real terminal each service's label is color-coded — `API` cyan, `Worker` yellow,
etc. — so a busy interleaved log is still easy to scan by eye. Markdown code fences
strip that, but the alignment and ordering above are exactly what you'd see.)

## Why

Running a multi-service stack locally usually means one of:

- **N terminal tabs.** You alt-tab to see if something errored, and when you're done you
  close each one by hand (or forget one, and it's still bound to a port tomorrow).
- **A third-party tool** like `concurrently` — great, but it's an npm dependency for
  something that's fundamentally just process orchestration.
- **Nothing** — you just don't run the full stack locally and pay for it in slower
  iteration.

`ParallelRun` is the missing built-in: no install beyond the module itself, one declarative
file describing the stack, one combined log, one shutdown that actually cleans up every
child process tree behind each service.

## Install

```powershell
Install-Module -Name ParallelRun -Scope CurrentUser
```

From the [PowerShell Gallery](https://www.powershellgallery.com/packages/ParallelRun).

## Usage

Write a profile (`profile.json`):

```json
{
  "name": "My dev stack",
  "services": [
    { "name": "API", "command": "dotnet run", "cwd": "./src/Api", "color": "Cyan" },
    { "name": "Web", "command": "npm start", "cwd": "./src/Web" },
    { "name": "Redis", "command": "redis-server" }
  ]
}
```

Run it:

```powershell
Import-Module ParallelRun
Invoke-ParallelRun -ProfilePath ./profile.json
```

Every service starts in the order it appears in the file, staggered slightly so startup
banners don't collide. Their combined stdout/stderr streams into your terminal, each
line prefixed with a color-coded, column-aligned label. Press **`q`** or **Ctrl+C** to
stop everything — every service and its full child process tree.

If your terminal's key input isn't readable (some CI runners, redirected consoles),
create a `.stop-<profile-filename>` file next to the profile as a backstop; the launcher
polls for it and stops on the next tick.

## Profile schema

| Field                | Required | Description                                                                                  |
|-----------------------|:--------:|------------------------------------------------------------------------------------------------|
| `name`                |          | Label printed once at startup. Purely cosmetic.                                                |
| `services`            | ✅       | Ordered array of service objects. Services start in this order.                                |
| `services[].name`     | ✅       | The label prefixed on every line this service outputs.                                         |
| `services[].command`  | ✅       | Any shell command — `dotnet run`, `npm start`, a script, anything `pwsh -Command` can run.      |
| `services[].cwd`      |          | Working directory. Relative paths resolve against the **profile file's folder**, not wherever you invoked `Invoke-ParallelRun` from. Defaults to the profile's folder. |
| `services[].color`    |          | Any [PowerShell console color](https://learn.microsoft.com/dotnet/api/system.consolecolor). Auto-assigned from a palette, in order, when omitted. |
| `services[].env`      |          | Object of environment-variable name → value, set before `command` runs.                        |

See [`examples/profile.example.json`](examples/profile.example.json) for a full example.

## How it works

Each service is launched as a hidden child `pwsh -Command "<cd + env + your command>"`
process with its stdout/stderr redirected. `Register-ObjectEvent` subscribes to each
process's `OutputDataReceived`/`ErrorDataReceived` events — these fire on background
threads — and pushes every line onto a shared thread-safe queue
(`ConcurrentQueue`). The main thread just drains that queue in a loop, printing each
line with its service's colored label, while also watching for `q` / Ctrl+C / the
stop-file.

A couple of details that matter more than they look:

- **Each child's stdin is redirected too**, even though nothing writes to it. Without
  that, a child process (`dotnet`, `npm`, …) can inherit and silently consume the
  console's keystrokes — including the `q` you meant for the launcher — so it never
  reaches the shutdown key loop.
- **Ctrl+C is claimed via `[Console]::TreatControlCAsInput`** so it arrives as a normal
  keypress the launcher's own loop reads, rather than racing PowerShell's default
  Ctrl+C handling (which would tear the launcher down non-deterministically, before it
  gets to clean up its children).
- **Teardown runs `taskkill /PID <pid> /T /F`** against every service's process — the
  `/T` kills the entire tree (hidden `pwsh` → the real process it launched → whatever
  *that* spawned), which is what actually stops `dotnet run` from leaving Kestrel
  running after the launcher itself has exited.

The parsing/validation/resolution side (reading the JSON, checking required fields,
resolving relative working directories, assigning colors) is deliberately kept in pure,
side-effect-free private functions, separate from the process-spawning/console code —
see [AGENTS.md](AGENTS.md) if you're contributing and want the fuller design rationale.

## Requirements

- PowerShell 7+ (`pwsh`)
- Windows today — teardown uses `taskkill /T`. Cross-platform support (a
  `pkill`/process-group-based teardown) is a welcome contribution — see below.

## Contributing

Bug reports, feature ideas, and PRs are all welcome — see
[CONTRIBUTING.md](CONTRIBUTING.md) for project layout, conventions, and how to run the
same checks CI runs before you open a PR.

## License

[MIT](LICENSE)
