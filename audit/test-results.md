# Test Results

Validation run date: 2026-04-25.

## Static validation

```text
PASS parsed_yaml=44/44
PASS required_field_checks
PASS top_level_key_checks
WARN security_findings=14
```

## Kustomize render

```text
PASS render apps/grim-backend/base
PASS render apps/grim-backend/overlays/production
PASS render apps/minio/base
PASS render apps/minio/overlays/production
PASS render cluster/argocd
PASS render cluster/ingress-nginx
PASS render cluster/metrics-server
PASS render cluster/network/calico
PASS render cluster/sealed-secrets
```

## kubeconform

```text
Summary: 192 resources found in 9 files - Valid: 158, Invalid: 0, Errors: 0, Skipped: 34
```

Skipped CRD/custom-resource schema summary:

```text
rendered/apps/grim-backend/base.yaml - grim-backend-env SealedSecret skipped
rendered/apps/grim-backend/overlays/production.yaml - grim-backend-env SealedSecret skipped
rendered/cluster/argocd.yaml - applications.argoproj.io CustomResourceDefinition skipped
rendered/cluster/argocd.yaml - applicationsets.argoproj.io CustomResourceDefinition skipped
rendered/cluster/argocd.yaml - appprojects.argoproj.io CustomResourceDefinition skipped
rendered/cluster/argocd.yaml - grim-backend Application skipped
rendered/cluster/argocd.yaml - grim-backend ImageUpdater skipped
rendered/cluster/argocd.yaml - imageupdaters.argocd-image-updater.argoproj.io CustomResourceDefinition skipped
rendered/cluster/argocd.yaml - minio Application skipped
rendered/cluster/network/calico.yaml - adminnetworkpolicies.policy.networking.k8s.io CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - baselineadminnetworkpolicies.policy.networking.k8s.io CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - bgpconfigurations.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - bgpfilters.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - bgppeers.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - blockaffinities.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - caliconodestatuses.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - clusterinformations.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - felixconfigurations.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - globalnetworkpolicies.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - globalnetworksets.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - hostendpoints.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - ipamblocks.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - ipamconfigs.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - ipamhandles.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - ippools.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - ipreservations.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - kubecontrollersconfigurations.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - networkpolicies.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - networksets.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - stagedglobalnetworkpolicies.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - stagedkubernetesnetworkpolicies.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - stagednetworkpolicies.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/network/calico.yaml - tiers.crd.projectcalico.org CustomResourceDefinition skipped
rendered/cluster/sealed-secrets.yaml - sealedsecrets.bitnami.com CustomResourceDefinition skipped
```

## kind smoke

```text
SKIP kind smoke: no supported container runtime
```

## Negative fixtures

```text
PASS parsed_yaml=3/3
FAIL required_field_checks=2
  bad-deployment-missing-selector.yaml: Deployment.spec.selector missing
  bad-ingress-no-rules.yaml: Ingress requires spec.rules or spec.defaultBackend
PASS top_level_key_checks
WARN security_findings=2
PASS negative fixtures triggered expected validator failures and warnings
```

## Secret and environment greps

```text
PASS no plaintext occurrence of SUPPLIED_PASSWORD in tracked files
PASS old public IP/domain removed from tracked manifests and docs
```

## Live server-side dry-run

```text
PASS server-side dry-run apps/grim-backend/overlays/production
PASS server-side dry-run apps/minio/overlays/production
```
