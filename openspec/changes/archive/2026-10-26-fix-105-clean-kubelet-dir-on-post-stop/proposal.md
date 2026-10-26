# Proposal: fix-105-clean-kubelet-dir-on-post-stop

## Why

On `bosh stop`, the k3s-server/k3s-agent jobs kill all processes via `k3s-killall.sh`, but leftover data in `/var/vcap/data/k3s-<job>/kubelet` is not cleaned. Residual files exhaust inodes and prevent the node from restarting (issue #105). Additionally, the server's `k3s-killall.sh` contains a copy-paste bug: its kubelet cleanup paths point to `/var/vcap/data/k3s-agent/...` instead of `/var/vcap/data/k3s-server/...`, so the server node does not even unmount its pod/plugin mounts.

## What Changes

- `post-stop.erb` of both `k3s-agent` and `k3s-server` jobs: after invoking (or skipping) `k3s-killall.sh`, unconditionally remove the content of `/var/vcap/data/k3s-<job>/kubelet/`. The killall failure no longer aborts the cleanup, and the post-stop script still exits 0.
- Restructure `post-stop.erb` so the `k3s.do-not-killall-on-post-stop` branch no longer `exit 0`s before the cleanup step.
- Fix `jobs/k3s-server/templates/bin/k3s-killall.sh` lines 82-84: `k3s-agent` paths → `k3s-server` paths.
- No new BOSH property: cleanup is unconditional (decision validated during exploration of issue #105).

## Capabilities

### New Capabilities
- `node-lifecycle-cleanup`: k3s jobs leave no kubelet residue on the node filesystem after a BOSH stop, so a restarted node does not inherit inode/mount pollution.

### Modified Capabilities

(none)

## Impact

- `jobs/k3s-agent/templates/bin/post-stop.erb`, `jobs/k3s-server/templates/bin/post-stop.erb`
- `jobs/k3s-server/templates/bin/k3s-killall.sh` (3 path lines)
- Runtime: `bosh stop` (and the post-stop hook BOSH runs before start) wipes the kubelet data dir; acceptable because after `k3s-killall.sh` only residue remains, and that residue is precisely what caused node restart failures.
- No spec/property changes; no manifest changes.
