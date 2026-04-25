# Kubernetes Setup With Kustomize

This directory sets up a standard upstream Kubernetes cluster workflow with:

- `kubeadm` for the control plane
- Calico for CNI
- ingress-nginx for ingress
- metrics-server for resource metrics and HPA support
- cert-manager for ingress TLS certificates
- Argo CD for GitOps sync and dashboard
- Argo CD Image Updater for automatic image refresh
- Sealed Secrets for encrypted secret management
- the GRIM backend deployed through `kustomize`

No `k3s`, `minikube`, or other Kubernetes distributions are used here.

## Start Here

For a clean VM setup, follow [docs/get-started.md](docs/get-started.md). It covers host preparation, VM-specific values, kubeadm initialization, Kustomize apply order, Argo CD access, and basic verification.

## Layout

- `cluster/kubeadm`: bootstrap files and helper scripts for a normal Kubernetes control plane
- `cluster/network/calico`: CNI install via `kustomize`
- `cluster/ingress-nginx`: ingress controller install via `kustomize`
- `cluster/cert-manager`: cert-manager install via pinned upstream manifest
- `cluster/cert-manager-issuers`: Let's Encrypt ClusterIssuer resources
- `cluster/argocd`: Argo CD, Image Updater, dashboard ingress, and GRIM applications
- `cluster/sealed-secrets`: Sealed Secrets controller install via `kustomize`
- `apps/grim-backend`: GRIM backend base and production overlay
- `apps/minio`: MinIO base and production overlay
- `apps/headlamp`: Headlamp Kubernetes dashboard base and production overlay
- `apps/prometheus`: Prometheus monitoring server base and production overlay
- `hack`: validation and smoke-test helpers
- `audit`: generated manifest inventory, security findings, deferred items, and test results
- `scripts`: render/apply helpers
- `docs`: operator setup and runbook documentation

## Order

1. Install container runtime plus `kubeadm`, `kubelet`, and `kubectl` on the nodes.
2. Initialize the control plane with `cluster/kubeadm/kubeadm-config.yaml`.
3. Join worker nodes.
4. Install Calico.
5. Install ingress-nginx.
6. Install metrics-server.
7. Install cert-manager.
8. Install Argo CD.
9. Install Sealed Secrets.
10. Apply the GRIM backend overlay directly or let Argo CD manage it.

## Commands

```bash
cd /root/k8s

./scripts/render.sh cluster/network/calico
./scripts/apply.sh cluster/network/calico

./scripts/render.sh cluster/ingress-nginx
./scripts/apply.sh cluster/ingress-nginx

./scripts/render.sh cluster/metrics-server
./scripts/apply.sh cluster/metrics-server

./scripts/render.sh cluster/cert-manager
./scripts/apply.sh cluster/cert-manager
kubectl -n cert-manager wait --for=condition=Available deployment/cert-manager-webhook --timeout=180s

./scripts/render.sh cluster/cert-manager-issuers
./scripts/apply.sh cluster/cert-manager-issuers

./scripts/render.sh cluster/argocd
./scripts/apply.sh cluster/argocd

./scripts/render.sh cluster/sealed-secrets
./scripts/apply.sh cluster/sealed-secrets

./scripts/render.sh apps/grim-backend/overlays/production
./scripts/apply.sh apps/grim-backend/overlays/production
```

## Node Prep

For Ubuntu or Debian nodes, start with:

```bash
cd /root/k8s/cluster/kubeadm
sudo ./install-tools-ubuntu.sh
```

## Environment-Specific Values

- The kubeadm config uses placeholder control plane endpoint `control-plane.example.com:6443`. Replace it with the DNS name or address for the target control plane before bootstrapping.
- Argo CD ingress uses `argocd.example.com`, and the backend API uses `api.example.com`. Replace those placeholders with real TLS hostnames for the target environment.

## Notes

- The kubeadm config uses pod CIDR `192.168.0.0/16`, which matches the Calico manifest referenced here.
- The ingress controller uses the official bare-metal deployment patched to `hostNetwork: true`, so ports `80` and `443` bind directly on the ingress node.
- The MinIO console is served at `https://lowjungxuan.dpdns.org/minIO/`; the S3 API is served separately at `https://lowjxn8n.dpdns.org/`.
- Headlamp is served at `https://lowjungxuan.dpdns.org/headlamp/`.
- Prometheus is served at `https://lowjungxuan.dpdns.org/prometheus/`.
- Public ingress TLS certificates are issued by cert-manager through the `letsencrypt-prod` ClusterIssuer.
- Keep the MinIO S3 API DNS record DNS-only when using Cloudflare. S3 clients and presigned URLs are sensitive to proxy upload limits and signature-changing behavior.
- Argo CD dashboard ingress is configured in `cluster/argocd/argocd-server-ingress.yaml` and expects HTTPS termination at ingress.
- The GRIM `Application` uses an internal Git HTTP service in the cluster. The backing bare repository is stored on this VM.
- The GRIM backend requires real Cloudinary, Firebase, and LLM credentials. Those are now managed with Sealed Secrets. The deployment defaults to `replicas: 0` until you seal real values and then scale it up.
- MinIO credentials must be generated as a SealedSecret or equivalent encrypted secret before production use. Do not commit plaintext MinIO credentials.

## Validation

Run the local checks before committing manifest changes:

```bash
python3 hack/validate-yaml.py --root . --write-report
bash hack/render-all.sh
bash hack/kind-smoke.sh
```

`hack/render-all.sh` writes rendered manifests under `rendered/`. The CI workflow in `.github/workflows/validate-k8s.yaml` runs the same static, render, schema, and kind smoke checks.
