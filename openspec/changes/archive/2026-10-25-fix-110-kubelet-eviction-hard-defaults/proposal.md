# Proposal: fix-110-kubelet-eviction-hard-defaults

## Why

k3s hardcodes `--eviction-hard=undefined,<nil>` when starting the kubelet (see [k3s-io/k3s#11312](https://github.com/k3s-io/k3s/issues/11312)), which wipes out ALL vanilla kubelet hard-eviction thresholds — including `nodefs.inodesFree` and `imagefs.inodesFree`. As a consequence, inode exhaustion on the node/container/image filesystems triggers no pod eviction and no node pressure signal, making nodes unstable and unrecoverable without a reboot (observed in [paas-templates#2669](https://github.com/orange-cloudfoundry/paas-templates/issues/2669), tracked as [k3s-wrapper-boshrelease#110](https://github.com/orange-cloudfoundry/k3s-wrapper-boshrelease/issues/110)).

## What Changes

- Change the default of `k3s.kubelet-args` in both `jobs/k3s-agent/spec` and `jobs/k3s-server/spec` from `[]` to a list containing:
  `eviction-hard=imagefs.available<15%,memory.available<100Mi,nodefs.available<10%,pid.available<10%,nodefs.inodesFree<5%,imagefs.inodesFree<6%`
  (vanilla kubelet defaults extended with inode thresholds, matching the workaround validated in k3s#11312).
- Document in both job specs that k3s disables vanilla eviction defaults, and that overriding `k3s.kubelet-args` replaces this protection (standard BOSH property override semantics).
- No template changes: the existing `--kubelet-arg` rendering loop in `ctl.erb` already emits each list entry.

No breaking change: only a property default changes. Operators who explicitly set `k3s.kubelet-args` keep their current behavior and must re-add the flag themselves to regain the protection.

## Capabilities

### New Capabilities
- `kubelet-eviction-hard-defaults`: k3s-server and k3s-agent jobs start their kubelet with explicit hard-eviction thresholds (memory, node/imagefs availability and inodes, pids) by default, restoring vanilla kubelet node-pressure protection neutralized by k3s.

### Modified Capabilities

(none — `openspec/specs/` is empty; this is the first spec for this behavior)

## Impact

- `jobs/k3s-agent/spec` (`k3s.kubelet-args` default + description)
- `jobs/k3s-server/spec` (`k3s.kubelet-args` default + description)
- Rendered `bin/ctl` of both jobs gains one more `--kubelet-arg=eviction-hard=...` flag by default (CLI flag takes precedence over the broken k3s default).
- Runtime behavior: kubelets will evict pods and signal node pressure under inode/disk/memory pressure where they previously did nothing. No manifest or API changes.
