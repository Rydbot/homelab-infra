# homelab-infra

GitOps repo for my homelab Kubernetes cluster (Talos) managed by Flux. This repo defines both cluster infrastructure (storage, networking, observability) and application workloads (media stack, Immich, Vaultwarden, WoW servers, etc).

## How this repo is applied

Flux is bootstrapped in the cluster and continuously syncs `./clusters/home` from the `main` branch:

- Flux source + sync: `clusters/home/flux-system/gotk-sync.yaml`
- Root Kustomization: `clusters/home/kustomization.yaml`

General workflow:

1. Change manifests in this repo.
2. Commit + push to `main`.
3. Flux reconciles and applies changes (or you trigger a reconcile manually).

Useful commands:

```bash
# Flux status
flux get kustomizations -A
flux get sources git -A

# Force a reconcile (examples)
flux -n flux-system reconcile kustomization apps-wotlk --with-source
flux -n flux-system reconcile kustomization apps-arr --with-source
flux -n flux-system reconcile kustomization infrastructure --with-source
```

## Repo layout

- `clusters/`
  - `clusters/home/`: Flux entrypoint for the “home” cluster (what gets applied)
  - `clusters/home/apps/`: Flux Kustomizations for app groups (arr/homepage/wotlk/etc)
  - `clusters/home/infrastructure/`: Flux Kustomizations for infrastructure components
- `apps/`: Kubernetes manifests for workloads (mostly plain YAML + kustomize)
  - `apps/arr/` is represented by the individual apps (`apps/sonarr`, `apps/radarr`, `apps/prowlarr`, `apps/sabnzbd`, etc)
  - `apps/immich/`, `apps/vaultwarden/`, `apps/homepage/`, `apps/jellyfin/`, `apps/jellyseerr/`
  - `apps/wotlk/` and `apps/wow/`: WoW server stacks
- `infra/`: cluster-level services (Longhorn, monitoring, Cloudflared, WireGuard, namespaces, etc)
- `secrets/`: SOPS-encrypted Kubernetes Secrets/credentials (`*.enc.yaml`)
- `ops/`: operational helpers (SQL, image build inputs, WireGuard scripts, etc)

## WotLK server stack

The Wrath server runs as a dedicated stack under `apps/wotlk/`:

- Core services:
  - `apps/wotlk/worldserver-deployment.yaml`
  - `apps/wotlk/authserver-deployment.yaml`
  - `apps/wotlk/mariadb-statefulset.yaml`
- Server configuration:
  - `apps/wotlk/worldserver-config.yaml` (templates rendered into `/etc` on startup)
  - `apps/wotlk/authserver-config.yaml`
  - `apps/wotlk/acore-source-configmap.yaml` (AzerothCore repo + ref)
- Modules (playerbots/AH/transmog/etc):
  - `apps/wotlk/worldserver-config.yaml` contains the module configs (e.g., `mod_ahbot.conf`)
  - `apps/wotlk/ahbot-cleanup-cronjob.yaml` removes unwanted AH items
- Maintenance / scheduled jobs:
  - `apps/wotlk/realm-upsert-cronjob.yaml` (realm address updates)
  - `apps/wotlk/restart-cronjob.yaml` (scheduled restarts + announcements)
  - `apps/wotlk/stats-snapshot-cronjob.yaml` (stats snapshots)
  - `apps/wotlk/playerbots-normalize-ascii-cronjob.yaml`
  - `apps/wotlk/tokenstore-dailies-cronjob.yaml` (custom daily quest content)

Notes:
- WotLK pods run on `metal7` and use `hostNetwork` (see `apps/wotlk/worldserver-deployment.yaml`).
- New images are pushed to GHCR and referenced directly in the deployments.
- Flux applies changes on push to `main`.

## WotLK admin portal

The account management / admin portal is served by the `accountmgr` sidecar container:

- Portal source lives in `apps/wotlk/accountmgr-configmap.yaml` (inline PHP + assets).
- Exposed via `apps/wotlk/accountmgr-service.yaml`.
- Access can be gated with Cloudflare Access and invite codes (see portal env vars and logic in the configmap).
- Patch download support: the portal can serve a client patch when present under `/client/Data/patch-S.mpq`.

When updating the portal:
1. Edit `apps/wotlk/accountmgr-configmap.yaml`.
2. Commit + push to `main`.
3. Reconcile the WotLK kustomization (or wait for Flux).

## Secrets (SOPS)

This repo uses Mozilla SOPS with Age to store secrets safely in Git.

- SOPS rules live in `.sops.yaml`
- Flux decrypts SOPS secrets using an Age key stored in-cluster (see `clusters/home/flux-system/gotk-sync.yaml` `spec.decryption`)

Typical flow:

```bash
# Encrypt a secret for committing (example)
sops --encrypt --in-place secrets/my-secret.enc.yaml

# Edit an encrypted secret
sops secrets/my-secret.enc.yaml
```

Notes:

- Do not commit plaintext secrets.
- Keep your Age private key out of Git and back it up securely.

## Renovate (dependency/image updates)

Renovate is configured in `renovate.json` and runs via GitHub Actions:

- Workflow: `.github/workflows/renovate.yml`
- It pins container image digests so updates can be reviewed/merged via PRs.
- WoW stacks are excluded from Renovate updates (see `renovate.json` ignore rules).

## Adding/updating apps

High-level pattern:

1. Add/update YAML in `apps/<app>/` (and `kustomization.yaml` inside that folder).
2. Ensure the app is referenced by the relevant Flux Kustomization under `clusters/home/apps/`.
3. Commit + push; Flux rolls it out.

## Troubleshooting

- See what Flux thinks is applied:
  - `flux get kustomizations -A`
  - `flux logs -A --kind Kustomization --follow`
- See what Kubernetes is doing:
  - `kubectl get pods -A`
  - `kubectl -n <ns> describe deploy/<name>`
  - `kubectl -n <ns> logs deploy/<name> --tail=200`

## Notes

This is a personal homelab repo; manifests are opinionated and tailored to the “home” cluster.
