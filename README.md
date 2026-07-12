# FileSync status publisher

This private repository contains a small, externally available status record for selected local projects. It does not contain project source files, NAS data, credentials, virtual environments, or logs.

`projects.local.json` supplies the local projects root and is deliberately ignored. Copy `projects.template.json` to that filename and edit it when adding a machine.

## Current machine

`tweebeest` automatically reports every qualifying direct subfolder of its configured projects root. A folder qualifies when it contains a Git repository, a common project manifest/solution file, or source code within two folder levels. `FileSync` itself is excluded.

## Publish manually

```powershell
.\publish-status.ps1
```

For a local preview that does not commit or push:

```powershell
.\publish-status.ps1 -NoPush
```

## Status format

The generated `status/tweebeest.json` contains each project’s Git branch and commit where available, whether the working tree has uncommitted changes, up to 50 recently modified source/docs/test files, and NAS-sync state. Non-Git projects are reported as `unversioned`.

NAS/Syncthing state is `not_configured` until the LAN sync pilot is installed.
