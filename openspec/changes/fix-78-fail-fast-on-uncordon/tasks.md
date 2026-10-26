# Tasks: fix-78-fail-fast-on-uncordon

Note: the template changes below were already prototyped in the working tree while
diagnosing issue #78; tasks 1.x and 2.x are marked done accordingly, 3.x remains.

## 1. k3s-server post-start

- [x] 1.1 In `jobs/k3s-server/templates/bin/post-start.erb`, remove the broken readiness probe (`timeout 300 sh -c 'until nc ...'` whose trailing `kubectl get pods` never executed)
- [x] 1.2 Wrap the `uncordon` call in a bounded retry: `timeout 300 bash -c "until <uncordon>; do sleep 5; done"`
- [x] 1.3 On failure after the retry window, print `ERROR: failed to uncordon node $K3S_NODE_NAME: ...` and `exit 1`

## 2. k3s-agent post-start

- [x] 2.1 In `jobs/k3s-agent/templates/bin/post-start.erb`, apply the same bounded retry loop to the `uncordon` call, keeping the existing `>> $JOB_DIR/post-start.log` / `2>> $JOB_DIR/post-start-stderr.log` redirects inside the retried command
- [x] 2.2 On failure after the retry window, print the same error and `exit 1`
- [x] 2.3 Make the kubelet healthz check `exit 1` when it prints "kubelet is down, post-start failure"

## 3. Validation

- [x] 3.1 Render both templates for all property variants (`k3s.drain.kubeconfig` set/unset, `k3s.master_vip_api` set/unset, `k3s.node_name_prefix` unset) and check the generated scripts with `bash -n`
- [x] 3.2 Verify packaging with `bosh create-release --name k3s --version 0+dev.test` from a clean git worktree containing the change
- [x] 3.3 Confirm no remaining `uncordon` call sites ignore the exit status (`grep -rn uncordon jobs/`)

## 4. Delivery

- [ ] 4.1 Commit both templates with a Conventional Commit message (`fix: ...`) referencing issue #78
- [ ] 4.2 Open a PR (CI builds a dev release per commit)
