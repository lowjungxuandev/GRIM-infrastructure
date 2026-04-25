#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CLUSTER_NAME="${KIND_CLUSTER_NAME:-grim-audit}"
ARTIFACT_DIR="audit/test-artifacts"
RESULTS="audit/test-results.md"
PATH="$ROOT/.bin:$PATH"

mkdir -p "$ARTIFACT_DIR" .bin audit rendered

append_result() {
  printf '%s\n' "$1" | tee -a "$RESULTS"
}

capture_failure_artifacts() {
  kubectl get pods -A -o wide > "$ARTIFACT_DIR/pods-wide.txt" 2>&1 || true
  kubectl get events -A --sort-by=.lastTimestamp > "$ARTIFACT_DIR/events.txt" 2>&1 || true
  kubectl describe deployments,pods,secrets,ingress -A > "$ARTIFACT_DIR/describe.txt" 2>&1 || true
}

fail() {
  append_result "FAIL kind smoke: $*"
  capture_failure_artifacts
  exit 1
}

has_runtime() {
  command -v docker >/dev/null 2>&1 || command -v podman >/dev/null 2>&1 || command -v nerdctl >/dev/null 2>&1
}

install_kind() {
  if command -v kind >/dev/null 2>&1; then
    return
  fi
  local arch
  arch="$(go_arch)"
  curl -fsSL -o .bin/kind "https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-${arch}"
  chmod +x .bin/kind
}

go_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo amd64 ;;
    aarch64|arm64) echo arm64 ;;
    *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
  esac
}

install_kubectl() {
  if command -v kubectl >/dev/null 2>&1; then
    return
  fi
  local version
  version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  curl -fsSL -o .bin/kubectl "https://dl.k8s.io/release/${version}/bin/linux/$(go_arch)/kubectl"
  chmod +x .bin/kubectl
}

install_kubeseal() {
  if command -v kubeseal >/dev/null 2>&1; then
    return
  fi
  local version="v0.36.6"
  curl -fsSL -o /tmp/kubeseal.tar.gz "https://github.com/bitnami-labs/sealed-secrets/releases/download/${version}/kubeseal-${version#v}-linux-$(go_arch).tar.gz"
  tar -xzf /tmp/kubeseal.tar.gz -C /tmp kubeseal
  mv /tmp/kubeseal .bin/kubeseal
  chmod +x .bin/kubeseal
}

if ! has_runtime; then
  append_result "SKIP kind smoke: no supported container runtime"
  exit 0
fi

install_kind
install_kubectl
install_kubeseal

if ! kind get clusters | grep -qx "$CLUSTER_NAME"; then
  kind create cluster --name "$CLUSTER_NAME" || fail "cluster creation failed"
fi

cleanup() {
  if [[ "${KEEP_KIND_CLUSTER:-0}" != "1" ]]; then
    kind delete cluster --name "$CLUSTER_NAME" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

kubectl cluster-info >/dev/null || fail "kubectl cannot reach kind cluster"

kubectl apply -k cluster/sealed-secrets || fail "sealed-secrets apply failed"
kubectl -n kube-system rollout status deployment/sealed-secrets-controller --timeout=180s || fail "sealed-secrets controller not Available"

kubectl create namespace minio --dry-run=client -o yaml | kubectl apply -f - || fail "minio namespace creation failed"

tmp_secret="$(mktemp)"
SMOKE_MINIO_USER="${SUPPLIED_USERNAME:-kind-minio-user}"
SMOKE_MINIO_PASSWORD="${SUPPLIED_PASSWORD:-kind-minio-password}"

scripts/generate-sealed-secret.sh \
  --namespace minio \
  --name minio-root-credentials \
  --from-literal "MINIO_ROOT_USER=${SMOKE_MINIO_USER}" \
  --from-literal "MINIO_ROOT_PASSWORD=${SMOKE_MINIO_PASSWORD}" \
  --controller-name sealed-secrets-controller \
  --controller-namespace kube-system \
  --output "$tmp_secret" >/dev/null || fail "disposable MinIO SealedSecret generation failed"

kubectl apply -f "$tmp_secret" || fail "disposable MinIO SealedSecret apply failed"
kubectl -n minio wait --for=jsonpath='{.metadata.name}'=minio-root-credentials secret/minio-root-credentials --timeout=120s || fail "disposable MinIO SealedSecret did not unseal"
append_result "PASS disposable MinIO SealedSecret unsealed in kind"

kubectl apply --server-side --dry-run=server -k apps/grim-backend/overlays/production >/dev/null || fail "server dry-run grim-backend failed"
kubectl apply --server-side --dry-run=server -k apps/minio/overlays/production >/dev/null || fail "server dry-run minio failed"
append_result "PASS server-side dry-run for grim-backend and minio overlays"

tmp_runtime="$(mktemp -d)"
kubectl kustomize apps/grim-backend/overlays/production > "$tmp_runtime/grim-backend.yaml"
python3 - "$tmp_runtime/grim-backend.yaml" <<'PY'
import sys
import yaml

path = sys.argv[1]
docs = list(yaml.safe_load_all(open(path, encoding="utf-8")))
for doc in docs:
    if isinstance(doc, dict) and doc.get("kind") == "Deployment" and doc.get("metadata", {}).get("name") == "grim-backend":
        doc.setdefault("spec", {})["replicas"] = 0
with open(path, "w", encoding="utf-8") as f:
    yaml.safe_dump_all(docs, f, sort_keys=False)
PY
append_result "INFO grim-backend runtime apply uses replicas=0 because external services are not available in kind"

kubectl apply -k apps/minio/overlays/production || fail "minio apply failed"
kubectl apply -f "$tmp_runtime/grim-backend.yaml" || fail "grim-backend replicas=0 apply failed"

kubectl -n minio rollout status deployment/minio --timeout=180s || fail "minio deployment rollout failed"
append_result "PASS minio deployment Available in kind"

kubectl get namespace grim minio >/dev/null || fail "expected namespaces missing"
kubectl -n minio get secret minio-root-credentials >/dev/null || fail "expected MinIO secret missing"

kubectl apply -k apps/minio/overlays/production >/dev/null || fail "minio second apply failed"
kubectl apply -f "$tmp_runtime/grim-backend.yaml" >/dev/null || fail "grim-backend second apply failed"
append_result "PASS idempotent second apply for smoke targets"

if kubectl diff -k apps/minio/overlays/production >/dev/null 2>&1; then
  append_result "PASS kubectl diff minio has no diff"
else
  status=$?
  if [[ "$status" -eq 1 ]]; then
    fail "kubectl diff minio still reports changes after second apply"
  else
    fail "kubectl diff minio failed"
  fi
fi

append_result "PASS kind smoke completed"
