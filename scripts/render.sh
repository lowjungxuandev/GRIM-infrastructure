#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <kustomize-path>" >&2
  exit 1
fi

kustomize build "$1"
