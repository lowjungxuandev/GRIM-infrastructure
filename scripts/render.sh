#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <kustomize-path>" >&2
  exit 1
fi

if command -v kustomize >/dev/null 2>&1; then
  kustomize build "$1"
else
  kubectl kustomize "$1"
fi
