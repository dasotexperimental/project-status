# FileSync status publisher

This private repository contains a small, externally available status record for selected local projects. It does not contain project source files, NAS data, credentials, virtual environments, or logs.

## Current machine

`tweebeest` reports status for the local AZA Git repository.

## Publish manually

```powershell
.\publish-status.ps1
```

For a local preview that does not commit or push:

```powershell
.\publish-status.ps1 -NoPush
```

## Status format

The generated `status/tweebeest.json` contains the Git branch and commit, whether the working tree has uncommitted changes, up to 50 recently modified source/docs/test files, and NAS-sync state.

NAS/Syncthing state is `not_configured` until the LAN sync pilot is installed.
