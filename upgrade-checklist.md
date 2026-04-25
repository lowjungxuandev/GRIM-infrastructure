# Kubernetes v1.35 Upgrade Checklist

Date: 2026-04-25

## Scope

- Upgraded the single-node kubeadm cluster from Kubernetes `v1.34.x` to `v1.35.4`.
- Added Grafana at `https://lowjungxuan.dpdns.org/grafana/`.
- Provisioned the `GRIM Kubernetes Overview` Grafana dashboard from GitOps.
- Verified public ingress routes, Argo CD applications, TLS certificates, and Prometheus targets.

## Pre-Upgrade Checks

- Confirmed node was Ready before upgrade.
- Confirmed no pods were stuck outside `Running` or `Succeeded`.
- Confirmed host uses cgroup v2.
- Confirmed container runtime is containerd `2.2.1`.
- Confirmed `kubeadm`, `kubelet`, and `kubectl` were held apt packages before changing versions.
- Confirmed the Kubernetes `v1.35` apt repository exposes `1.35.4-1.1`.

## Upgrade Steps Completed

- Changed `/etc/apt/sources.list.d/kubernetes.list` from the `v1.34` package channel to `v1.35`.
- Upgraded `kubeadm` to `v1.35.4`.
- Ran `kubeadm upgrade plan`.
- Applied the control-plane upgrade with `kubeadm upgrade apply v1.35.4 -y`.
- Upgraded `kubelet` and `kubectl` to `v1.35.4`.
- Restarted kubelet.
- Re-held `kubeadm`, `kubelet`, and `kubectl`.
- Aligned repo bootstrap files to Kubernetes `v1.35.4` and apt channel `v1.35`.

## Grafana Work Completed

- Added a Grafana kustomize app under `apps/grafana`.
- Added the Argo CD Application at `cluster/argocd/grafana-application.yaml`.
- Added a sealed admin credential secret.
- Added a Prometheus datasource provisioned as UID `prometheus`.
- Added dashboard provisioning.
- Added dashboard template `GRIM Kubernetes Overview`.
- The dashboard includes:
  - API server health
  - node scrape health
  - Grafana scrape health
  - running pod count
  - cluster CPU and memory
  - top namespaces by CPU and memory
  - top pods by CPU and memory
  - API server request rate
  - pod network throughput
  - Grafana API response rate
  - Prometheus scrape health

## TLS Note

- The first Grafana certificate request hit Let's Encrypt's exact-set rate limit for `lowjungxuan.dpdns.org`.
- To keep Grafana working immediately, `grafana-tls` reuses an existing valid cert-manager-issued certificate for the same hostname.
- The Grafana Certificate resource is Ready after adding the reused TLS secret.
- Avoid issuing more separate certificates for the same `lowjungxuan.dpdns.org` hostname until the rate-limit window has passed.

## Verification Results

- `kubectl`, `kubeadm`, `kubelet`, and API server report `v1.35.4`.
- Node `ubuntu-4gb-hel1-2` is Ready on `v1.35.4`.
- No pods are stuck outside `Running` or `Succeeded`.
- Argo CD Applications are Synced and Healthy:
  - `grafana`
  - `grim-backend`
  - `headlamp`
  - `minio`
  - `prometheus`
- All cert-manager Certificate resources are Ready:
  - `argocd/argocd-server-tls`
  - `grafana/grafana-tls`
  - `grim/grim-backend-tls`
  - `headlamp/headlamp-tls`
  - `minio/minio-api-tls`
  - `minio/minio-console-tls`
  - `prometheus/prometheus-tls`
- Prometheus targets checked through the API:
  - total targets: `10`
  - down targets: `0`
- Grafana API health returned database `ok`.
- Grafana dashboard API confirms:
  - title: `GRIM Kubernetes Overview`
  - UID: `grim-kubernetes-overview`
  - panels: `14`

## Public Route Checks

- `https://lowjungxuan.dpdns.org/argocd/` returned `200`.
- `https://lowjungxuan.dpdns.org/backend/docs` returned `200`.
- `https://lowjungxuan.dpdns.org/minIO/` returned `200`.
- `https://lowjungxuan.dpdns.org/headlamp/` returned `401`, expected because basic auth is enabled.
- `https://lowjungxuan.dpdns.org/prometheus/` returned `401`, expected because basic auth is enabled.
- `https://lowjungxuan.dpdns.org/grafana/api/health` returned `200`.
- `https://lowjxn8n.dpdns.org/minio/health/live` returned `200`.

## Follow-Up

- Add `node-exporter` later if host CPU, memory, filesystem, disk I/O, and network panels are needed.
- Add `kube-state-metrics` later if Deployment, StatefulSet, DaemonSet, PVC, and pod phase dashboards are needed.
- Consider using one shared wildcard or shared hostname certificate design later to avoid duplicate Let's Encrypt exact-set limits.
