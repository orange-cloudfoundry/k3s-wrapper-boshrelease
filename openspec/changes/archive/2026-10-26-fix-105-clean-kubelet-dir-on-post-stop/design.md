# Design: fix-105-clean-kubelet-dir-on-post-stop

## Context

See proposal.md - Why. Current state:

- `post-stop.erb` (agent/server) wraps the whole script body in `<% if_p('k3s.do-not-killall-on-post-stop') do %>`; the skip branch ends in `exit 0`, so any code added after the ERB block would never run.
- `k3s-killall.sh` unmounts and removes `kubelet/pods`, `kubelet/plugins`, `kubelet/plugins/kubernetes.io/csi` — but not the rest of the kubelet root (`plugins_registry/`, `pki/`, journal files, leftover local volumes).
- The server copy of `k3s-killall.sh` is byte-identical to the agent copy, including `/var/vcap/data/k3s-agent/...` paths (bug).
- BOSH runs `post-stop` before `start` as well as on stop; a cleanup in post-stop therefore also runs at startup.

## Goals / Non-Goals

**Goals:**
- No kubelet residue survives a stop, in all branches (killall ok / skipped / failed).
- Fix the server killall paths in the same change.

**Non-Goals:**
- No new BOSH property (unconditional cleanup — operator decision recorded during issue review).
- Not touching `ctl.erb`, drain, or the agent killall content (beyond what already exists).
- Not addressing issue #154 (killall log noise) although in the same files.

## Decisions

**D1: Clean `rm -rf /var/vcap/data/k3s-<job>/kubelet/*` in post-stop, after the killall block, instead of inside `k3s-killall.sh`.**
- `k3s-killall.sh` is a vendored upstream script with minimal bosh adaptations; keeping adaptations tagged and few eases future k3s upgrades. Post-stop is wrapper-owned ERB, free to change.
- Running cleanup even when killall is skipped or failed matches the requirement: residue removal is the goal, killall is best-effort.

**D2: Restructure post-stop instead of appending after the current block.** The existing skip-branch `exit 0` makes appending impossible. New shape: plain script; `if_p` only around the killall if/else (no exits inside); cleanup; `exit 0` at the very end.

**D3: `rm -rf <dir>/*` with `|| true` and a log line, not deleting the directory itself.** The dir is BOSH-managed (`data` persistent-disk layout, owned by vcap); recreating it is `ctl`'s/pre-start's concern — keeping the dir avoids surprises with ownership/mounts.

**D4: Fix server killall paths (82-84) in the same PR.** Without it the server never unmounts pods/plugins, and `rm -rf` would then fail on mounted paths; the two defects share one root cause (copy-paste).

## Risks / Trade-offs

- [Cleanup also runs at every start (BOSH post-stop-before-start)] → intended: after a real stop only residue remains; wiping it is the fix. First-ever start has an empty dir — no-op.
- [Local hostPath/empty-dir data intentionally kept across restarts is destroyed] → empty-dirs are already destroyed by killall's pods unmount; the issue explicitly asks for full cleanup. Documented in the script comment.
- [`rm -rf` on a still-mounted path would delete mountpoint contents] → killall unmounts pods/plugins beforehand; failure is non-fatal by design (`|| true` + exit 0), inode leak residue is strictly better than today.
- [post-stop hiding killall errors] → failure is echoed; exit code stays 0 to keep BOSH stop semantics (today's script also always exits 0).

## Migration Plan

Regular BOSH update; no state migration. Rollback = redeploy previous release.
