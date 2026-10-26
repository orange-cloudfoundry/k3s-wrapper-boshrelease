# Proposal: fix-78-fail-fast-on-uncordon

## Why

The `post-start` hooks of both `k3s-server` and `k3s-agent` jobs run `kubectl uncordon` but ignore its exit code (the agent redirects output to log files, the server never checks either), so a failed uncordon is silently swallowed. BOSH then reports a healthy deployment while the node stays cordoned, and failures only surface much later as downstream side effects (workloads and kustomizations never scheduling, smoke tests timing out on fresh instances — see issue #78). Operators need the BOSH job status to surface uncordon failures so that canary/rolling updates stop propagating a broken cluster state.

## What Changes

- `jobs/k3s-server/templates/bin/post-start.erb`: replace the broken API-readiness probe (a `timeout 300 sh -c 'until nc ...'` line whose trailing `kubectl get pods` was passed as inert positional args and never executed) and the unchecked `uncordon` call with a bounded retry loop (300s, 5s interval) around `uncordon`; if it still fails, print a clear error and exit non-zero so BOSH marks the job failed.
- `jobs/k3s-agent/templates/bin/post-start.erb`: same bounded retry-and-fail treatment for the `uncordon` call (keeping its existing log redirects); additionally, the kubelet healthz check that already prints "post-start failure" now actually exits non-zero instead of continuing.
- No new properties, no spec changes: the 300s retry budget mirrors the timeout already used (buggily) by the server template.

## Capabilities

### New Capabilities

- `node-uncordon-on-post-start`: post-start hooks of k3s-server and k3s-agent must uncordon the node once the k8s API accepts requests, retry with a bounded timeout while the API is still warming up, and fail the BOSH job (non-zero exit, clear error) when the node could not be uncordoned or, on the agent, when kubelet is unhealthy.

### Modified Capabilities

<!-- none: node-lifecycle-cleanup covers post-stop behavior only; post-start requirements are new -->

## Impact

- Affected files: `jobs/k3s-server/templates/bin/post-start.erb`, `jobs/k3s-agent/templates/bin/post-start.erb` (templates; `spec.yml` files unchanged — no property changes).
- Behavioral impact: deployments where the k8s API stays unreachable for >300s, or where uncordon is rejected, now FAIL in BOSH instead of silently succeeding; operators may see previously-hidden failures surface on existing pipelines.
- Downstream (coab/strimzi smoke tests): genuinely failed clusters stop advancing to the smoke-test phase with cordoned nodes.
