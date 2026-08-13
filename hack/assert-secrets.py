#!/usr/bin/env python3
"""Assertions over a rendered Helm release, for the secret-externalization work.

Two of these encode the properties the whole exercise exists to guarantee:

  --no-plaintext-secrets  nothing that looks like a live credential is in the render
  --no-dsn                no connection string carries an embedded password

The second is the one that proves rotation is actually possible. A DSN in a Secret is
a rotation dead-end: when a managed database rotates the password, nothing can track
it, because the password is baked into a string somebody has to recompose. Discrete
credential parts are what make a verbatim mirror of a rotation secret work.

Usage:
    assert-secrets.py rendered.yaml --no-plaintext-secrets --no-dsn
    assert-secrets.py rendered.yaml --absent AWS_ACCESS_KEY_ID,AWS_REGION
    assert-secrets.py rendered.yaml --no-key-in-secrets OPENAI_API_KEY,CLAUDE_API_KEY
    assert-secrets.py rendered.yaml --order 'Deployment/t-pi-api-wl/t-pi-api:plane-ai=plane-pi'

Exits non-zero and prints every violation.
"""

import argparse
import re
import sys

import yaml

# Credential shapes worth failing a build over. Deliberately provider-prefix based:
# matching on entropy produces false positives on image digests and checksums.
SECRET_PATTERNS = {
    "OpenAI key": re.compile(r"sk-(proj-|svcacct-)?[A-Za-z0-9_-]{20,}"),
    "Anthropic key": re.compile(r"sk-ant-[A-Za-z0-9_-]{20,}"),
    "Groq key": re.compile(r"gsk_[A-Za-z0-9]{20,}"),
    "Docker Hub token": re.compile(r"dckr_(oat|pat)_[A-Za-z0-9_-]{10,}"),
    "AWS access key id": re.compile(r"\b(AKIA|ASIA)[0-9A-Z]{16}\b"),
    "GitLab OAuth token": re.compile(r"gloas-[A-Za-z0-9_-]{20,}"),
    "Google OAuth secret": re.compile(r"GOCSPX-[A-Za-z0-9_-]{10,}"),
    "private key block": re.compile(r"BEGIN [A-Z ]*PRIVATE KEY"),
}

# A connection string whose authority section carries a password.
DSN_WITH_PASSWORD = re.compile(r"\b(postgresql|postgres|amqps?|rediss?|mongodb)://[^\s:/@]+:[^\s@]+@")


def load(path):
    with open(path) as fh:
        return [d for d in yaml.safe_load_all(fh) if isinstance(d, dict)]


def iter_values(docs, kinds=("Secret", "ConfigMap")):
    """Yield (kind, name, key, value) for every data entry in the render."""
    for doc in docs:
        kind = doc.get("kind")
        if kind not in kinds:
            continue
        name = (doc.get("metadata") or {}).get("name", "")
        for field in ("stringData", "data"):
            for k, v in (doc.get(field) or {}).items():
                if isinstance(v, str):
                    yield kind, name, k, v


def iter_container_env(docs):
    """Yield (workload, container, env_entry) for explicit env lists."""
    for doc in docs:
        if doc.get("kind") not in ("Deployment", "StatefulSet", "DaemonSet", "Job"):
            continue
        name = (doc.get("metadata") or {}).get("name", "")
        pod = (((doc.get("spec") or {}).get("template") or {}).get("spec") or {})
        for c in (pod.get("initContainers") or []) + (pod.get("containers") or []):
            for e in c.get("env") or []:
                yield name, c.get("name", "?"), e


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("rendered")
    ap.add_argument("--no-plaintext-secrets", action="store_true")
    ap.add_argument("--no-dsn", action="store_true")
    ap.add_argument("--absent", default="", help="env names that must not appear anywhere")
    ap.add_argument("--no-key-in-secrets", default="", help="keys no rendered Secret may contain, even empty")
    ap.add_argument(
        "--order",
        action="append",
        default=[],
        metavar="WORKLOAD/CONTAINER:EARLIER=LATER",
        help="assert one envFrom secretRef precedes another",
    )
    args = ap.parse_args()

    docs = load(args.rendered)
    problems = []

    if args.no_plaintext_secrets:
        for kind, name, key, value in iter_values(docs):
            for label, pat in SECRET_PATTERNS.items():
                if pat.search(value):
                    problems.append(f"plaintext {label} in {kind}/{name} key {key}")
        for wl, cname, entry in iter_container_env(docs):
            v = entry.get("value")
            if isinstance(v, str):
                for label, pat in SECRET_PATTERNS.items():
                    if pat.search(v):
                        problems.append(f"plaintext {label} in {wl}/{cname} env {entry.get('name')}")

    if args.no_dsn:
        for kind, name, key, value in iter_values(docs):
            if DSN_WITH_PASSWORD.search(value):
                problems.append(
                    f"connection string with an embedded password in {kind}/{name} key {key} "
                    "— a rotated credential can never reach this; use the discrete credential parts"
                )

    if args.absent:
        wanted = {k for k in args.absent.split(",") if k}
        for kind, name, key, _ in iter_values(docs):
            if key in wanted:
                problems.append(f"{key} must be absent but is set in {kind}/{name}")
        for wl, cname, entry in iter_container_env(docs):
            if entry.get("name") in wanted:
                problems.append(f"{entry['name']} must be absent but is set on {wl}/{cname}")

    if args.no_key_in_secrets:
        wanted = {k for k in args.no_key_in_secrets.split(",") if k}
        for kind, name, key, value in iter_values(docs, kinds=("Secret",)):
            if key in wanted:
                shown = "empty string" if value == "" else "a value"
                problems.append(
                    f"Secret/{name} still renders {key} ({shown}) — envFrom resolves "
                    "later-source-wins, so this overwrites the external Secret"
                )

    for spec in args.order:
        target, _, pair = spec.partition(":")
        earlier, _, later = pair.partition("=")
        found = False
        for doc in docs:
            if doc.get("kind") not in ("Deployment", "StatefulSet", "Job"):
                continue
            name = (doc.get("metadata") or {}).get("name", "")
            pod = (((doc.get("spec") or {}).get("template") or {}).get("spec") or {})
            for c in pod.get("containers") or []:
                if f"{doc['kind']}/{name}/{c.get('name')}" != target:
                    continue
                found = True
                names = [s["secretRef"]["name"] for s in (c.get("envFrom") or []) if "secretRef" in s]
                if earlier not in names or later not in names:
                    problems.append(f"{target}: expected both {earlier} and {later} in envFrom, got {names}")
                elif names.index(earlier) > names.index(later):
                    problems.append(f"{target}: {earlier} must precede {later}, got {names}")
        if not found:
            problems.append(f"{target}: container not found in render")

    if problems:
        print(f"FAIL — {len(problems)} violation(s):", file=sys.stderr)
        for p in problems:
            print(f"  - {p}", file=sys.stderr)
        return 1
    print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
