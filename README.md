# Kubernetes Setup With Kustomize

This directory sets up a standard upstream Kubernetes cluster workflow with:

- `kubeadm` for the control plane
- Calico for CNI
- ingress-nginx for ingress
- metrics-server for resource metrics and HPA support
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
- `cluster/argocd`: Argo CD, Image Updater, dashboard ingress, and GRIM application
- `cluster/sealed-secrets`: Sealed Secrets controller install via `kustomize`
- `apps/grim-backend`: GRIM backend base and production overlay
- `scripts`: render/apply helpers
- `docs`: operator setup and runbook documentation

## Order

1. Install container runtime plus `kubeadm`, `kubelet`, and `kubectl` on the nodes.
2. Initialize the control plane with `cluster/kubeadm/kubeadm-config.yaml`.
3. Join worker nodes.
4. Install Calico.
5. Install ingress-nginx.
6. Install metrics-server.
7. Install Argo CD.
8. Install Sealed Secrets.
9. Apply the GRIM backend overlay directly or let Argo CD manage it.

## Commands

```bash
cd /root/k8s

./scripts/render.sh cluster/network/calico
./scripts/apply.sh cluster/network/calico

./scripts/render.sh cluster/ingress-nginx
./scripts/apply.sh cluster/ingress-nginx

./scripts/render.sh cluster/metrics-server
./scripts/apply.sh cluster/metrics-server

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

## VM-Specific Values

- The kubeadm config currently uses control plane endpoint `89.167.40.225:6443`. Update `cluster/kubeadm/kubeadm-config.yaml` before bootstrapping a different VM.
- The ingress host currently uses `lowjungxuan.dpdns.org` for both Argo CD and the GRIM backend. Update `cluster/argocd/argocd-server-ingress.yaml` and `apps/grim-backend/overlays/production/ingress-patch.yaml` if you want separate hostnames.

## Notes

- The kubeadm config uses pod CIDR `192.168.0.0/16`, which matches the Calico manifest referenced here.
- The ingress controller uses the official bare-metal deployment patched to `hostNetwork: true`, so ports `80` and `443` bind directly on the ingress node.
- Argo CD dashboard ingress is configured in `cluster/argocd/argocd-server-ingress.yaml`.
- The GRIM `Application` uses an internal Git HTTP service in the cluster. The backing bare repository is stored on this VM.
- The GRIM backend requires real Cloudinary, Firebase, and LLM credentials. Those are now managed with Sealed Secrets. The deployment defaults to `replicas: 0` until you seal real values and then scale it up.
