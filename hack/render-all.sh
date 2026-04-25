#!/usr/bin/env bash
set -euo pipefail

root="${1:-.}"
cd "$root"

if command -v kustomize >/dev/null 2>&1; then
  renderer=(kustomize build)
elif command -v kubectl >/dev/null 2>&1; then
  renderer=(kubectl kustomize)
else
  echo "FAIL no renderer found: install kustomize or kubectl" >&2
  exit 1
fi

mkdir -p rendered

mapfile -t kustomizations < <(find . -path ./.git -prune -o -name kustomization.yaml -print | sort)

for kustomization in "${kustomizations[@]}"; do
  dir="${kustomization%/kustomization.yaml}"
  dir="${dir#./}"
  output="rendered/${dir}.yaml"
  mkdir -p "$(dirname "$output")"
  if "${renderer[@]}" "$dir" > "$output"; then
    echo "PASS render $dir"
  else
    echo "FAIL render $dir" >&2
    exit 1
  fi
done
