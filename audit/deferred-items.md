# Deferred Items

| Severity | Area | Deferred item | Reason |
|---|---|---|---|
| High | MinIO credentials | Production `minio-root-credentials` SealedSecret generation | The target cluster Sealed Secrets public certificate/controller must be reachable before production ciphertext can be generated. Use `scripts/generate-sealed-secret.sh` against the target cluster and do not commit plaintext credentials. |
| Medium | GitOps source | Internal `git://gitops-git.argocd.svc.cluster.local/gitops.git` source of truth | No external Git host was specified. The current internal Git source is preserved but remains architecture debt because it lives inside the cluster it manages. |
| Medium | Argo CD Image Updater | `writeBackConfig.method=argocd` | Git write-back should be selected after the external Git source is defined. |
| Medium | Argo CD RBAC | Local user `jungxuanlow` maps to `role:admin` | Existing behavior is preserved. Narrow RBAC or SSO should replace broad local admin access in steady state. |
| Medium | metrics-server | `--kubelet-insecure-tls` remains enabled | Kubelet serving certificate trust was not specified. This is preserved as a lab concession and should be replaced with verified kubelet TLS in production. |
| Medium | Storage | MinIO uses a hostPath-backed static PV | This is suitable for a single-node lab cluster only. A production storage class or external object storage target is not specified. |
| Medium | Backend runtime | `runAsNonRoot` is not forced on the backend container | The backend image user contract was not proven locally. Baseline seccomp/capability/privilege hardening was applied instead. |
