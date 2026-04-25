# Pinned Upstream Versions

Resolved on 2026-04-25 from official release APIs, package indexes, and image registries.

| Component | Previous | Current/latest | Status | Reference |
|---|---:|---:|---|---|
| Kubernetes kubeadm config | `v1.34.0` | `v1.36.0` | Updated | `cluster/kubeadm/kubeadm-config.yaml` |
| Kubernetes apt repository minor | `v1.34` | `v1.36` | Updated | `cluster/kubeadm/install-tools-ubuntu.sh` |
| Argo CD | `v3.3.8` | `v3.3.8` | Current | `https://raw.githubusercontent.com/argoproj/argo-cd/v3.3.8/manifests/install.yaml` |
| Argo CD Image Updater | `v1.1.1` | `v1.1.1` | Current | `https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/v1.1.1/config/install.yaml` |
| ingress-nginx | `controller-v1.15.1` | `controller-v1.15.1` | Current | `cluster/ingress-nginx/kustomization.yaml` |
| metrics-server | `v0.8.1` | `v0.8.1` | Current | `https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.8.1/components.yaml` |
| cert-manager | new | `v1.20.2` | Pinned latest | `https://github.com/cert-manager/cert-manager/releases/download/v1.20.2/cert-manager.yaml` |
| Calico | `v3.31.4` | `v3.31.5` | Updated | `cluster/network/calico/kustomization.yaml` |
| Sealed Secrets controller | `v0.32.1` | `v0.36.6` | Updated | `cluster/sealed-secrets/controller.yaml` |
| kubeseal | `v0.36.6` | `v0.36.6` | Current | `.github/workflows/validate-k8s.yaml`, `hack/kind-smoke.sh` |
| kubeconform | `v0.7.0` | `v0.7.0` | Current | `.github/workflows/validate-k8s.yaml` |
| kind | `v0.31.0` | `v0.31.0` | Current | `.github/workflows/validate-k8s.yaml`, `hack/kind-smoke.sh` |
| actions/checkout | `v6.0.2` | `v6.0.2` | Current | `.github/workflows/validate-k8s.yaml` |
| PyYAML | unpinned | `6.0.3` | Pinned latest | `.github/workflows/validate-k8s.yaml` |
| bcrypt | unpinned | `5.0.0` | Pinned latest | `.github/workflows/validate-k8s.yaml` |
| Alpine utility image | `alpine:3.22` | `alpine:3.23.4` | Updated | `cluster/argocd/gitops-git-daemon-deployment.yaml` |
| nginx-unprivileged image | `nginxinc/nginx-unprivileged:1.27.5-alpine` | `nginxinc/nginx-unprivileged:1.29.8-alpine3.23` | Updated | `cluster/argocd/gitops-repo-deployment.yaml` |
| MinIO image | `RELEASE.2025-09-07T16-13-09Z` | `RELEASE.2025-09-07T16-13-09Z` | Current multi-arch | `apps/minio/base/deployment.yaml` |

First-party images are intentionally not changed here:

- `ghcr.io/lowjungxuandev/grim/backend:latest`
