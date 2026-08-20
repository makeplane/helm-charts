#!/usr/bin/env python3
"""Resolve the effective environment of every container in a rendered Helm release.

Reading a chart diff tells you what the templates changed. It does not tell you what
the *pods* end up with, which is the only thing that matters when secrets move between
Secrets: `envFrom` resolves in list order with later sources winning, and explicit
`env` entries beat all of them. A key that moves from one Secret to another, or that a
suppression forgot to remove, shows up here and nowhere else.

Emits sorted JSON: {"kind/name/container": {"ENV_NAME": "<resolution>"}} where the
resolution is the literal value, or a marker:

    <from:secret/NAME#KEY>       valueFrom.secretKeyRef
    <from:configmap/NAME#KEY>    valueFrom.configMapKeyRef
    <from:field/PATH>            valueFrom.fieldRef
    <MISSING:secret/NAME>        envFrom referenced a Secret this release never renders
                                 (expected for operator-supplied external Secrets)

Usage:
    resolve-env.py rendered.yaml [--external NAME=KEY1,KEY2 ...] > effective.json

--external declares a Secret that lives outside the chart along with the keys it
carries, so its contribution can be modelled instead of reported as missing.
"""

import argparse
import json
import re
import base64
import binascii
import sys

import yaml

WORKLOAD_KINDS = {"Deployment", "StatefulSet", "DaemonSet", "Job", "CronJob"}
# Job names carry a render timestamp; strip it so runs are comparable.
TIMESTAMP_SUFFIX = re.compile(r"-\d{8}-\d{6}$")


def load_docs(path):
    with open(path) as fh:
        return [d for d in yaml.safe_load_all(fh) if isinstance(d, dict)]


def collect_sources(docs, external):
    """Map Secret/ConfigMap name -> {key: value}. External Secrets get sentinel values."""
    secrets, configmaps = dict(external), {}
    for doc in docs:
        kind = doc.get("kind")
        name = (doc.get("metadata") or {}).get("name", "")
        if kind == "Secret":
            merged = dict(doc.get("stringData") or {})
            # `data` is base64, and the decoded value is what the container actually
            # sees. Substituting a placeholder here would report two renders as
            # different whenever a chart moves a key between the two fields, and would
            # hide the value from every caller that compares resolved environments.
            for k, v in (doc.get("data") or {}).items():
                try:
                    decoded = base64.b64decode(v, validate=True).decode("utf-8")
                except (binascii.Error, UnicodeDecodeError, ValueError, TypeError):
                    decoded = "<base64:undecodable>"
                merged.setdefault(k, decoded)
            secrets[name] = merged
        elif kind == "ConfigMap":
            configmaps[name] = dict(doc.get("data") or {})
    return secrets, configmaps


def pod_templates(doc):
    """Yield (container_dict, is_init) for every container in a workload."""
    kind = doc.get("kind")
    spec = doc.get("spec") or {}
    if kind == "CronJob":
        spec = ((spec.get("jobTemplate") or {}).get("spec") or {})
    pod = ((spec.get("template") or {}).get("spec") or {})
    for c in pod.get("initContainers") or []:
        yield c, True
    for c in pod.get("containers") or []:
        yield c, False


def resolve_container(container, secrets, configmaps):
    env = {}
    # envFrom first, in order: later sources overwrite earlier ones.
    for source in container.get("envFrom") or []:
        if "secretRef" in source:
            name = source["secretRef"].get("name", "")
            if name in secrets:
                env.update(secrets[name])
            else:
                env[f"<MISSING:secret/{name}>"] = "<unresolved envFrom>"
        elif "configMapRef" in source:
            name = source["configMapRef"].get("name", "")
            if name in configmaps:
                env.update(configmaps[name])
            else:
                env[f"<MISSING:configmap/{name}>"] = "<unresolved envFrom>"
    # Explicit env always wins over envFrom.
    for entry in container.get("env") or []:
        name = entry.get("name")
        if not name:
            continue
        if "value" in entry:
            env[name] = entry["value"]
            continue
        vf = entry.get("valueFrom") or {}
        if "secretKeyRef" in vf:
            ref = vf["secretKeyRef"]
            env[name] = f"<from:secret/{ref.get('name')}#{ref.get('key')}>"
        elif "configMapKeyRef" in vf:
            ref = vf["configMapKeyRef"]
            env[name] = f"<from:configmap/{ref.get('name')}#{ref.get('key')}>"
        elif "fieldRef" in vf:
            env[name] = f"<from:field/{vf['fieldRef'].get('fieldPath')}>"
        else:
            env[name] = "<from:unknown>"
    return env


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("rendered")
    ap.add_argument(
        "--external",
        action="append",
        default=[],
        metavar="NAME=KEY1,KEY2",
        help="model an operator-supplied Secret and the keys it carries",
    )
    args = ap.parse_args()

    external = {}
    for spec in args.external:
        name, _, keys = spec.partition("=")
        external[name] = {k: f"<external:{name}#{k}>" for k in keys.split(",") if k}

    docs = load_docs(args.rendered)
    secrets, configmaps = collect_sources(docs, external)

    out = {}
    for doc in docs:
        if doc.get("kind") not in WORKLOAD_KINDS:
            continue
        name = TIMESTAMP_SUFFIX.sub("", (doc.get("metadata") or {}).get("name", ""))
        for container, is_init in pod_templates(doc):
            cname = container.get("name", "?")
            key = f"{doc['kind']}/{name}/{'init:' if is_init else ''}{cname}"
            out[key] = dict(sorted(resolve_container(container, secrets, configmaps).items()))

    json.dump(dict(sorted(out.items())), sys.stdout, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
