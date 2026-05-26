#!/usr/bin/env bash
#
# test-plugin.sh — battle-tested verification that the deployed plugin responds
# to the same call Argo CD's ApplicationSet controller makes.
#
# Usage:
#   ./test-plugin.sh [SERVICE_NAME] [NAMESPACE]
#
# Defaults to the Service name produced by `helm install asplugin .` in
# the `argocd` namespace.
#
# What it does:
#   1. Resolves the Service's cluster-internal address.
#   2. Reads the bearer token from the chart's Secret.
#   3. Issues the exact getparams.execute call ArgoCD makes.
#   4. Pretty-prints the result and exits non-zero on error / empty output.
#
# Run from inside the cluster (e.g. `kubectl run` debug pod) OR
# from outside with `kubectl port-forward` (see `port-forward` mode below).

set -euo pipefail

SERVICE="${1:-asplugin-argocd-applicationset-json-plugin}"
NAMESPACE="${2:-argocd}"
MODE="${MODE:-port-forward}"   # port-forward | in-cluster

err() { printf '\033[0;31m✗ %s\033[0m\n' "$*" >&2; }
ok()  { printf '\033[0;32m✓ %s\033[0m\n' "$*"; }
info() { printf '· %s\n' "$*"; }

require_cmd() {
  command -v "$1" >/dev/null || { err "missing dependency: $1"; exit 1; }
}

require_cmd kubectl
require_cmd curl
require_cmd jq

# Pull the bearer token out of the chart's Secret.
info "fetching token from secret/$SERVICE in namespace $NAMESPACE"
TOKEN=$(kubectl -n "$NAMESPACE" get secret "$SERVICE" -o jsonpath='{.data.token}' 2>/dev/null | base64 --decode)
if [[ -z "$TOKEN" ]]; then
  err "no token found at secret/$SERVICE — is the chart installed with this release name?"
  exit 1
fi
ok "token retrieved (${#TOKEN} bytes)"

call_plugin() {
  local url="$1"
  curl -sS -w '\n%{http_code}' \
    "$url/api/v1/getparams.execute" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"applicationSetName": "test-plugin-sh", "input": {"parameters": {}}}'
}

case "$MODE" in
  port-forward)
    PORT=4355
    info "starting port-forward to svc/$SERVICE:$PORT (Ctrl-C to abort if it hangs)"
    kubectl -n "$NAMESPACE" port-forward "svc/$SERVICE" "$PORT:$PORT" >/dev/null 2>&1 &
    PF_PID=$!
    trap 'kill $PF_PID 2>/dev/null || true' EXIT
    # Wait for port-forward to be ready.
    for _ in {1..30}; do
      if curl -sf --max-time 1 "http://127.0.0.1:$PORT" >/dev/null 2>&1 \
        || curl -s --max-time 1 -o /dev/null "http://127.0.0.1:$PORT"; then
        break
      fi
      sleep 0.2
    done
    URL="http://127.0.0.1:$PORT"
    ;;
  in-cluster)
    URL="http://$SERVICE.$NAMESPACE.svc.cluster.local:4355"
    ;;
  *)
    err "unknown MODE=$MODE (use port-forward or in-cluster)"
    exit 1
    ;;
esac

info "calling $URL/api/v1/getparams.execute"
RAW=$(call_plugin "$URL")
STATUS=$(echo "$RAW" | tail -n1)
BODY=$(echo "$RAW" | sed '$d')

if [[ "$STATUS" != "200" ]]; then
  err "HTTP $STATUS"
  echo "$BODY"
  exit 1
fi

# Validate shape: must be {"output": {"parameters": [...]}} with non-empty array.
COUNT=$(echo "$BODY" | jq -r '.output.parameters | length' 2>/dev/null || echo "-1")
if [[ "$COUNT" == "-1" ]]; then
  err "response is not valid JSON or missing output.parameters"
  echo "$BODY"
  exit 1
fi
if [[ "$COUNT" == "0" ]]; then
  err "plugin returned 0 parameters — check that plugin.url is reachable from the pod and the filter matches the JSON shape"
  echo "$BODY" | jq .
  exit 1
fi

ok "plugin returned $COUNT parameter(s):"
echo "$BODY" | jq '.output.parameters'
