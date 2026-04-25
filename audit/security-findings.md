# Security Findings

## High

- `apps/grim-backend/overlays/production/ingress-openapi.yaml:10`: Hardcoded personal domain remains. Environment-specific hostnames should be placeholders or overlays.
- `apps/grim-backend/overlays/production/ingress-patch.yaml:14`: Hardcoded personal domain remains. Environment-specific hostnames should be placeholders or overlays.
- `apps/grim-backend/overlays/production/ingress-root-redirect.yaml:7`: Hardcoded personal domain remains. Environment-specific hostnames should be placeholders or overlays.
- `apps/minio/base/deployment.yaml:37`: Hardcoded personal domain remains. Environment-specific hostnames should be placeholders or overlays.
- `apps/minio/overlays/production/ingress.yaml:16`: Hardcoded personal domain remains. Environment-specific hostnames should be placeholders or overlays.
- `cluster/argocd/argocd-server-ingress.yaml:12`: Hardcoded personal domain remains. Environment-specific hostnames should be placeholders or overlays.

## Medium

- `apps/grim-backend/base/deployment.yaml:20`: Container image uses floating latest tag: ghcr.io/lowjungxuandev/grim/backend:latest. Floating image tags reduce reproducibility; prefer immutable tags or digests.
- `apps/grim-backend/base/ingress.yaml:2`: Ingress does not define TLS. Ingress TLS is expected for exposed HTTP services; production overlays should add a TLS block.
- `apps/minio/base/pv.yaml:12`: PersistentVolume uses hostPath. hostPath storage is acceptable for single-node lab use but not portable production storage.
- `cluster/argocd/argocd-cmd-params-patch.yaml:7`: Argo CD subpath/basehref/rootpath configuration remains. Dedicated host routing avoids path-prefix behavior and simplifies ingress TLS.
- `cluster/argocd/argocd-secret-accounts-patch.yaml:6`: Argo CD local account password patch stores a bcrypt hash. The hash is not plaintext, but the local account remains sensitive configuration.
- `cluster/argocd/argocd-server-deployment-patch.yaml:14`: Argo CD subpath/basehref/rootpath configuration remains. Dedicated host routing avoids path-prefix behavior and simplifies ingress TLS.
- `cluster/argocd/gitops-git-daemon-deployment.yaml:55`: Deployment uses hostPath volume. hostPath couples workloads to node-local filesystem state and increases blast radius.
- `cluster/argocd/gitops-repo-deployment.yaml:58`: Deployment uses hostPath volume. hostPath couples workloads to node-local filesystem state and increases blast radius.
- `cluster/argocd/grim-backend-application.yaml:11`: Argo CD Application uses internal git:// source. The Git source of truth is inside the same cluster it manages; external Git remains deferred.
- `cluster/argocd/grim-backend-application.yaml:18`: Argo CD Application enables automated prune/self-heal. Automated remediation is useful but increases the impact of a bad source commit.
- `cluster/argocd/grim-image-updater.yaml:8`: Argo CD Image Updater write-back uses argocd method. Git write-back is deferred until an external Git source is selected.
- `cluster/argocd/minio-application.yaml:11`: Argo CD Application uses internal git:// source. The Git source of truth is inside the same cluster it manages; external Git remains deferred.
- `cluster/argocd/minio-application.yaml:18`: Argo CD Application enables automated prune/self-heal. Automated remediation is useful but increases the impact of a bad source commit.
- `cluster/metrics-server/kustomization.yaml:13`: metrics-server skips kubelet TLS verification. This flag is useful for lab clusters but should be replaced by kubelet serving certificate trust in production.

## Low

- `apps/grim-backend/base/secret-template.yaml:7`: Secret template contains placeholder data and is not intended for Kustomize resources. Secret templates are acceptable only when they are not referenced by an overlay and do not contain real values.
- `apps/minio/base/secret-template.yaml:6`: Secret template contains placeholder data and is not intended for Kustomize resources. Secret templates are acceptable only when they are not referenced by an overlay and do not contain real values.
