#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

import yaml


KUSTOMIZATION_NAMES = {"kustomization.yaml", "kustomization.yml", "Kustomization"}
YAML_SUFFIXES = {".yaml", ".yml"}

KUSTOMIZATION_KEYS = {
    "apiVersion",
    "kind",
    "metadata",
    "namespace",
    "namePrefix",
    "nameSuffix",
    "commonLabels",
    "labels",
    "commonAnnotations",
    "resources",
    "bases",
    "components",
    "patches",
    "patchesStrategicMerge",
    "patchesJson6902",
    "images",
    "replicas",
    "configMapGenerator",
    "secretGenerator",
    "generatorOptions",
    "vars",
    "replacements",
    "transformers",
    "crds",
    "sortOptions",
}

RESOURCE_TOP_KEYS = {
    "apiVersion",
    "kind",
    "metadata",
    "spec",
    "data",
    "binaryData",
    "stringData",
    "type",
    "immutable",
    "rules",
    "subjects",
    "roleRef",
    "webhooks",
    "provisioner",
    "parameters",
    "reclaimPolicy",
    "volumeBindingMode",
    "allowVolumeExpansion",
    "mountOptions",
    "aggregationRule",
    "automountServiceAccountToken",
    "secrets",
    "imagePullSecrets",
}

COMMON_REQUIRED = {
    "Deployment": ["apiVersion", "kind", "metadata", "spec"],
    "Service": ["apiVersion", "kind", "metadata", "spec"],
    "Ingress": ["apiVersion", "kind", "metadata", "spec"],
    "HorizontalPodAutoscaler": ["apiVersion", "kind", "metadata", "spec"],
    "PodDisruptionBudget": ["apiVersion", "kind", "metadata", "spec"],
    "Namespace": ["apiVersion", "kind", "metadata"],
    "PersistentVolume": ["apiVersion", "kind", "metadata", "spec"],
    "PersistentVolumeClaim": ["apiVersion", "kind", "metadata", "spec"],
    "NetworkPolicy": ["apiVersion", "kind", "metadata", "spec"],
    "Secret": ["apiVersion", "kind", "metadata"],
    "ConfigMap": ["apiVersion", "kind", "metadata"],
    "Application": ["apiVersion", "kind", "metadata", "spec"],
    "SealedSecret": ["apiVersion", "kind", "metadata", "spec"],
}

FIRST_PARTY_DEPLOYMENTS = (
    "apps/",
    "cluster/argocd/gitops-git-daemon-deployment.yaml",
    "cluster/argocd/gitops-repo-deployment.yaml",
)


def repo_files(root: Path, include_fixtures: bool):
    try:
        out = subprocess.check_output(
            ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
            cwd=root,
            text=True,
            stderr=subprocess.DEVNULL,
        )
        paths = [p for p in out.splitlines() if p]
    except Exception:
        paths = [
            str(p.relative_to(root))
            for p in root.rglob("*")
            if p.is_file()
            and ".git" not in p.relative_to(root).parts
            and "rendered" not in p.relative_to(root).parts
            and ".bin" not in p.relative_to(root).parts
        ]

    result = []
    for rel in sorted(set(paths)):
        if not (root / rel).exists():
            continue
        if rel.startswith(".git/"):
            continue
        if rel.startswith("rendered/") or rel.startswith(".bin/"):
            continue
        if rel.startswith("audit/test-artifacts/"):
            continue
        if rel.startswith("tests/fixtures/") and not include_fixtures:
            continue
        result.append(rel)
    return result


def load_docs(path: Path):
    text = path.read_text(encoding="utf-8")
    return text, list(yaml.safe_load_all(text))


def nested_get(obj, keys):
    cur = obj
    for key in keys:
        if not isinstance(cur, dict) or key not in cur:
            return None
        cur = cur[key]
    return cur


def line_for(text, needle):
    if not needle:
        return None
    for i, line in enumerate(text.splitlines(), 1):
        if needle in line:
            return i
    return None


def add_finding(findings, severity, path, message, rationale, text="", needle=""):
    line = line_for(text, needle)
    findings.append(
        {
            "severity": severity,
            "path": path,
            "line": line,
            "message": message,
            "rationale": rationale,
        }
    )


def collect_kustomize_references(root: Path, files):
    patches = set()
    resources = set()
    for rel in files:
        path = root / rel
        if path.name not in KUSTOMIZATION_NAMES:
            continue
        try:
            _text, docs = load_docs(path)
        except Exception:
            continue
        if not docs or not isinstance(docs[0], dict):
            continue
        doc = docs[0]
        base = path.parent
        for key in ("patchesStrategicMerge",):
            for item in doc.get(key, []) or []:
                if isinstance(item, str):
                    patches.add(str((base / item).resolve().relative_to(root.resolve())))
        for item in doc.get("patches", []) or []:
            if isinstance(item, dict) and item.get("path"):
                patches.add(str((base / item["path"]).resolve().relative_to(root.resolve())))
            elif isinstance(item, str):
                patches.add(str((base / item).resolve().relative_to(root.resolve())))
        for key in ("resources", "components", "bases"):
            for item in doc.get(key, []) or []:
                if isinstance(item, str) and not re.match(r"^[a-z]+://", item) and not item.startswith("https://"):
                    target = base / item
                    if target.is_file():
                        resources.add(str(target.resolve().relative_to(root.resolve())))
                    elif target.is_dir():
                        for name in KUSTOMIZATION_NAMES:
                            if (target / name).exists():
                                resources.add(str((target / name).resolve().relative_to(root.resolve())))
                                break
    return patches, resources


def is_yaml(rel):
    return Path(rel).suffix in YAML_SUFFIXES


def file_type(rel):
    path = Path(rel)
    if path.name in KUSTOMIZATION_NAMES:
        return "kustomization"
    if path.suffix in YAML_SUFFIXES:
        return "yaml"
    if path.suffix == ".md":
        return "markdown"
    if path.suffix == ".sh":
        return "shell"
    if path.suffix == ".py":
        return "python"
    if path.suffix == ".json":
        return "json"
    if path.name.startswith(".env"):
        return "env-template"
    return path.suffix.lstrip(".") or "text"


def validate_doc(rel, doc, text, role, findings):
    errors = []
    extras = []
    warnings = []

    if doc is None:
        return errors, extras, warnings
    if not isinstance(doc, dict):
        return errors, extras, warnings

    kind = doc.get("kind")
    if kind == "Kustomization":
        allowed = KUSTOMIZATION_KEYS
    elif kind in {"InitConfiguration", "ClusterConfiguration", "KubeletConfiguration"}:
        allowed = set(doc.keys())
    elif kind:
        allowed = RESOURCE_TOP_KEYS
    else:
        allowed = set()

    if allowed:
        for key in doc:
            if key not in allowed:
                extras.append(key)

    if role != "patch" and kind in COMMON_REQUIRED:
        for key in COMMON_REQUIRED[kind]:
            if key not in doc:
                errors.append(f"{kind} missing top-level {key}")

    if role != "patch" and kind == "Deployment":
        if nested_get(doc, ["spec", "selector"]) is None:
            errors.append("Deployment.spec.selector missing")
        containers = nested_get(doc, ["spec", "template", "spec", "containers"])
        if not containers:
            errors.append("Deployment.spec.template.spec.containers missing")
    if role != "patch" and kind == "Service":
        if not nested_get(doc, ["spec", "ports"]):
            errors.append("Service.spec.ports missing")
    if role != "patch" and kind == "Ingress":
        spec = doc.get("spec") if isinstance(doc.get("spec"), dict) else {}
        if not spec.get("rules") and not spec.get("defaultBackend"):
            errors.append("Ingress requires spec.rules or spec.defaultBackend")
    if role != "patch" and kind == "HorizontalPodAutoscaler":
        if nested_get(doc, ["spec", "scaleTargetRef"]) is None:
            errors.append("HorizontalPodAutoscaler.spec.scaleTargetRef missing")
    if role != "patch" and kind == "PodDisruptionBudget":
        if nested_get(doc, ["spec", "selector"]) is None:
            errors.append("PodDisruptionBudget.spec.selector missing")

    if kind == "Secret":
        data_keys = []
        for key in ("stringData", "data"):
            if isinstance(doc.get(key), dict):
                data_keys.extend(doc[key].keys())
        if data_keys:
            if rel.endswith("secret-template.yaml"):
                add_finding(
                    findings,
                    "low",
                    rel,
                    "Secret template contains placeholder data and is not intended for Kustomize resources",
                    "Secret templates are acceptable only when they are not referenced by an overlay and do not contain real values.",
                    text,
                    "stringData:",
                )
            elif role == "patch" and "bcrypt" in text.lower() or "accounts.jungxuanlow.password" in text:
                add_finding(
                    findings,
                    "medium",
                    rel,
                    "Argo CD local account password patch stores a bcrypt hash",
                    "The hash is not plaintext, but the local account remains sensitive configuration.",
                    text,
                    "accounts.jungxuanlow.password",
                )
            else:
                add_finding(
                    findings,
                    "high",
                    rel,
                    "Plaintext Kubernetes Secret manifest is committed",
                    "Kubernetes Secrets are base64-encoded by default and should not be stored as plaintext in Git.",
                    text,
                    "stringData:",
                )

    if kind == "Ingress" and role != "patch":
        if nested_get(doc, ["spec", "tls"]) is None:
            add_finding(
                findings,
                "medium",
                rel,
                "Ingress does not define TLS",
                "Ingress TLS is expected for exposed HTTP services; production overlays should add a TLS block.",
                text,
                "kind: Ingress",
            )

    if kind == "Namespace" and role != "patch":
        labels = nested_get(doc, ["metadata", "labels"]) or {}
        required = [
            "pod-security.kubernetes.io/warn",
            "pod-security.kubernetes.io/warn-version",
            "pod-security.kubernetes.io/audit",
            "pod-security.kubernetes.io/audit-version",
        ]
        missing = [key for key in required if key not in labels]
        if missing:
            add_finding(
                findings,
                "high",
                rel,
                "Namespace missing Pod Security warn/audit labels",
                "Pod Security labels provide namespace-level audit and warning coverage without enforcing yet.",
                text,
                "kind: Namespace",
            )

    if kind == "Deployment" and role != "patch":
        pod_spec = nested_get(doc, ["spec", "template", "spec"]) or {}
        containers = pod_spec.get("containers") or []
        first_party = rel.startswith(FIRST_PARTY_DEPLOYMENTS)
        if first_party:
            if nested_get(doc, ["spec", "template", "spec", "securityContext", "seccompProfile", "type"]) is None:
                add_finding(
                    findings,
                    "high",
                    rel,
                    "Deployment missing pod seccomp RuntimeDefault",
                    "RuntimeDefault seccomp is a low-risk pod-level hardening baseline.",
                    text,
                    "kind: Deployment",
                )
            for container in containers:
                if not isinstance(container, dict):
                    continue
                sc = container.get("securityContext") or {}
                if not sc:
                    add_finding(
                        findings,
                        "high",
                        rel,
                        f"Container {container.get('name', '<unknown>')} missing securityContext",
                        "Container hardening should disable privilege escalation and drop Linux capabilities.",
                        text,
                        f"name: {container.get('name', '')}",
                    )
        for container in containers:
            if not isinstance(container, dict):
                continue
            image = container.get("image", "")
            if image.endswith(":latest"):
                add_finding(
                    findings,
                    "medium",
                    rel,
                    f"Container image uses floating latest tag: {image}",
                    "Floating image tags reduce reproducibility; prefer immutable tags or digests.",
                    text,
                    image,
                )
            for port in container.get("ports") or []:
                if isinstance(port, dict) and "hostPort" in port:
                    add_finding(
                        findings,
                        "high",
                        rel,
                        "Container uses hostPort",
                        "hostPort increases node-level exposure and should be avoided unless explicitly required.",
                        text,
                        "hostPort",
                    )
        for volume in pod_spec.get("volumes") or []:
            if isinstance(volume, dict) and "hostPath" in volume:
                add_finding(
                    findings,
                    "medium",
                    rel,
                    "Deployment uses hostPath volume",
                    "hostPath couples workloads to node-local filesystem state and increases blast radius.",
                    text,
                    "hostPath",
                )

    if kind == "PersistentVolume" and nested_get(doc, ["spec", "hostPath"]) is not None:
        add_finding(
            findings,
            "medium",
            rel,
            "PersistentVolume uses hostPath",
            "hostPath storage is acceptable for single-node lab use but not portable production storage.",
            text,
            "hostPath",
        )

    if kind == "Application":
        repo = nested_get(doc, ["spec", "source", "repoURL"])
        if isinstance(repo, str) and repo.startswith("git://"):
            add_finding(
                findings,
                "medium",
                rel,
                "Argo CD Application uses internal git:// source",
                "The Git source of truth is inside the same cluster it manages; external Git remains deferred.",
                text,
                "repoURL:",
            )
        automated = nested_get(doc, ["spec", "syncPolicy", "automated"])
        if isinstance(automated, dict) and (automated.get("prune") or automated.get("selfHeal")):
            add_finding(
                findings,
                "medium",
                rel,
                "Argo CD Application enables automated prune/self-heal",
                "Automated remediation is useful but increases the impact of a bad source commit.",
                text,
                "automated:",
            )

    return errors, extras, warnings


def scan_text(rel, text, findings):
    if "lowjungxuan.dpdns.org" in text:
        add_finding(
            findings,
            "high",
            rel,
            "Hardcoded personal domain remains",
            "Environment-specific hostnames should be placeholders or overlays.",
            text,
            "lowjungxuan.dpdns.org",
        )
    if "89.167.40.225" in text:
        add_finding(
            findings,
            "high",
            rel,
            "Hardcoded public control-plane IP remains",
            "Public IPs should not be committed into reusable cluster manifests.",
            text,
            "89.167.40.225",
        )
    if re.search(r"/(stable|latest)(/|$)", text):
        add_finding(
            findings,
            "medium",
            rel,
            "Floating remote install URL remains",
            "Remote install URLs should be pinned to explicit release tags for reproducibility.",
            text,
            "latest" if "latest" in text else "stable",
        )
    if "server.basehref" in text or "server.rootpath" in text or "--basehref" in text or "--rootpath" in text:
        add_finding(
            findings,
            "medium",
            rel,
            "Argo CD subpath/basehref/rootpath configuration remains",
            "Dedicated host routing avoids path-prefix behavior and simplifies ingress TLS.",
            text,
            "server.basehref" if "server.basehref" in text else "rootpath",
        )
    if "--kubelet-insecure-tls" in text:
        add_finding(
            findings,
            "medium",
            rel,
            "metrics-server skips kubelet TLS verification",
            "This flag is useful for lab clusters but should be replaced by kubelet serving certificate trust in production.",
            text,
            "--kubelet-insecure-tls",
        )
    if "method: argocd" in text:
        add_finding(
            findings,
            "medium",
            rel,
            "Argo CD Image Updater write-back uses argocd method",
            "Git write-back is deferred until an external Git source is selected.",
            text,
            "method: argocd",
        )


def grouped_directory(path):
    parts = Path(path).parts
    if not parts:
        return "."
    if parts[0].startswith("."):
        return parts[0]
    if len(parts) == 1:
        return "."
    return "/".join(parts[:2]) if parts[0] in {"apps", "cluster"} else parts[0]


def markdown_table(rows):
    lines = [
        "| File | Type | Status | Role | Kinds | Validation | Warnings |",
        "|---|---|---:|---|---|---|---|",
    ]
    for row in rows:
        lines.append(
            "| {path} | {type} | {status} | {role} | {kinds} | {validation} | {warnings} |".format(
                **{k: str(v).replace("|", "\\|") for k, v in row.items()}
            )
        )
    return "\n".join(lines)


def write_reports(root, inventory, findings, parsed_ok, parsed_total, required_errors, top_extras):
    audit = root / "audit"
    audit.mkdir(exist_ok=True)
    (audit / "manifest-inventory.json").write_text(json.dumps(inventory, indent=2) + "\n", encoding="utf-8")

    grouped = defaultdict(list)
    for row in inventory:
        grouped[grouped_directory(row["path"])].append(row)

    md = ["# Manifest Inventory", ""]
    md.append(f"PASS parsed_yaml={parsed_ok}/{parsed_total}")
    md.append("PASS required_field_checks" if not required_errors else f"FAIL required_field_checks={len(required_errors)}")
    md.append("PASS top_level_key_checks" if not top_extras else f"FAIL top_level_key_checks={len(top_extras)}")
    md.append("")
    for group in sorted(grouped):
        md.append(f"## {group}")
        md.append("")
        md.append(markdown_table(grouped[group]))
        md.append("")
    (audit / "manifest-inventory.md").write_text("\n".join(md), encoding="utf-8")

    sec = ["# Security Findings", ""]
    if not findings:
        sec.append("No security warnings detected.")
    else:
        by_severity = defaultdict(list)
        for finding in findings:
            by_severity[finding["severity"]].append(finding)
        for severity in ("critical", "high", "medium", "low"):
            items = by_severity.get(severity, [])
            if not items:
                continue
            sec.append(f"## {severity.title()}")
            sec.append("")
            for item in items:
                ref = item["path"]
                if item.get("line"):
                    ref = f"{ref}:{item['line']}"
                sec.append(f"- `{ref}`: {item['message']}. {item['rationale']}")
            sec.append("")
    (audit / "security-findings.md").write_text("\n".join(sec), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--write-report", action="store_true")
    parser.add_argument("--include-fixtures", action="store_true")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    files = repo_files(root, args.include_fixtures)
    patches, kustomize_resources = collect_kustomize_references(root, files)

    inventory = []
    findings = []
    parse_errors = []
    required_errors = []
    top_extras = []
    parsed_total = 0
    parsed_ok = 0

    for rel in files:
        path = root / rel
        ftype = file_type(rel)
        row = {
            "path": rel,
            "type": ftype,
            "status": "N/A",
            "role": "N/A",
            "kinds": "",
            "validation": "",
            "warnings": "",
        }

        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            text = ""

        if text and rel != "hack/validate-yaml.py" and not rel.startswith("audit/"):
            scan_text(rel, text, findings)

        if is_yaml(rel):
            parsed_total += 1
            role = "full resource"
            if path.name in KUSTOMIZATION_NAMES:
                role = "kustomization"
            elif rel in patches:
                role = "patch fragment"
            elif rel.endswith("secret-template.yaml"):
                role = "template"
            row["role"] = role
            try:
                docs = list(yaml.safe_load_all(text))
                parsed_ok += 1
                row["status"] = "OK-patch" if role == "patch fragment" else "OK"
                kinds = [doc.get("kind", "<none>") for doc in docs if isinstance(doc, dict)]
                row["kinds"] = ", ".join(kinds)
                local_required = []
                local_extras = []
                before_findings = len(findings)
                validation_role = "patch" if role == "patch fragment" else role
                for doc in docs:
                    errors, extras, _warnings = validate_doc(rel, doc, text, validation_role, findings)
                    local_required.extend(errors)
                    local_extras.extend(extras)
                if local_required:
                    required_errors.extend((rel, err) for err in local_required)
                if local_extras:
                    top_extras.extend((rel, extra) for extra in local_extras)
                row["validation"] = "required=PASS; top-level=PASS"
                if local_required:
                    row["validation"] = "required=FAIL: " + "; ".join(local_required)
                elif local_extras:
                    row["validation"] = "top-level=FAIL: " + ", ".join(local_extras)
                warning_count = len(findings) - before_findings
                row["warnings"] = str(warning_count) if warning_count else "none"
            except yaml.YAMLError as exc:
                parse_errors.append((rel, str(exc)))
                row["status"] = "FAIL"
                row["validation"] = f"parse error: {exc}"
        else:
            row["validation"] = "not yaml"
            row["warnings"] = "see security report" if text else "none"

        inventory.append(row)

    if args.write_report:
        write_reports(root, inventory, findings, parsed_ok, parsed_total, required_errors, top_extras)

    print(f"PASS parsed_yaml={parsed_ok}/{parsed_total}" if not parse_errors else f"FAIL parsed_yaml={parsed_ok}/{parsed_total}")
    if required_errors:
        print(f"FAIL required_field_checks={len(required_errors)}")
        for rel, err in required_errors:
            print(f"  {rel}: {err}")
    else:
        print("PASS required_field_checks")
    if top_extras:
        print(f"FAIL top_level_key_checks={len(top_extras)}")
        for rel, extra in top_extras:
            print(f"  {rel}: unexpected top-level key {extra}")
    else:
        print("PASS top_level_key_checks")
    print(f"WARN security_findings={len(findings)}")

    if parse_errors:
        for rel, err in parse_errors:
            print(f"FAIL parse error in {rel}: {err}")

    if parse_errors or required_errors or top_extras:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
