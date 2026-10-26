# Tasks: fix-110-kubelet-eviction-hard-defaults

## 1. Update job specs

- [x] 1.1 In `jobs/k3s-agent/spec`, change the `k3s.kubelet-args` default from `[]` to the list containing `eviction-hard=imagefs.available<15%,memory.available<100Mi,nodefs.available<10%,pid.available<10%,nodefs.inodesFree<5%,imagefs.inodesFree<6%`, and extend its description: k3s disables vanilla kubelet eviction defaults (k3s-io/k3s#11312); overriding this property replaces this protection.
- [x] 1.2 In `jobs/k3s-server/spec`, apply the same default and description to `k3s.kubelet-args` (keep server/agent wording consistent).

## 2. Validate

- [x] 2.1 Render both job specs and confirm valid YAML: `bosh int jobs/k3s-agent/spec` and `bosh int jobs/k3s-server/spec` (or `bosh interpolate`).
- [x] 2.2 Build a dev release to verify templates still render: `bosh create-release --name k3s --dev`.
- [x] 2.3 Grep the rendered dev release package (or inspect `bin/ctl` from a created deployment if available) to confirm `--kubelet-arg=eviction-hard=imagefs.available<15%,memory.available<100Mi,nodefs.available<10%,pid.available<10%,nodefs.inodesFree<5%,imagefs.inodesFree<6%` appears once by default and disappears when `k3s.kubelet-args` is overridden (check with `bosh int manifests/k3s.yml -o <override ops-file>` or spec-level interpolation).

## 3. Ship

- [x] 3.1 Commit with a Conventional Commit message, e.g. `fix: restore vanilla kubelet hard-eviction defaults with inode thresholds` and `Fixes #110` in the body.
- [ ] 3.2 Open a PR against master (CI builds a dev release per commit). -- deferred: gh CLI unauthenticated, commits kept local on feature-ai-agentic-authoring.
