# Publishing psp-run to the PowerShell Gallery

This is maintainer-only documentation for the one-time setup behind
`.github/workflows/publish.yml`, and the release process itself. If you're looking for
how to *use* the module, see [README.md](README.md).

## How a release works

1. Bump `ModuleVersion` in `psp-run.psd1` and update `ReleaseNotes` in `PrivateData.PSData`.
2. Merge that to `main`.
3. Cut a GitHub Release with tag `vX.Y.Z` matching the manifest version exactly (e.g.
   manifest `0.2.0` → tag `v0.2.0`). Publishing a Release (not just pushing a tag) is
   what triggers the workflow — a plain `git push --tags` does nothing here.
4. The `gallery-publish` environment gate (below) requires a reviewer to approve the run
   before it touches the Gallery.
5. The workflow re-runs lint + tests, checks the manifest version matches the tag, and
   only then runs `Publish-PSResource`.

If the manifest/tag version check fails, the workflow throws before it ever calls
`Publish-PSResource` — nothing partially publishes.

## One-time setup

### 1. Create a scoped PowerShell Gallery API key

Sign in at [powershellgallery.com](https://www.powershellgallery.com) → your account →
**API Keys** → create a new key with:

- **Glob pattern**: `psp-run` (or `psp-run*` if you expect to publish related packages
  later) — NOT `*`. A key scoped to one package name can't be used to push or take over
  anything else in the Gallery, even if it leaks.
- **Scope**: once the package exists, switch to *"Push only new versions of an existing
  package"* rather than *"Push new packages and package versions"* — that removes the
  key's ability to create brand-new packages entirely, which you don't need after the
  first publish.
- **Expiration**: set one (90–365 days). A key that can't be used forever is a key
  that can't be quietly re-used by an attacker months after a leak. Put a recurring
  reminder to rotate it before it expires (see below).

> **Prefer trusted publishing (OIDC) if it's available when you set this up.** NuGet.org
> added federated/OIDC "Trusted Publishing" for GitHub Actions, removing the need for a
> long-lived API key secret entirely — the Gallery's underlying infra is converging with
> NuGet.org's, so check the [PowerShell Gallery
> docs](https://learn.microsoft.com/powershell/gallery/) for current support before
> following the API-key path below. If it's supported, it's strictly better than
> everything in this section: no secret to store, rotate, or leak.

### 2. Store the key as an *environment* secret, not a repo secret

Repo → **Settings → Environments → New environment** → name it exactly `gallery-publish`
(matches `environment:` in `publish.yml`) → **Add secret** → `PSGALLERY_API_KEY` → the
key from step 1.

Then, on that same environment, add a **required reviewer** (yourself, or anyone else
who should sign off on a release). This is the actual security control: it means
`secrets.PSGALLERY_API_KEY` is only ever exposed to a workflow run that a human has
explicitly approved *after* seeing that it's about to run — a compromised or malicious
PR still can't reach the secret, because PRs from other branches/forks can't target a
protected environment without that approval step. A plain repo-level secret has no
equivalent gate: any workflow that runs in the repo can read it.

### 3. Keep the workflow's own permissions minimal

`publish.yml` already sets `permissions: contents: read` at the workflow level — the
job has no ability to push commits, open PRs, or touch anything else in the repo even if
something in the dependency chain were compromised. Don't broaden this unless a step
genuinely needs it.

### 4. Pin third-party Actions

`actions/checkout@v4` is an official GitHub Action; still worth knowing that pinning to
a full commit SHA (`actions/checkout@<sha>`) instead of a tag is the stronger form of
this control if you want to rule out a tag being force-moved upstream. Left as a
tag-pin here for readability; revisit if the security bar needs to go up (e.g. once
there are consuming teams beyond a hobby project).

## Rotating the API key

Before it expires: repeat step 1 to generate a new key with the same scope, update the
`PSGALLERY_API_KEY` secret on the `gallery-publish` environment, then revoke the old key
on the Gallery. Nothing else changes — the workflow doesn't need touching.

## If a key leaks

Revoke it immediately from your Gallery account (API Keys → the key → delete). Because
it was glob-scoped to `psp-run` and (after the first publish) restricted to
"push new versions only", the blast radius is "someone could publish a malicious version
of psp-run" — not "someone can publish anything under your account". Publish a
corrected version immediately after rotating, and consider a Gallery support request to
have the bad version delisted.
