# TOOLS.md - Environment Notes

## Task Tracker (yx)

- Binary: `yx` (in PATH)
- State dir: `/home/yakob/yakthang/.yaks`
- All commands run from `/home/yakob/yakthang`

## Worker Management

- `./spawn-worker.sh` -- Spawn Docker worker containers
- `./check-workers.sh` -- Monitor worker status (supports `--blocked`, `--wip`)
- Workers run as Docker containers with the `yak-worker` image
- One worker per sub-repo to avoid concurrent edits

## Docker

- Socket: default `/var/run/docker.sock`
- Worker image: `yak-worker` (built from `worker.Dockerfile`)
- yakob user is in the `docker` group

## Zellij

- Session name: set via `ZELLIJ_SESSION_NAME` env var in systemd
- Layout: `/home/yakob/yakthang/orchestrator.kdl`

## Git

- Repos live under `/home/yakob/yakthang/` (main) and sub-repos within

## SSH

- No custom hosts configured yet
