# Manifest Inventory

PASS parsed_yaml=47/47
PASS required_field_checks
PASS top_level_key_checks

## .

| File | Type | Status | Role | Kinds | Validation | Warnings |
|---|---|---:|---|---|---|---|
| README.md | markdown | N/A | N/A |  | not yaml | see security report |

## .github

| File | Type | Status | Role | Kinds | Validation | Warnings |
|---|---|---:|---|---|---|---|
| .github/workflows/validate-k8s.yaml | yaml | OK | full resource | <none> | required=PASS; top-level=PASS | none |

## .gitignore

| File | Type | Status | Role | Kinds | Validation | Warnings |
|---|---|---:|---|---|---|---|
| .gitignore | text | N/A | N/A |  | not yaml | see security report |

## apps/grim-backend

| File | Type | Status | Role | Kinds | Validation | Warnings |
|---|---|---:|---|---|---|---|
| apps/grim-backend/base/deployment.yaml | yaml | OK | full resource | Deployment | required=PASS; top-level=PASS | 1 |
| apps/grim-backend/base/ingress.yaml | yaml | OK | full resource | Ingress | required=PASS; top-level=PASS | 1 |
| apps/grim-backend/base/kustomization.yaml | kustomization | OK | kustomization | Kustomization | required=PASS; top-level=PASS | none |
| apps/grim-backend/base/namespace.yaml | yaml | OK | full resource | Namespace | required=PASS; top-level=PASS | none |
| apps/grim-backend/base/networkpolicy-allow-from-ingress-nginx.yaml | yaml | OK | full resource | NetworkPolicy | required=PASS; top-level=PASS | none |
| apps/grim-backend/base/networkpolicy-default-deny-ingress.yaml | yaml | OK | full resource | NetworkPolicy | required=PASS; top-level=PASS | none |
| apps/grim-backend/base/sealedsecret.yaml | yaml | OK | full resource | SealedSecret | required=PASS; top-level=PASS | none |
| apps/grim-backend/base/secret-template.yaml | yaml | OK | template | Secret | required=PASS; top-level=PASS | 1 |
| apps/grim-backend/base/service.yaml | yaml | OK | full resource | Service | required=PASS; top-level=PASS | none |
| apps/grim-backend/overlays/production/deployment-patch.yaml | yaml | OK-patch | patch fragment | Deployment | required=PASS; top-level=PASS | none |
| apps/grim-backend/overlays/production/ingress-patch.yaml | yaml | OK-patch | patch fragment | Ingress | required=PASS; top-level=PASS | none |
| apps/grim-backend/overlays/production/kustomization.yaml | kustomization | OK | kustomization | Kustomization | required=PASS; top-level=PASS | none |

## apps/minio

| File | Type | Status | Role | Kinds | Validation | Warnings |
|---|---|---:|---|---|---|---|
| apps/minio/base/deployment.yaml | yaml | OK | full resource | Deployment | required=PASS; top-level=PASS | none |
| apps/minio/base/kustomization.yaml | kustomization | OK | kustomization | Kustomization | required=PASS; top-level=PASS | none |
| apps/minio/base/namespace.yaml | yaml | OK | full resource | Namespace | required=PASS; top-level=PASS | none |
| apps/minio/base/networkpolicy-allow-console-public.yaml | yaml | OK | full resource | NetworkPolicy | required=PASS; top-level=PASS | none |
| apps/minio/base/networkpolicy-allow-from-grim-backend.yaml | yaml | OK | full resource | NetworkPolicy | required=PASS; top-level=PASS | none |
| apps/minio/base/networkpolicy-default-deny-ingress.yaml | yaml | OK | full resource | NetworkPolicy | required=PASS; top-level=PASS | none |
| apps/minio/base/pv.yaml | yaml | OK | full resource | PersistentVolume | required=PASS; top-level=PASS | 1 |
| apps/minio/base/pvc.yaml | yaml | OK | full resource | PersistentVolumeClaim | required=PASS; top-level=PASS | none |
| apps/minio/base/secret-template.yaml | yaml | OK | template | Secret | required=PASS; top-level=PASS | 1 |
| apps/minio/base/service.yaml | yaml | OK | full resource | Service | required=PASS; top-level=PASS | none |
| apps/minio/overlays/production/ingress.yaml | yaml | OK | full resource | Ingress | required=PASS; top-level=PASS | none |
| apps/minio/overlays/production/kustomization.yaml | kustomization | OK | kustomization | Kustomization | required=PASS; top-level=PASS | none |

## audit

| File | Type | Status | Role | Kinds | Validation | Warnings |
|---|---|---:|---|---|---|---|
| audit/deferred-items.md | markdown | N/A | N/A |  | not yaml | see security report |
| audit/manifest-inventory.json | json | N/A | N/A |  | not yaml | see security report |
| audit/manifest-inventory.md | markdown | N/A | N/A |  | not yaml | see security report |
| audit/pinned-versions.md | markdown | N/A | N/A |  | not yaml | see security report |
| audit/security-findings.md | markdown | N/A | N/A |  | not yaml | see security report |
| audit/test-results.md | markdown | N/A | N/A |  | not yaml | see security report |

## cluster/argocd

| File | Type | Status | Role | Kinds | Validation | Warnings |
|---|---|---:|---|---|---|---|
| cluster/argocd/argocd-cm-accounts-patch.yaml | yaml | OK-patch | patch fragment | ConfigMap | required=PASS; top-level=PASS | none |
| cluster/argocd/argocd-cmd-params-patch.yaml | yaml | OK-patch | patch fragment | ConfigMap | required=PASS; top-level=PASS | none |
| cluster/argocd/argocd-rbac-cm-patch.yaml | yaml | OK-patch | patch fragment | ConfigMap | required=PASS; top-level=PASS | none |
| cluster/argocd/argocd-secret-accounts-patch.yaml | yaml | OK-patch | patch fragment | Secret | required=PASS; top-level=PASS | 1 |
| cluster/argocd/argocd-server-deployment-patch.yaml | yaml | OK-patch | patch fragment | Deployment | required=PASS; top-level=PASS | none |
| cluster/argocd/argocd-server-ingress.yaml | yaml | OK | full resource | Ingress | required=PASS; top-level=PASS | none |
| cluster/argocd/gitops-git-daemon-deployment.yaml | yaml | OK | full resource | Deployment | required=PASS; top-level=PASS | 1 |
| cluster/argocd/gitops-git-daemon-service.yaml | yaml | OK | full resource | Service | required=PASS; top-level=PASS | none |
| cluster/argocd/gitops-repo-configmap.yaml | yaml | OK | full resource | ConfigMap | required=PASS; top-level=PASS | none |
| cluster/argocd/gitops-repo-deployment.yaml | yaml | OK | full resource | Deployment | required=PASS; top-level=PASS | 1 |
| cluster/argocd/gitops-repo-service.yaml | yaml | OK | full resource | Service | required=PASS; top-level=PASS | none |
| cluster/argocd/grim-backend-application.yaml | yaml | OK | full resource | Application | required=PASS; top-level=PASS | 2 |
| cluster/argocd/grim-image-updater.yaml | yaml | OK | full resource | ImageUpdater | required=PASS; top-level=PASS | none |
| cluster/argocd/kustomization.yaml | kustomization | OK | kustomization | Kustomization | required=PASS; top-level=PASS | none |
| cluster/argocd/minio-application.yaml | yaml | OK | full resource | Application | required=PASS; top-level=PASS | 2 |

## cluster/ingress-nginx

| File | Type | Status | Role | Kinds | Validation | Warnings |
|---|---|---:|---|---|---|---|
| cluster/ingress-nginx/hostnetwork-patch.yaml | yaml | OK-patch | patch fragment | Deployment | required=PASS; top-level=PASS | none |
| cluster/ingress-nginx/kustomization.yaml | kustomization | OK | kustomization | Kustomization | required=PASS; top-level=PASS | none |

## cluster/kubeadm

| File | Type | Status | Role | Kinds | Validation | Warnings |
|---|---|---:|---|---|---|---|
| cluster/kubeadm/README.md | markdown | N/A | N/A |  | not yaml | see security report |
| cluster/kubeadm/control-plane-init.sh | shell | N/A | N/A |  | not yaml | see security report |
| cluster/kubeadm/install-tools-ubuntu.sh | shell | N/A | N/A |  | not yaml | see security report |
| cluster/kubeadm/kubeadm-config.yaml | yaml | OK | full resource | InitConfiguration, ClusterConfiguration, KubeletConfiguration | required=PASS; top-level=PASS | none |

## cluster/metrics-server

| File | Type | Status | Role | Kinds | Validation | Warnings |
|---|---|---:|---|---|---|---|
| cluster/metrics-server/kustomization.yaml | kustomization | OK | kustomization | Kustomization | required=PASS; top-level=PASS | none |

## cluster/network

| File | Type | Status | Role | Kinds | Validation | Warnings |
|---|---|---:|---|---|---|---|
| cluster/network/calico/kustomization.yaml | kustomization | OK | kustomization | Kustomization | required=PASS; top-level=PASS | none |

## cluster/sealed-secrets

| File | Type | Status | Role | Kinds | Validation | Warnings |
|---|---|---:|---|---|---|---|
| cluster/sealed-secrets/controller.yaml | yaml | OK | full resource | ServiceAccount, Deployment, RoleBinding, Role, Service, Role, ClusterRoleBinding, ClusterRole, CustomResourceDefinition, Service, RoleBinding | required=PASS; top-level=PASS | none |
| cluster/sealed-secrets/kustomization.yaml | kustomization | OK | kustomization | Kustomization | required=PASS; top-level=PASS | none |

## docs

| File | Type | Status | Role | Kinds | Validation | Warnings |
|---|---|---:|---|---|---|---|
| docs/get-started.md | markdown | N/A | N/A |  | not yaml | see security report |

## hack

| File | Type | Status | Role | Kinds | Validation | Warnings |
|---|---|---:|---|---|---|---|
| hack/kind-smoke.sh | shell | N/A | N/A |  | not yaml | see security report |
| hack/render-all.sh | shell | N/A | N/A |  | not yaml | see security report |
| hack/validate-yaml.py | python | N/A | N/A |  | not yaml | see security report |

## scripts

| File | Type | Status | Role | Kinds | Validation | Warnings |
|---|---|---:|---|---|---|---|
| scripts/.env.example | env-template | N/A | N/A |  | not yaml | see security report |
| scripts/apply.sh | shell | N/A | N/A |  | not yaml | see security report |
| scripts/generate-sealed-secret.sh | shell | N/A | N/A |  | not yaml | see security report |
| scripts/render.sh | shell | N/A | N/A |  | not yaml | see security report |
| scripts/update-secret.sh | shell | N/A | N/A |  | not yaml | see security report |
