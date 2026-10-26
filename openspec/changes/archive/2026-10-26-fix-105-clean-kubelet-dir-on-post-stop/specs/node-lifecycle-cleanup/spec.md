## Purpose

Ensure k3s BOSH jobs leave no kubelet residue on the node filesystem after a stop, so a restarted node does not inherit inode or mount pollution that previously prevented it from coming back.

## ADDED Requirements

### Requirement: Kubelet data dir is cleaned on post-stop
When the `k3s-agent` or `k3s-server` post-stop hook runs, the system SHALL remove the content of the job's kubelet root directory (`/var/vcap/data/k3s-agent/kubelet` respectively `/var/vcap/data/k3s-server/kubelet`), whether or not `k3s-killall.sh` was executed or succeeded, and the post-stop hook SHALL exit successfully.

#### Scenario: Stop with killall enabled (default)
- **WHEN** post-stop runs with `k3s.do-not-killall-on-post-stop` false
- **THEN** `k3s-killall.sh` is invoked
- **AND** the kubelet root directory is empty afterwards

#### Scenario: Stop with killall skipped
- **WHEN** post-stop runs with `k3s.do-not-killall-on-post-stop` true
- **THEN** `k3s-killall.sh` is not invoked
- **AND** the kubelet root directory is still emptied

#### Scenario: Killall failure does not block cleanup
- **WHEN** `k3s-killall.sh` exits non-zero
- **THEN** post-stop still performs the kubelet directory cleanup
- **AND** post-stop exits 0

### Requirement: Server killall targets server paths
The `k3s-server` job's `k3s-killall.sh` SHALL unmount and remove mounts under `/var/vcap/data/k3s-server/kubelet` (pods, plugins, csi plugins) and never under `/var/vcap/data/k3s-agent/kubelet`.

#### Scenario: Server node stop
- **WHEN** `k3s-killall.sh` of the k3s-server job runs
- **THEN** its kubelet unmount-and-remove operations reference only `/var/vcap/data/k3s-server/kubelet/...` paths
