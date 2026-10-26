# Tasks: fix-105-clean-kubelet-dir-on-post-stop

## 1. Templates

- [x] 1.1 Rewrite `jobs/k3s-agent/templates/bin/post-stop.erb`: run `k3s-killall.sh` unless `k3s.do-not-killall-on-post-stop` is true (no `exit 0` inside branches), tolerate its failure with an echo, then `rm -rf /var/vcap/data/k3s-agent/kubelet/* 2>/dev/null || true` with a log line, `exit 0` at the end.
- [x] 1.2 Rewrite `jobs/k3s-server/templates/bin/post-stop.erb` identically with `/var/vcap/data/k3s-server/kubelet` and the server killall path.
- [x] 1.3 Fix `jobs/k3s-server/templates/bin/k3s-killall.sh` lines 82-84: `/var/vcap/data/k3s-agent/kubelet/...` → `/var/vcap/data/k3s-server/kubelet/...` (keep the bosh-layout comments).

## 2. Validate

- [x] 2.1 `bosh -n int` both job specs still succeed.
- [x] 2.2 Build dev release: `bosh -n create-release --version dev --name k3s --tarball=/tmp/k3s-dev.tgz --force`; extract job tarballs and render/inspect `bin/post-stop` for both jobs (paths per job, cleanup present in both killall branches) and `k3s-killall.sh` server paths.
- [x] 2.3 Confirm `grep -c "k3s-agent" jobs/k3s-server/templates/bin/k3s-killall.sh` no longer matches kubelet paths.

## 3. Ship

- [x] 3.1 Commit: `fix: clean kubelet dir on post-stop and fix server killall paths` with `Fixes #105` in the body.
- [ ] 3.2 Open a PR against master (blocked on gh authentication as for #110 — defer if still unauthenticated).
