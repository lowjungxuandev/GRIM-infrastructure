#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

swapoff -a
modprobe overlay
modprobe br_netfilter

cat >/etc/sysctl.d/99-kubernetes-cri.conf <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system
kubeadm init --config "${SCRIPT_DIR}/kubeadm-config.yaml" --upload-certs

mkdir -p "${HOME}/.kube"
cp /etc/kubernetes/admin.conf "${HOME}/.kube/config"
chown "$(id -u):$(id -g)" "${HOME}/.kube/config"

kubectl get nodes -o wide
