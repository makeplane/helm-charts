#!/usr/bin/env bash
#
# Render-and-assert tests for plane-enterprise's Redis wiring (local, remote URL,
# external_secrets.redis, Redis Sentinel). No cluster needed: every check runs on
# `helm template` output.
#
#   charts/plane-enterprise/ci/render-test.sh [BASE_REF]
#
# Needs helm 3+, yq v4 (mikefarah) and jq. BASE_REF (default: $BASE_REF, else
# origin/master) is the git ref that Plane AI's manifests are compared against: outside
# Sentinel mode this chart must not change what pi receives. Set SKIP_BASE_COMPARE=1
# to skip that comparison (e.g. in a tarball with no git).
#
# Values files: ci/*-values.yaml must render; ci/fail/*.yaml must fail with the
# message listed in FAIL_CASES below.

set -euo pipefail

CHART_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CI_DIR="$CHART_DIR/ci"
BASE_REF=${1:-${BASE_REF:-origin/master}}
RELEASE=plane
NAMESPACE=plane

for tool in helm yq jq; do
  command -v "$tool" >/dev/null || { echo "render-test: $tool is required" >&2; exit 2; }
done

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

failures=0
pass() { echo "ok   - $*"; }
fail() { echo "FAIL - $*"; failures=$((failures + 1)); }

# Job names carry a render timestamp and every object a chart-version label; strip
# both so two renders can be compared.
normalize() { sed -E -e 's/-[0-9]{8}-[0-9]{6}/-TS/g' -e 's/(helm\.sh\/chart: )plane-enterprise-.*/\1plane-enterprise/'; }

render() { # chart_dir values_file out_file [helm args...]
  helm template "$RELEASE" "$1" -n "$NAMESPACE" -f "$2" "${@:4}" | normalize > "$3"
}

# One JSON document per manifest, for jq.
to_json() { yq -o=json -I=0 'select(. != null)' "$1"; }

# Workloads that read Redis, by the env helper they use. pi is listed separately: it
# gets the new variables only in Sentinel mode.
APP_WORKLOADS="plane-api-wl plane-external-api-wl plane-worker-wl plane-worker-importers-wl
  plane-beat-worker-wl plane-outbox-poller-wl plane-automation-consumer-wl
  plane-webhook-consumer-wl plane-agent-consumer-wl plane-api-migrate-TS plane-api-search-index"
NODE_WORKLOADS="plane-live-wl plane-live-exporter-wl plane-silo-wl"
MCP_WORKLOAD="plane-mcp-server-wl"
REDIS_WORKLOADS="$APP_WORKLOADS $NODE_WORKLOADS $MCP_WORKLOAD"
PI_WORKLOADS="plane-pi-api-wl plane-pi-worker-wl plane-pi-beat-wl plane-pi-api-migrate-TS"
# Secrets that carry REDIS_URL, and so the Sentinel-mode passwords.
REDIS_SECRETS="plane-app-secrets plane-live-secrets plane-silo-secrets plane-mcp-server-secrets"
NEW_VARS="REDIS_SENTINELS REDIS_SENTINEL_MASTER REDIS_SENTINEL_USERNAME REDIS_SENTINEL_PASSWORD
  REDIS_USERNAME REDIS_DB REDIS_SENTINEL_SSL REDIS_SSL_VERIFY"

# Value of an env entry on a workload's main container: the literal value,
# "secret:<name>/<key>" for a secretKeyRef, "<unset>" when absent, or "<no-workload>".
# Reads the JSON form of a render ($1.json, written by the main loop).
env_of() { # file workload var
  jq -rs --arg w "$2" --arg v "$3" '
    [.[] | select((.kind == "Deployment" or .kind == "Job") and .metadata.name == $w)] |
    if length == 0 then "<no-workload>" else
      ([.[0].spec.template.spec.containers[0].env // [] | .[] | select(.name == $v)] | last) as $e |
      if $e == null then "<unset>"
      elif $e.valueFrom.secretKeyRef then "secret:\($e.valueFrom.secretKeyRef.name)/\($e.valueFrom.secretKeyRef.key)"
      else ($e.value // "") end
    end' "$1.json"
}

# How many times a var appears in a workload's env list (duplicates are a smell:
# the later one silently wins).
env_count() { # file workload var
  jq -rs --arg w "$2" --arg v "$3" '
    [.[] | select((.kind == "Deployment" or .kind == "Job") and .metadata.name == $w) |
     .spec.template.spec.containers[0].env // [] | .[] | select(.name == $v)] | length' "$1.json"
}

# What a workload's pod does with a custom CA, as "<volume> <install> <trust>" of yes/no:
# the CA volume, the step that installs it, and the variable that makes the client trust it.
ca_python() { # file workload
  jq -rs --arg w "$2" '
    [.[] | select((.kind == "Deployment" or .kind == "Job") and .metadata.name == $w)][0].spec.template.spec |
    [ (any(.volumes[]?; .name == "s3-custom-ca") and any(.containers[0].volumeMounts[]?; .mountPath == "/s3-custom-ca")),
      ((.containers[0].command // []) | join(" ") | contains("plane_install_custom_ca")),
      any(.containers[0].env[]?; .name == "SSL_CERT_FILE") ] |
    map(if . then "yes" else "no" end) | join(" ")' "$1.json"
}
ca_node() { # file workload
  jq -rs --arg w "$2" '
    [.[] | select((.kind == "Deployment" or .kind == "Job") and .metadata.name == $w)][0].spec.template.spec |
    [ (any(.volumes[]?; .name == "s3-custom-ca") and any(.containers[0].volumeMounts[]?; .mountPath == "/ca-bundle")),
      any(.initContainers[]?; .name == "prepare-ca-bundle"),
      any(.containers[0].env[]?; .name == "NODE_EXTRA_CA_CERTS") ] |
    map(if . then "yes" else "no" end) | join(" ")' "$1.json"
}
# Main-container command as one line, for the entrypoint checks.
command_of() { # file workload
  jq -rs --arg w "$2" '
    [.[] | select((.kind == "Deployment" or .kind == "Job") and .metadata.name == $w)][0].spec.template.spec.containers[0].command // [] | join(" ")' "$1.json"
}
# Every workload told about the sentinels, found from the render rather than a list, so a
# new Redis consumer can't miss the CA unnoticed.
sentinel_workloads() { # file
  jq -rs '.[] | select(.kind == "Deployment" or .kind == "Job") |
    select(any(.spec.template.spec.containers[0].env[]?; .name == "REDIS_SENTINELS")) | .metadata.name' "$1.json"
}
has_ca_volume() { # file workload
  jq -rs --arg w "$2" '
    [.[] | select((.kind == "Deployment" or .kind == "Job") and .metadata.name == $w)][0].spec.template.spec |
    any(.volumes[]?; .name == "s3-custom-ca")' "$1.json"
}

run_as_user() { # file workload
  jq -rs --arg w "$2" '
    [.[] | select((.kind == "Deployment" or .kind == "Job") and .metadata.name == $w)][0].spec.template.spec.containers[0].securityContext.runAsUser' "$1.json"
}
# The order of the custom CA attempts in a workload's command: system store, own bundle, warning.
ca_attempts_in_order() { # file workload
  jq -rs --arg w "$2" '
    [.[] | select((.kind == "Deployment" or .kind == "Job") and .metadata.name == $w)][0].spec.template.spec.containers[0].command // [] | join(" ") |
    test("if plane_install_custom_ca; then\\s+:\\s+elif plane_build_ca_bundle; then\\s+:\\s+else\\s+echo \"plane: WARNING")' "$1.json"
}

# Runs a workload's rendered install script on this machine and prints what it logged and
# the environment it left. Its paths are moved under a scratch directory and the trust tools
# are out of reach, so the system store can't be updated, as in a non-root pod, even when
# this runs as root.
run_ca_script() { # file workload scratch tmpdir
  local script
  script=$(jq -rs --arg w "$2" '
    [.[] | select((.kind == "Deployment" or .kind == "Job") and .metadata.name == $w)][0].spec.template.spec.containers[0].command[2]' "$1.json" |
    sed -e '/^exec /d' -e "s#/s3-custom-ca#$3/ca#g" -e "s#/etc/ssl/certs/ca-certificates.crt#$3/system.crt#g" \
      -e "s#/etc/pki/tls/certs/ca-bundle.crt#$3/absent#g" -e "s#/etc/ssl/cert.pem#$3/absent#g" \
      -e "s#/dev/shm#$3/shm#g" -e 's#update-ca-#absent-update-ca-#g')
  env -i PATH="$PATH" TMPDIR="$4" bash -c "$script"$'\nenv' 2>&1
}

# The non-root fallback, run for real: the bundle lands where it should, holds the image's
# CAs and the supplied ones, and every client variable points at it. When that can't happen
# the warning is the last resort.
check_ca_fallback() { # case file
  local dir="$WORK/ca-fallback" out bundle v
  if ! command -v openssl >/dev/null; then
    echo "render-test: openssl not found, skipping the run of the non-root CA fallback" >&2
    return 0
  fi
  mkdir -p "$dir/ca" "$dir/shm" "$dir/tmp"
  openssl req -x509 -newkey rsa:2048 -nodes -keyout /dev/null -subj /CN=ci-system -days 2 -out "$dir/system.crt" 2>/dev/null
  openssl req -x509 -newkey rsa:2048 -nodes -keyout /dev/null -subj /CN=ci-private -days 2 -out "$dir/ca/ca.crt" 2>/dev/null

  out=$(run_ca_script "$2" plane-worker-wl "$dir" "$dir/tmp")
  bundle=$(sed -n 's/^SSL_CERT_FILE=//p' <<<"$out")
  case "$bundle" in
    "$dir"/tmp/plane-ca.*/ca-bundle.crt) pass "$1: the bundle goes in a directory of its own under the temp dir" ;;
    *) fail "$1: bundle at '$bundle':"$'\n'"$out" ;;
  esac
  for v in REQUESTS_CA_BUNDLE CURL_CA_BUNDLE AWS_CA_BUNDLE; do
    expect "$1: $v points at the bundle" "$(sed -n "s/^$v=//p" <<<"$out")" "$bundle"
  done
  expect "$1: SSL_CERT_DIR is the bundle's directory" "$(sed -n 's/^SSL_CERT_DIR=//p' <<<"$out")" "${bundle%/*}"
  expect "$1: the bundle holds the image's CAs and the supplied ones" "$(grep -c 'BEGIN CERTIFICATE' "$bundle" 2>/dev/null)" "2"
  case "$out" in
    *WARNING*) fail "$1: warned although the bundle was built" ;;
    *) pass "$1: no warning when the bundle was built" ;;
  esac

  run_ca_script "$2" plane-worker-wl "$dir" "$dir/tmp" >/dev/null
  expect "$1: a restart replaces the last bundle" "$(find "$dir/tmp" -type d -name 'plane-ca.*' | wc -l | tr -d ' ')" "1"

  out=$(run_ca_script "$2" plane-worker-wl "$dir" "$dir/no-such-dir")
  case "$(sed -n 's/^SSL_CERT_FILE=//p' <<<"$out")" in
    "$dir"/shm/plane-ca.*/ca-bundle.crt) pass "$1: with no writable temp dir the bundle goes in /dev/shm" ;;
    *) fail "$1: temp dir not writable:"$'\n'"$out" ;;
  esac

  rm -rf "$dir/shm"
  out=$(run_ca_script "$2" plane-worker-wl "$dir" "$dir/no-such-dir")
  case "$out" in
    *"WARNING custom CA certificates were not installed"*) pass "$1: warns when nowhere is writable" ;;
    *) fail "$1: no warning when nowhere is writable:"$'\n'"$out" ;;
  esac
  expect "$1: SSL_CERT_FILE unset when nowhere is writable" "$(sed -n 's/^SSL_CERT_FILE=//p' <<<"$out")" ""

  echo "not a certificate" > "$dir/ca/ca.crt"
  out=$(run_ca_script "$2" plane-worker-wl "$dir" "$dir/tmp")
  case "$out" in
    *"WARNING custom CA certificates were not installed"*) pass "$1: warns on a file that isn't a certificate" ;;
    *) fail "$1: no warning on a file that isn't a certificate:"$'\n'"$out" ;;
  esac
  expect "$1: SSL_CERT_FILE unset on a file that isn't a certificate" "$(sed -n 's/^SSL_CERT_FILE=//p' <<<"$out")" ""
}

# A key of a Secret's stringData, "<unset>" when absent, "<no-secret>" when the
# Secret is not rendered.
secret_of() { # file secret key
  jq -rs --arg n "$2" --arg k "$3" '
    [.[] | select(.kind == "Secret" and .metadata.name == $n)] |
    if length == 0 then "<no-secret>" else (.[0].stringData[$k] // "<unset>") end' "$1.json"
}

expect() { # description actual expected
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1: got '$2', want '$3'"; fi
}

expect_env() { # case file workloads var expected
  local w
  for w in $3; do expect "$1: $w $4" "$(env_of "$2" "$w" "$4")" "$5"; done
}

# Outside Sentinel mode the new variables must not reach pi.
check_pi_untouched() { # case file
  local w v
  for w in $PI_WORKLOADS; do
    for v in $NEW_VARS; do
      [[ "$(env_of "$2" "$w" "$v")" == "<unset>" ]] || fail "$1: $w has $v outside Sentinel mode"
    done
  done
  pass "$1: no Sentinel variables on pi"
}

# pi's manifests (workloads, its Secret and ConfigMap) are identical to BASE_REF's
# render of the same values. Only the checksum/config pod annotation may differ: it
# hashes the whole chart config, so it moves whenever app-env does.
pi_docs() {
  to_json "$1" | jq -S 'select(
        ((.kind == "Deployment" or .kind == "Job") and (.metadata.name | test("^plane-pi-"))) or
        (.kind == "Secret" and .metadata.name == "plane-pi-api-secrets") or
        (.kind == "ConfigMap" and .metadata.name == "plane-pi-api-vars"))
      | del(.spec.template.metadata.annotations["checksum/config"]?)'
}

BASE_CHART=""
if [[ "${SKIP_BASE_COMPARE:-0}" != "1" ]]; then
  repo_root=$(git -C "$CHART_DIR" rev-parse --show-toplevel 2>/dev/null || true)
  chart_path=${CHART_DIR#"$repo_root"/}
  if [[ -n "$repo_root" ]] && git -C "$repo_root" rev-parse --verify --quiet "$BASE_REF^{commit}" >/dev/null; then
    mkdir -p "$WORK/base"
    git -C "$repo_root" archive "$BASE_REF" "$chart_path" | tar -x -C "$WORK/base"
    BASE_CHART="$WORK/base/$chart_path"
  else
    echo "render-test: base ref '$BASE_REF' not found; set SKIP_BASE_COMPARE=1 to run without it" >&2
    exit 2
  fi
fi

compare_pi_with_base() { # case values_file branch_render
  [[ -n "$BASE_CHART" ]] || return 0
  local base_out="$WORK/$1.base.yaml"
  if ! render "$BASE_CHART" "$2" "$base_out" 2>"$WORK/$1.base.err"; then
    fail "$1: $BASE_REF does not render these values: $(head -c 300 "$WORK/$1.base.err")"
    return
  fi
  if diff -u <(pi_docs "$base_out") <(pi_docs "$3") > "$WORK/$1.pi.diff"; then
    pass "$1: pi manifests identical to $BASE_REF"
  else
    fail "$1: pi manifests differ from $BASE_REF:"; cat "$WORK/$1.pi.diff"
  fi
}

# --- Cases that must render ----------------------------------------------------

LOCAL_URL="redis://$RELEASE-redis.$NAMESPACE.svc.cluster.local:6379/"

for values in "$CI_DIR"/*-values.yaml; do
  case_name=$(basename "$values" -values.yaml)
  out="$WORK/$case_name.yaml"
  echo "# $case_name"
  if ! render "$CHART_DIR" "$values" "$out" 2>"$WORK/$case_name.err"; then
    fail "$case_name: render failed: $(cat "$WORK/$case_name.err")"
    continue
  fi
  to_json "$out" > "$out.json"

  for w in $REDIS_WORKLOADS $PI_WORKLOADS; do
    [[ "$(env_of "$out" "$w" REDIS_SSL)" != "<no-workload>" ]] || fail "$case_name: $w not rendered"
    for v in $NEW_VARS REDIS_SSL REDIS_PASSWORD; do
      n=$(env_count "$out" "$w" "$v")
      [[ "${n:-0}" -le 1 ]] || fail "$case_name: $w lists $v $n times"
    done
  done

  # Passwords from values may only ever appear inside a Secret.
  for pw in ci-redis-password ci-sentinel-password; do
    if jq -c 'select(.kind != "Secret")' "$out.json" | grep -q -- "$pw"; then
      fail "$case_name: '$pw' rendered outside a Secret"
    fi
  done

  case "$case_name" in
    local-redis|remote-url|remote-external-secrets)
      for w in $REDIS_WORKLOADS; do
        for v in $NEW_VARS; do
          [[ "$(env_of "$out" "$w" "$v")" == "<unset>" ]] || fail "$case_name: $w has $v outside Sentinel mode"
        done
      done
      pass "$case_name: no Sentinel variables outside Sentinel mode"
      ;;
  esac

  case "$case_name" in
    local-redis)
      for s in plane-app-secrets plane-live-secrets plane-silo-secrets plane-mcp-server-secrets; do
        expect "$case_name: $s REDIS_URL" "$(secret_of "$out" "$s" REDIS_URL)" "$LOCAL_URL"
      done
      ;;

    remote-url)
      url=$(yq '.env.remote_redis_url' "$values")
      for s in $REDIS_SECRETS; do
        expect "$case_name: $s REDIS_URL" "$(secret_of "$out" "$s" REDIS_URL)" "$url"
      done
      ;;

    remote-external-secrets)
      for s in plane-app-secrets plane-live-secrets plane-silo-secrets; do
        expect "$case_name: $s REDIS_URL" "$(secret_of "$out" "$s" REDIS_URL)" ""
      done
      expect "$case_name: mcp-server-secrets REDIS_URL" "$(secret_of "$out" plane-mcp-server-secrets REDIS_URL)" "<unset>"
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_PASSWORD "secret:plane-redis/password"
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_SSL "1"
      # TLS for the MCP token store rides on a password-free rediss:// URL.
      # shellcheck disable=SC2016 # a literal Kubernetes $(VAR) reference
      expect_env "$case_name" "$out" "$MCP_WORKLOAD" REDIS_URL 'rediss://$(REDIS_HOST):$(REDIS_PORT)/'
      ;;

    sentinel|sentinel-external-secrets|sentinel-existing-secret|sentinel-private-ca)
      sentinels=$(yq '.env.redis_sentinels' "$values")
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_SENTINELS "$sentinels"
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_SENTINEL_MASTER "mymaster"
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_SSL "1"
      # Sentinel mode leaves REDIS_URL blank everywhere the chart renders it, and the
      # MCP deployment adds no rediss:// URL of its own.
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_URL "<unset>"
      # pi stays on Redis, through Sentinel: the marker makes it build the broker from these.
      expect_env "$case_name" "$out" "$PI_WORKLOADS" REDIS_SENTINELS "$sentinels"
      expect_env "$case_name" "$out" "$PI_WORKLOADS" REDIS_SENTINEL_MASTER "mymaster"
      expect "$case_name: pi CELERY_BROKER_URL" "$(secret_of "$out" plane-pi-api-secrets CELERY_BROKER_URL)" "sentinel://"
      ;;
  esac

  case "$case_name" in
    sentinel)
      expect "$case_name: pi REDIS_PASSWORD" "$(secret_of "$out" plane-pi-api-secrets REDIS_PASSWORD)" "ci-redis-password"
      expect "$case_name: pi REDIS_SENTINEL_PASSWORD" "$(secret_of "$out" plane-pi-api-secrets REDIS_SENTINEL_PASSWORD)" "ci-sentinel-password"
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_DB "2"
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_SENTINEL_SSL "0"
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_SSL_VERIFY "1"
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_USERNAME "plane"
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_SENTINEL_USERNAME "sentinel-user"
      # Passwords come from each service's own Secret, never from the manifest.
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_PASSWORD "<unset>"
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_SENTINEL_PASSWORD "<unset>"
      # No custom CA: the entrypoint runs directly and there's no CA volume.
      for w in $REDIS_WORKLOADS $PI_WORKLOADS; do
        [[ "$(has_ca_volume "$out" "$w")" == "false" ]] || fail "$case_name: $w has the CA volume without customCA"
      done
      expect "$case_name: beat-worker command" "$(command_of "$out" plane-beat-worker-wl)" "./bin/docker-entrypoint-beat.sh"
      expect "$case_name: migrator command" "$(command_of "$out" plane-api-migrate-TS)" "./bin/docker-entrypoint-migrator.sh"
      expect "$case_name: mcp-server keeps the image's command" "$(command_of "$out" "$MCP_WORKLOAD")" ""
      for s in $REDIS_SECRETS; do
        expect "$case_name: $s REDIS_URL" "$(secret_of "$out" "$s" REDIS_URL)" ""
        expect "$case_name: $s REDIS_PASSWORD" "$(secret_of "$out" "$s" REDIS_PASSWORD)" "ci-redis-password"
        expect "$case_name: $s REDIS_SENTINEL_PASSWORD" "$(secret_of "$out" "$s" REDIS_SENTINEL_PASSWORD)" "ci-sentinel-password"
      done
      ;;

    sentinel-external-secrets)
      expect_env "$case_name" "$out" "$PI_WORKLOADS" REDIS_PASSWORD "secret:plane-redis/redis-password"
      expect_env "$case_name" "$out" "$PI_WORKLOADS" REDIS_SENTINEL_PASSWORD "secret:plane-redis/sentinel-password"
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_DB "0"
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_SENTINEL_SSL "<unset>"
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_SSL_VERIFY "0"
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_PASSWORD "secret:plane-redis/redis-password"
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_USERNAME "secret:plane-redis/redis-username"
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_SENTINEL_USERNAME "secret:plane-redis/sentinel-username"
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_SENTINEL_PASSWORD "secret:plane-redis/sentinel-password"
      for s in $REDIS_SECRETS; do
        expect "$case_name: $s REDIS_URL" "$(secret_of "$out" "$s" REDIS_URL)" ""
        expect "$case_name: $s REDIS_PASSWORD" "$(secret_of "$out" "$s" REDIS_PASSWORD)" "<unset>"
        expect "$case_name: $s REDIS_SENTINEL_PASSWORD" "$(secret_of "$out" "$s" REDIS_SENTINEL_PASSWORD)" "<unset>"
      done
      ;;

    sentinel-private-ca)
      found=$(sentinel_workloads "$out")
      for w in $found; do
        expect "$case_name: $w has the CA volume" "$(has_ca_volume "$out" "$w")" "true"
      done
      for w in $APP_WORKLOADS $MCP_WORKLOAD $PI_WORKLOADS; do
        expect "$case_name: $w installs and trusts the CA" "$(ca_python "$out" "$w")" "yes yes yes"
      done
      for w in $NODE_WORKLOADS; do
        expect "$case_name: $w installs and trusts the CA" "$(ca_node "$out" "$w")" "yes yes yes"
      done
      # The install must end by running the same entrypoint as without a CA.
      for pair in plane-beat-worker-wl:beat plane-agent-consumer-wl:agent-consumer \
        plane-automation-consumer-wl:automation-consumer plane-webhook-consumer-wl:webhook-consumer \
        plane-outbox-poller-wl:outbox-poller plane-api-migrate-TS:migrator; do
        w=${pair%%:*}
        case "$(command_of "$out" "$w")" in
          *"exec ./bin/docker-entrypoint-${pair#*:}.sh"*) pass "$case_name: $w ends on its entrypoint" ;;
          *) fail "$case_name: $w does not exec its entrypoint" ;;
        esac
      done
      case "$(command_of "$out" "$MCP_WORKLOAD")" in
        *"exec python -m plane_mcp http"*) pass "$case_name: mcp-server ends on the image's command" ;;
        *) fail "$case_name: mcp-server does not exec the image's command" ;;
      esac
      # Non-root, the system trust store can't be written. Each Python workload has to get
      # past that with a bundle of its own, or it logs a warning and fails TLS to the CA.
      nonroot="$WORK/$case_name-nonroot.yaml"
      render "$CHART_DIR" "$values" "$nonroot" --set securityContext.enabled=true
      to_json "$nonroot" > "$nonroot.json"
      for w in $APP_WORKLOADS $MCP_WORKLOAD $PI_WORKLOADS; do
        expect "$case_name non-root: $w runs as uid 1000" "$(run_as_user "$nonroot" "$w")" "1000"
        expect "$case_name non-root: $w tries the system store, then a bundle, then warns" "$(ca_attempts_in_order "$nonroot" "$w")" "true"
      done
      check_ca_fallback "$case_name non-root" "$nonroot"
      ;;

    sentinel-existing-secret)
      # The operator's Secrets replace the chart's; the Sentinel settings still
      # arrive as env entries, and the passwords are the operator's to supply.
      for s in $REDIS_SECRETS; do
        expect "$case_name: $s not rendered" "$(secret_of "$out" "$s" REDIS_URL)" "<no-secret>"
      done
      expect_env "$case_name" "$out" "$REDIS_WORKLOADS" REDIS_PASSWORD "<unset>"
      ;;
  esac

  case "$case_name" in
    sentinel*) ;;
    *)
      check_pi_untouched "$case_name" "$out"
      compare_pi_with_base "$case_name" "$values" "$out"
      ;;
  esac
done

# --- Cases that must fail -----------------------------------------------------

FAIL_CASES=(
  "sentinel-local-setup.yaml|set services.redis.local_setup: false"
  "sentinel-no-master.yaml|env.redis_sentinel_master is empty"
  "sentinel-remote-url.yaml|together with env.remote_redis_url"
)
echo "# fail cases"
for entry in "${FAIL_CASES[@]}"; do
  file=${entry%%|*}
  want=${entry#*|}
  if helm template "$RELEASE" "$CHART_DIR" -n "$NAMESPACE" -f "$CI_DIR/fail/$file" >/dev/null 2>"$WORK/fail.err"; then
    fail "$file: rendered, want a failure"
  elif grep -qF -- "$want" "$WORK/fail.err"; then
    pass "$file: fails with '$want'"
  else
    fail "$file: failed for another reason: $(cat "$WORK/fail.err")"
  fi
done

echo
if (( failures > 0 )); then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
