#!/usr/bin/env bash
set -euo pipefail

namespace=""
name=""
controller_name="sealed-secrets-controller"
controller_namespace="kube-system"
output=""
from_literals=()

usage() {
  cat <<'EOF'
Usage:
  scripts/generate-sealed-secret.sh \
    --namespace <ns> \
    --name <secret-name> \
    --from-literal KEY=VALUE [--from-literal KEY=VALUE ...] \
    --controller-name <controller-name> \
    --controller-namespace <controller-namespace> \
    --output <path>
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)
      namespace="${2:-}"
      shift 2
      ;;
    --name)
      name="${2:-}"
      shift 2
      ;;
    --from-literal)
      from_literals+=("${2:-}")
      shift 2
      ;;
    --controller-name)
      controller_name="${2:-}"
      shift 2
      ;;
    --controller-namespace)
      controller_namespace="${2:-}"
      shift 2
      ;;
    --output)
      output="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$namespace" || -z "$name" || -z "$output" || "${#from_literals[@]}" -eq 0 ]]; then
  usage >&2
  exit 1
fi

for literal in "${from_literals[@]}"; do
  if [[ "$literal" != *=* || "$literal" == "="* ]]; then
    echo "invalid --from-literal value: $literal" >&2
    exit 1
  fi
done

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found" >&2; exit 1; }
command -v kubeseal >/dev/null 2>&1 || { echo "kubeseal not found" >&2; exit 1; }

secret_args=()
for literal in "${from_literals[@]}"; do
  secret_args+=(--from-literal "$literal")
done

mkdir -p "$(dirname "$output")"

kubectl create secret generic "$name" \
  --namespace "$namespace" \
  "${secret_args[@]}" \
  --dry-run=client \
  -o yaml \
  | kubeseal \
      --format yaml \
      --controller-name "$controller_name" \
      --controller-namespace "$controller_namespace" \
  > "$output"

echo "wrote sealed secret to $output"
