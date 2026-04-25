# kubeadm Bootstrap

This is a standard upstream Kubernetes setup based on `kubeadm`.

## Target

- Kubernetes: `v1.36.0`
- kubeadm config API: `kubeadm.k8s.io/v1beta4`
- Container runtime: `containerd`

`v1.36` is the current upstream stable Kubernetes minor version used by this repository.

## Control Plane Init

Run on the first control plane node:

```bash
sudo ./install-tools-ubuntu.sh
sudo ./control-plane-init.sh
```

That script:

- disables swap for the current session
- loads required kernel modules
- configures sysctls needed by Kubernetes networking
- initializes the cluster with `kubeadm init --config kubeadm-config.yaml`
- writes admin kubeconfig to `$HOME/.kube/config`

Before production bootstrap, make swap disablement persistent in the host OS configuration and verify it after reboot. Also replace the placeholder control plane DNS name `control-plane.example.com` in `kubeadm-config.yaml` with the target control plane endpoint and matching certificate SAN.

After bootstrap, run the repository validation workflow from the repo root:

```bash
python3 hack/validate-yaml.py --root . --write-report
bash hack/render-all.sh
```

## Worker Join

After control plane initialization, generate a join command:

```bash
kubeadm token create --print-join-command
```

Then run the generated command on each worker node after preparing containerd, kubelet, and kubeadm.

## Single-Node Note

If you intentionally run a single-node cluster and want normal workloads plus ingress to schedule on the control plane, remove the default taint:

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

Do this only when you accept running workload pods on the control plane.
