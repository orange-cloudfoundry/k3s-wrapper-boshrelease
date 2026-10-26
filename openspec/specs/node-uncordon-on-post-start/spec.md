# node-uncordon-on-post-start

## Purpose

Ensure the post-start hooks of the k3s-server and k3s-agent BOSH jobs bring their node back into a schedulable (uncordoned) state after start/drain, and that any inability to do so is surfaced through the BOSH job status instead of being silently ignored.

## Requirements

### Requirement: Post-start uncordons the node once the k8s API accepts requests
After the k3s-server job starts, and after the k3s-agent job starts when `k3s.drain.kubeconfig` is set, the post-start hook SHALL uncordon the job's node (`<instance-group>-<index>`, or `<k3s.node_name_prefix>-<index>`) against the k8s API.

#### Scenario: API already available
- **WHEN** post-start runs and the k8s API accepts the uncordon request on the first attempt
- **THEN** the node is uncordoned
- **AND** post-start continues without waiting for the retry interval

### Requirement: Post-start tolerates a not-yet-ready k8s API with a bounded retry
Because the k8s API may not accept requests immediately after start, the post-start hook SHALL retry a failed uncordon at a regular interval for a bounded period of at most 5 minutes, and SHALL succeed as soon as one attempt succeeds.

#### Scenario: API becomes reachable during the retry window
- **WHEN** the first uncordon attempts fail because the k8s API is unreachable or the node object does not exist yet
- **AND** the API starts accepting uncordon within the 5-minute retry window
- **THEN** post-start completes successfully without consuming the full retry window

### Requirement: Post-start fails when the node could not be uncordoned
If no uncordon attempt has succeeded by the end of the bounded retry window, the post-start hook SHALL write a clear error identifying the node to its standard output and exit non-zero, so that BOSH reports the job as failed instead of silently leaving the node cordoned.

#### Scenario: API unreachable beyond the retry window
- **WHEN** every uncordon attempt during the 5-minute retry window fails because the k8s API is unreachable
- **THEN** post-start prints an error naming the node
- **AND** post-start exits non-zero
- **AND** BOSH marks the instance's job as failed

#### Scenario: Uncordon rejected by the API
- **WHEN** the k8s API answers uncordon requests but rejects them (e.g. forbidden) during the whole retry window
- **THEN** post-start exits non-zero with the same kind of error

#### Scenario: Failure is not hidden in log files
- **WHEN** uncordon output is redirected to the job's post-start log files (k3s-agent)
- **THEN** the post-start hook's exit status still reflects the uncordon failure

### Requirement: Agent post-start fails when kubelet is unhealthy
When the kubelet healthz endpoint of the k3s-agent job does not report healthy, the post-start hook SHALL exit non-zero instead of only printing a failure message.

#### Scenario: Kubelet healthz down
- **WHEN** `http://127.0.0.1:10248/healthz` does not answer 200 or 301
- **THEN** post-start prints the failure message
- **AND** post-start exits non-zero

#### Scenario: Kubelet healthz up
- **WHEN** `http://127.0.0.1:10248/healthz` answers 200 or 301
- **THEN** post-start proceeds with the uncordon step
