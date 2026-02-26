# TUNEDPC by SENSEQUALITY (Private Source Repo)

Concise maintainer context for future model handoff.

## What This Repo Is

- Private source repository for the Electron app.
- Public binaries-only repo: `Kirneill/TunedPCApp`.
- Users should download installers from public releases, not this repo.

## Current Product State

- App name in installer: `SENSEQUALITY Optimizer` (electron-builder `productName`).
- In-app top-left branding text: `TUNEDPC by SENSEQUALITY.com`.
- EULA included and enforced in NSIS installer (`EULA.txt`).
- `package.json` license set to `UNLICENSED`.

## Build / Package

```bash
npm run build
npm run package
```

Primary outputs:
- `release/SENSEQUALITY Optimizer Setup <version>.exe`
- `release/SENSEQUALITY Optimizer Setup <version>.exe.blockmap`
- `release/latest.yml`

## Update + Release Architecture

### Source of truth
- Private repo creates releases from packaged artifacts.

### Public distribution target
- `Kirneill/TunedPCApp` hosts binaries only.
- No source code published there.

### Updater target
- App updater and builder publish target both point to `Kirneill/TunedPCApp`:
  - `electron/updater.ts`
  - `electron-builder.yml` (`publish.owner/repo`)

## Mirror Workflow

Workflow file:
- `.github/workflows/mirror-public-release.yml`

Triggers:
- `release.published` (automatic)
- `workflow_dispatch` with input `tag` (manual backfill/rerun)

Behavior:
1. Downloads `*.exe`, `*.exe.blockmap`, `latest*.yml` from private release.
2. Normalizes installer filenames to match `latest.yml` `path` value.
3. Creates/updates same tag release in `Kirneill/TunedPCApp`.
4. Replaces stale assets on rerun.

Token model:
- Reads private release metadata with `${{ github.token }}`.
- Writes public releases with secret `PUBLIC_RELEASES_PAT`.

Required secret in private repo:
- `PUBLIC_RELEASES_PAT` (fine-grained PAT)
- Repo access: `Kirneill/TunedPCApp`
- Permission: `Contents: Read and write`

Important:
- Public target repo must have at least one commit before releases can be created.

## Release Checklist (Short)

1. `npm run package`
2. Create/publish release in private repo with installer + blockmap + latest.yml.
3. Confirm mirror workflow succeeds in Actions.
4. Confirm same tag/assets exist in `https://github.com/Kirneill/TunedPCApp/releases`.

Manual backfill example:
```bash
gh workflow run mirror-public-release.yml --repo Kirneill/sensequality-optimizer -f tag=v1.0.5
```

## Core App Architecture (Minimal)

- `electron/main.ts`: window lifecycle, IPC wiring, app bootstrap.
- `electron/preload.ts`: context bridge API exposed as `window.sensequality`.
- `electron/updater.ts`: update checks/download/install state.
- `electron/ipc/handlers.ts`: optimization execution, backups, diagnostics hooks.
- `src/components/layout/TitleBar.tsx`: top-left app branding text.
- `scripts/*.ps1`: bundled optimization scripts run by Electron process.

