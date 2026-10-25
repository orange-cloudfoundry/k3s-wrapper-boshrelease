# AGENTS.md

BOSH release (orange-cloudfoundry) deploying k3s clusters: a very thin wrapper
around the k3s binary, orchestrated by BOSH jobs/monit. Companion releases
provide the actual binaries/packages: k3s-packages-boshrelease,
k9s-package-boshrelease, nerdctl-package-boshrelease (this repo's `packages/`
is empty by design).

## Repository layout

- `jobs/k3s-server`, `jobs/k3s-agent` — the only two jobs. Each is: `spec` (ERB,
  links + properties), `monit`, `templates/*.erb` → lifecycle hooks
  (`bin/pre-start`, `bin/ctl`, `bin/drain`, `bin/post-start`...) and config
  files (`config/*.erb`). `spec.yml` is the rendered spec; do not edit by hand.
- `manifests/k3s.yml` — base deployment manifest (uses vars, ops-files).
- `manifests/operators/` — bosh ops-files (create.yml, use-network.yml).
- `config/` — bosh final release config (blobs.yml, final.yml). Never commit
  `config/private.yml`, `releases/*.tgz`, `dev_releases/`, `blobs/`.
- `releases/` — final release tarballs + `latest` symlinks.

## Conventions

- k3s properties are all namespaced `k3s.*` and mirror k3s CLI flags
  (e.g. `k3s.kube-apiserver-arg` → `--kube-apiserver-arg`). When adding a
  property, document it in `jobs/*/spec` with the k3s flag group prefix
  (`(components)`, `(networking)`, `(db)`...) and keep server/agent specs
  consistent where the flag applies to both.
- ERB templates render into the job dir; reference packages/links via
  `link(...)`/`p(...)` helpers, and consume the k3s binary through
  `jobs/*/templates/bin/ctl.erb` env (K3S_* env vars).
- Node naming: `<instance-group-name>-<index>` unless `k3s.node_name_prefix` is set.

## Dev workflow

- Dev shell via devbox: `devbox shell` (bosh-cli 7.x, yq, jq, crane, kind, ...).
- No test suite (`devbox run test` is a stub). Validate changes with:
  - `bosh int manifests/k3s.yml -o manifests/operators/create.yml` to lint manifests.
  - `bosh create-release --name k3s --dev` to verify jobs/templates render.
- CI (GitHub Actions): PRs build a dev release (artifact in `on-PRs-commits.yml`);
  every commit on master auto-bumps and publishes a final release
  (`auto-release-on-master.yml`).

## Commits & releases

- Conventional Commits enforced by release automation:
  `fix:` → patch, `feat:`/`feature:` → minor, `major:` or `feat!:` → major;
  anything else defaults to patch.
- Prefer PRs (dev release auto-built per commit); direct-to-master also
  triggers a final release. See CONTRIBUTING.md for the full flow.
- Renovate (renovate.json5) manages tool/bump deps; do not bump those by hand.
