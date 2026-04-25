# Get Started On A New VM

This guide bootstraps this repository on a fresh Ubuntu/Debian VM using upstream Kubernetes with `kubeadm`, `containerd`, Calico, ingress-nginx, metrics-server, Sealed Secrets, Argo CD, and the GRIM backend manifests.

## 1. Prepare The VM

Use a VM with at least 2 vCPU, 4 GB RAM, a public or private static IP, and inbound access for SSH plus Kubernetes/ingress ports as needed.

Open these ports on the VM firewall or cloud security group:

- `22/tcp` for SSH
- `6443/tcp` for the Kubernetes API
- `80/tcp` and `443/tcp` for ingress-nginx
- Worker-node ports if you add more nodes and your provider blocks private traffic

Clone the repository on the VM:

```bash
cd /root
git clone <repo-url> k8s
cd /root/k8s
```

Install `git` first if the VM image does not include it:

```bash
sudo apt-get update
sudo apt-get install -y git
```

## 2. Update VM-Specific Values

Before running `kubeadm init`, edit `cluster/kubeadm/kubeadm-config.yaml`:

- Set `controlPlaneEndpoint` to the new VM IP or DNS name with port `6443`.
- Set `apiServer.certSANs` to include the same IP or DNS name.
- Keep `podSubnet: 192.168.0.0/16` unless you also change the Calico configuration.

Update ingress hostnames if this VM will use a different domain:

- `cluster/argocd/argocd-server-ingress.yaml`
- `apps/grim-backend/overlays/production/ingress-patch.yaml`
- `apps/grim-backend/base/ingress.yaml` if you want the base to match production

The current manifests use `lowjungxuan.dpdns.org`. Point that DNS record, or your replacement hostname, to the new VM IP.

## 3. Install Kubernetes Tools

Run on the control-plane VM:

```bash
cd /root/k8s/cluster/kubeadm
sudo ./install-tools-ubuntu.sh
```

The script installs `containerd`, `kubelet`, `kubeadm`, and `kubectl`, configures containerd to use the systemd cgroup driver, and enables the services.

## 4. Initialize The Control Plane

Run:

```bash
cd /root/k8s/cluster/kubeadm
sudo ./control-plane-init.sh
```

Then make sure your shell can use the generated kubeconfig:

```bash
export KUBECONFIG=/root/.kube/config
kubectl get nodes -o wide
```

For a single-node VM where workloads should run on the control plane, remove the default taint:

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

If you have worker nodes, prepare each worker with `install-tools-ubuntu.sh`, then generate and run the join command:

```bash
kubeadm token create --print-join-command
```

## 5. Install Cluster Add-Ons

Apply the Kustomize overlays in this order:

```bash
cd /root/k8s

kubectl apply -k cluster/network/calico
kubectl wait --for=condition=Ready nodes --all --timeout=180s

kubectl apply -k cluster/ingress-nginx
kubectl apply -k cluster/metrics-server
kubectl apply -k cluster/sealed-secrets
kubectl apply -k cluster/argocd
```

Check that the main system pods are running:

```bash
kubectl get pods -A
kubectl -n ingress-nginx get pods
kubectl -n argocd get pods
kubectl -n kube-system top nodes
```

## 6. Access Argo CD

The Argo CD ingress is defined in `cluster/argocd/argocd-server-ingress.yaml`. After DNS points to the VM, open:

```text
http://lowjungxuan.dpdns.org/argocd
```

Local accounts are managed in these Kustomize patches:

- `cluster/argocd/argocd-cm-accounts-patch.yaml`
- `cluster/argocd/argocd-rbac-cm-patch.yaml`
- `cluster/argocd/argocd-secret-accounts-patch.yaml`

The `jungxuanlow` account is configured as an Argo CD admin. The manifest stores a bcrypt hash in `argocd-secret`; do not commit plaintext passwords.

To rotate that password later, patch the live secret with a new bcrypt hash and update `cluster/argocd/argocd-secret-accounts-patch.yaml` with the same hash and a fresh `passwordMtime`.

## 7. Deploy The GRIM Backend

Argo CD is configured with `cluster/argocd/grim-backend-application.yaml` to sync the backend from the in-cluster Git service:

```yaml
repoURL: git://gitops-git.argocd.svc.cluster.local/gitops.git
targetRevision: main
path: apps/grim-backend/overlays/production
```

If you want to apply the backend directly instead of waiting for Argo CD:

```bash
kubectl apply -k apps/grim-backend/overlays/production
```

The backend uses a SealedSecret named `grim-backend-env`. If the VM is a new cluster with a new Sealed Secrets controller key, existing sealed values may not decrypt. Re-seal the real environment values for the new cluster before scaling the app.

## 8. Verify The Setup

Run:

```bash
kubectl get nodes -o wide
kubectl get ingress -A
kubectl -n argocd get applications
kubectl -n grim get deploy,svc,ingress,pods
```

Basic HTTP checks from the VM:

```bash
curl -I http://lowjungxuan.dpdns.org/argocd
curl -I http://127.0.0.1
```

If ingress does not respond, check:

- DNS points to the VM IP.
- Ports `80` and `443` are open.
- `ingress-nginx-controller` is running with `hostNetwork: true`.
- No other process on the VM is already binding ports `80` or `443`.

## 9. Common Maintenance

Render an overlay without applying it:

```bash
kubectl kustomize cluster/argocd
```

Apply an overlay:

```bash
kubectl apply -k cluster/argocd
```

Restart Argo CD server after account or RBAC changes:

```bash
kubectl -n argocd rollout restart deployment argocd-server
kubectl -n argocd rollout status deployment argocd-server
```

Review GitOps state:

```bash
kubectl -n argocd get applications.argoproj.io
kubectl -n argocd describe application grim-backend
```
