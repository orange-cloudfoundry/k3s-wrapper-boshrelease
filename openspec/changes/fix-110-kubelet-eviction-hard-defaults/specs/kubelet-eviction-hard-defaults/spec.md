## Purpose

Ensure k3s-server and k3s-agent nodes start their kubelet with explicit hard-eviction thresholds (memory, node/imagefs availability, inodes, pids) by default, restoring the vanilla kubelet node-pressure protection that k3s neutralizes at startup.

## ADDED Requirements

### Requirement: Kubelet starts with hard-eviction thresholds by default
The `k3s-agent` job SHALL start its kubelet with the hard-eviction thresholds `imagefs.available<15%,memory.available<100Mi,nodefs.available<10%,pid.available<10%,nodefs.inodesFree<5%,imagefs.inodesFree<6%` when the operator does not override the `k3s.kubelet-args` property, overriding the k3s startup default that disables all vanilla kubelet eviction thresholds.

#### Scenario: Agent node with default properties
- **WHEN** a k3s-agent instance is (re)started with `k3s.kubelet-args` left at its default
- **THEN** the k3s process command line contains `--kubelet-arg=eviction-hard=imagefs.available<15%,memory.available<100Mi,nodefs.available<10%,pid.available<10%,nodefs.inodesFree<5%,imagefs.inodesFree<6%`

#### Scenario: Server node with default properties
- **WHEN** a k3s-server instance is (re)started with `k3s.kubelet-args` left at its default
- **THEN** the k3s process command line contains the same `--kubelet-arg=eviction-hard=...` flag as the agent

### Requirement: Operator override of kubelet args is preserved
An operator who explicitly sets the `k3s.kubelet-args` property SHALL have their value used verbatim as the complete kubelet-args list, including replacing the default hard-eviction flag; the job specs SHALL document that removing the default flag restores k3s's behavior of disabling vanilla eviction thresholds.

#### Scenario: Operator supplies their own kubelet-args
- **WHEN** `k3s.kubelet-args` is set to a custom list, e.g. `["max-pods=250"]`
- **THEN** only `--kubelet-arg=max-pods=250` is rendered from this property
- **AND** no default `eviction-hard` flag is added

#### Scenario: Operator supplies their own eviction-hard value
- **WHEN** `k3s.kubelet-args` includes a custom `eviction-hard=...` entry
- **THEN** the rendered kubelet receives the operator's threshold and not the default one
