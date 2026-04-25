#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_PATH="${1:-${SCRIPT_DIR}/.env}"
SEALED_SECRET_PATH="${SEALED_SECRET_PATH:-${ROOT_DIR}/apps/grim-backend/base/sealedsecret.yaml}"
NAMESPACE="${NAMESPACE:-grim}"
SECRET_NAME="${SECRET_NAME:-grim-backend-env}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-grim-backend}"
SEALED_SECRETS_CONTROLLER_NAME="${SEALED_SECRETS_CONTROLLER_NAME:-sealed-secrets-controller}"
SEALED_SECRETS_CONTROLLER_NAMESPACE="${SEALED_SECRETS_CONTROLLER_NAMESPACE:-kube-system}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-180s}"
GITHUB_REMOTE="${GITHUB_REMOTE:-origin}"
GITOPS_REMOTE="${GITOPS_REMOTE:-gitops-local}"
GITOPS_REPO_PATH="${GITOPS_REPO_PATH:-/root/gitops.git}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"
COMMIT_MESSAGE="${COMMIT_MESSAGE:-Update grim backend sealed secret from env}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_APPLICATION="${ARGOCD_APPLICATION:-grim-backend}"
SECRET_SYNC_TIMEOUT_SECONDS="${SECRET_SYNC_TIMEOUT_SECONDS:-120}"
ARGOCD_SYNC_TIMEOUT_SECONDS="${ARGOCD_SYNC_TIMEOUT_SECONDS:-180}"

SEALED_SECRET_REL_PATH="${SEALED_SECRET_PATH#${ROOT_DIR}/}"

ensure_gitops_remote() {
  if ! git -C "${ROOT_DIR}" remote get-url "${GITOPS_REMOTE}" >/dev/null 2>&1; then
    git -C "${ROOT_DIR}" remote add "${GITOPS_REMOTE}" "${GITOPS_REPO_PATH}"
  fi
}

commit_and_push_github() {
  git -C "${ROOT_DIR}" add "${SEALED_SECRET_REL_PATH}"

  if ! git -C "${ROOT_DIR}" diff --cached --quiet; then
    git -C "${ROOT_DIR}" commit -m "${COMMIT_MESSAGE}"
    git -C "${ROOT_DIR}" push "${GITHUB_REMOTE}" "${TARGET_BRANCH}"
  else
    echo "no GitHub commit needed for ${SEALED_SECRET_REL_PATH}"
  fi
}

push_gitops_source() {
  ensure_gitops_remote

  git -C "${ROOT_DIR}" fetch "${GITOPS_REMOTE}" "${TARGET_BRANCH}" >&2

  local sync_dir
  sync_dir="$(mktemp -d)"

  git -C "${ROOT_DIR}" worktree add --detach "${sync_dir}" "${GITOPS_REMOTE}/${TARGET_BRANCH}" >/dev/null
  mkdir -p "${sync_dir}/$(dirname "${SEALED_SECRET_REL_PATH}")"
  cp "${SEALED_SECRET_PATH}" "${sync_dir}/${SEALED_SECRET_REL_PATH}"
  git -C "${sync_dir}" add "${SEALED_SECRET_REL_PATH}"
  if ! git -C "${sync_dir}" diff --cached --quiet; then
    git -C "${sync_dir}" commit -m "${COMMIT_MESSAGE}" >&2
    git -C "${sync_dir}" push "${GITOPS_REMOTE}" HEAD:"${TARGET_BRANCH}" >&2
  else
    echo "no GitOps commit needed for ${SEALED_SECRET_REL_PATH}" >&2
  fi
  git -C "${ROOT_DIR}" worktree remove --force "${sync_dir}" >/dev/null
  rm -rf "${sync_dir}"

  git --git-dir="${GITOPS_REPO_PATH}" rev-parse "${TARGET_BRANCH}"
}

refresh_argocd() {
  local expected_revision="$1"
  local deadline
  deadline=$((SECONDS + ARGOCD_SYNC_TIMEOUT_SECONDS))

  kubectl annotate application -n "${ARGOCD_NAMESPACE}" "${ARGOCD_APPLICATION}" \
    argocd.argoproj.io/refresh=hard --overwrite >/dev/null

  while (( SECONDS < deadline )); do
    local revision
    local sync_status
    revision="$(kubectl get application -n "${ARGOCD_NAMESPACE}" "${ARGOCD_APPLICATION}" -o jsonpath='{.status.sync.revision}' 2>/dev/null || true)"
    sync_status="$(kubectl get application -n "${ARGOCD_NAMESPACE}" "${ARGOCD_APPLICATION}" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"

    if [[ "${revision}" == "${expected_revision}" && "${sync_status}" == "Synced" ]]; then
      return 0
    fi

    sleep 5
  done

  echo "ArgoCD did not sync ${ARGOCD_APPLICATION} to ${expected_revision}" >&2
  return 1
}

env_key_list() {
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    [[ -z "${line}" || "${line}" == \#* ]] && continue
    [[ "${line}" == export\ * ]] && line="${line#export }"
    [[ "${line}" == *=* ]] || continue

    local key
    key="${line%%=*}"
    key="${key%"${key##*[![:space:]]}"}"
    printf '%s\n' "${key}"
  done < "${ENV_PATH}" | sort -u
}

live_secret_key_list() {
  kubectl get secret -n "${NAMESPACE}" "${SECRET_NAME}" \
    -o go-template='{{range $key, $_ := .data}}{{printf "%s\n" $key}}{{end}}' 2>/dev/null | sort -u
}

expected_secret_data_list() {
  kubectl create secret generic "${SECRET_NAME}" \
    --namespace "${NAMESPACE}" \
    --from-env-file="${ENV_PATH}" \
    --dry-run=client \
    -o go-template='{{range $key, $value := .data}}{{printf "%s=%s\n" $key $value}}{{end}}' | sort -u
}

live_secret_data_list() {
  kubectl get secret -n "${NAMESPACE}" "${SECRET_NAME}" \
    -o go-template='{{range $key, $value := .data}}{{printf "%s=%s\n" $key $value}}{{end}}' 2>/dev/null | sort -u
}

print_secret_diff() {
  local expected_data_path="$1"
  local live_data_path="$2"

  echo "post-push safety check failed: live ${NAMESPACE}/${SECRET_NAME} does not match ${ENV_PATH}" >&2
  echo "missing variables in live secret:" >&2
  comm -23 <(cut -d= -f1 "${expected_data_path}") <(cut -d= -f1 "${live_data_path}") >&2 || true
  echo "extra variables in live secret:" >&2
  comm -13 <(cut -d= -f1 "${expected_data_path}") <(cut -d= -f1 "${live_data_path}") >&2 || true
  echo "variables with changed values:" >&2
  comm -3 "${expected_data_path}" "${live_data_path}" | cut -d= -f1 | sort -u >&2 || true
}

wait_for_secret_to_match_env() {
  local expected_data_path
  local live_data_path
  local deadline

  expected_data_path="$(mktemp)"
  live_data_path="$(mktemp)"
  expected_secret_data_list > "${expected_data_path}"

  deadline=$((SECONDS + SECRET_SYNC_TIMEOUT_SECONDS))
  while (( SECONDS < deadline )); do
    if live_secret_data_list > "${live_data_path}"; then
      if cmp -s "${expected_data_path}" "${live_data_path}"; then
        rm -f "${expected_data_path}" "${live_data_path}"
        return 0
      fi
    fi
    sleep 5
  done

  print_secret_diff "${expected_data_path}" "${live_data_path}"
  rm -f "${expected_data_path}" "${live_data_path}"
  return 1
}

if [[ ! -f "${ENV_PATH}" ]]; then
  echo "missing env file: ${ENV_PATH}" >&2
  exit 1
fi

if [[ ! -f "${SEALED_SECRET_PATH}" ]]; then
  echo "missing sealed secret manifest: ${SEALED_SECRET_PATH}" >&2
  exit 1
fi

kubectl create secret generic "${SECRET_NAME}" \
  --namespace "${NAMESPACE}" \
  --from-env-file="${ENV_PATH}" \
  --dry-run=client \
  -o yaml \
  | kubeseal \
    --format yaml \
    --controller-name "${SEALED_SECRETS_CONTROLLER_NAME}" \
    --controller-namespace "${SEALED_SECRETS_CONTROLLER_NAMESPACE}" \
  > "${SEALED_SECRET_PATH}"

commit_and_push_github
gitops_revision="$(push_gitops_source)"
refresh_argocd "${gitops_revision}"

kubectl apply -f "${SEALED_SECRET_PATH}"
wait_for_secret_to_match_env
echo "post-push safety check passed: live ${NAMESPACE}/${SECRET_NAME} matches ${ENV_PATH}"

current_secret_resource_version="$(kubectl get secret -n "${NAMESPACE}" "${SECRET_NAME}" -o jsonpath='{.metadata.resourceVersion}' 2>/dev/null || true)"
if [[ -z "${current_secret_resource_version}" ]]; then
  echo "sealed secret applied, but ${NAMESPACE}/${SECRET_NAME} does not exist" >&2
  exit 1
fi

kubectl rollout restart deployment/"${DEPLOYMENT_NAME}" -n "${NAMESPACE}"
kubectl rollout status deployment/"${DEPLOYMENT_NAME}" -n "${NAMESPACE}" --timeout="${ROLLOUT_TIMEOUT}"

echo "updated ${SEALED_SECRET_PATH} from ${ENV_PATH}"
echo "pushed GitHub ${GITHUB_REMOTE}/${TARGET_BRANCH} and GitOps ${GITOPS_REMOTE}/${TARGET_BRANCH}"
echo "applied sealed secret and matched live ${NAMESPACE}/${SECRET_NAME} data at resourceVersion ${current_secret_resource_version}"
echo "refreshed deployment ${NAMESPACE}/${DEPLOYMENT_NAME} after the secret was live"
