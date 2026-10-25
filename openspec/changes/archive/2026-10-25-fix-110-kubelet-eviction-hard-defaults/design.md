# Design: fix-110-kubelet-eviction-hard-defaults

## Context

See proposal.md - Why. Current state of the wrapper:

- `k3s.kubelet-args` (default `[]`) is rendered by a loop in `jobs/k3s-agent/templates/bin/ctl.erb` and `jobs/k3s-server/templates/bin/ctl.erb` as one `--kubelet-arg=<entry>` per list element.
- The kubelet embedded in k3s receives a `--kubelet-arg=config=.../kubelet-config.yaml` flag whenever `k3s.kubelet-config-file` is set (it has a default with `shutdownGracePeriod`).
- kubelet precedence: a CLI flag overrides the same key in the kubelet config file; for repeated `--kubelet-arg` flags, k3s passes them through and kubelet keeps the last occurrence.

## Goals / Non-Goals

**Goals:**
- Restore hard-eviction thresholds (including inode thresholds) with the smallest diff, identical on server and agent.
- Keep operator override semantics unchanged and standard (BOSH property default replacement).

**Non-Goals:**
- Not tuning `kube-reserved`/`system-reserved` or per-environment thresholds (paas-templates-level concern).
- Not adding a dedicated `k3s.eviction-hard` property.
- Not cleaning kubelet dirs at stop (issue #105) nor fail-fast on uncordon (#78).

## Decisions

**D1: Deliver the threshold via `k3s.kubelet-args` default (approach A) rather than `k3s.kubelet-config-file` (approach B).**
- A is a two-line spec diff reusing the existing rendering loop; no template change.
- B is semantically cleaner (eviction is kubelet-config material) but couples the thresholds to the `shutdownGracePeriod` default: an operator overriding `k3s.kubelet-config-file` to keep their own evictionHard would silently lose GraceFull Node Shutdown, and vice versa.
- Precedence check for A: k3s's own broken default is injected as a flag; our flag comes from user-supplied `--kubelet-arg` entries which k3s appends after its defaults, and kubelet keeps the last occurrence → our value wins.
- Alternative considered and rejected: new dedicated property (`k3s.eviction-hard`) — more surface to document in two specs, no added value over reusing the generic list.

**D2: Same default in both jobs.** The server also runs a kubelet and its containerd state lives on the same node filesystems; inode exhaustion is equally fatal there. Keeps server/agent specs consistent per repo conventions.

**D3: Threshold values** = vanilla kubelet defaults (`memory.available<100Mi`, `nodefs.available<10%`, `imagefs.available<15%`) + the values validated in the k3s#11312 workaround (`pid.available<10%`, `nodefs.inodesFree<5%`, `imagefs.inodesFree<6%`).

## Risks / Trade-offs

- [Operators already setting `k3s.kubelet-args` keep no protection] → standard BOSH default-override semantics; documented in both spec descriptions and in this change; acceptable since they explicitly own the list.
- [Coexistence with an operator-placed `evictionHard:` inside `k3s.kubelet-config-file`] → the CLI flag wins; documented; operators wanting file-based config can drop the flag by overriding the property.
- [Behavior change on deployment: pods start getting evicted under pressure where nothing happened before] → this is the intent; evictions happen before node loss. Rolling deploy per BOSH canaries; no migration needed.
- [Flag string contains `<` and `,`] → rendered inside a double-quoted `FLAGS` string in ctl.erb like existing flags (e.g. `node-taint`); no shell metacharacter issue beyond `<` which is safe inside double quotes at assignment time.

## Migration Plan

Deploy as a regular BOSH update: property default change → kubelet restart with new flags. Rollback = redeploy previous release or set `k3s.kubelet-args: []` in the manifest.
