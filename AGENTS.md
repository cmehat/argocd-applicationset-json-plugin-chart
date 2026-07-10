# AGENTS.md — argocd-applicationset-json-plugin-chart

Guidance for AI agents (and humans) editing this repository.

## What this is

A Helm chart that deploys the backend for the **ArgoCD ApplicationSet JSON
plugin** (application code: <https://github.com/cmehat/argocd-applicationset-json-plugin>).
It renders a Deployment + Service + ConfigMap (+ optional Secret / ExternalSecret)
so an ArgoCD ApplicationSet *plugin generator* can fetch JSON from a URL, filter it
with JSONPath or jq, and emit Application parameters.

## Layout

- `Chart.yaml`, `values.yaml` — chart metadata and every tunable (documented in `README.md`).
- `templates/` — `deployment.yaml`, `service.yaml`, `configmap.yaml`, `secret.yaml`,
  `serviceaccount.yaml`, `_helpers.tpl`.
- `examples/` — a runnable ApplicationSet plus `test-plugin.sh`, which calls the
  plugin exactly the way ArgoCD does.

## Hard invariants — do not break these

1. **`tcpSocket` probes only.** The plugin exposes exactly one route,
   `POST /api/v1/getparams.execute` (token-authenticated). A `GET` returns `501`,
   so any `httpGet` probe on that path crash-loops the pod (`exitCode 137`). Keep
   liveness/readiness/startup on `tcpSocket` against `.Values.service.targetPort`.
2. **The generator ConfigMap must keep its shape.** `baseUrl` must include the
   Service port (`http://<fullname>.<namespace>.svc.cluster.local:{{ .Values.service.port }}`),
   and the label `app.kubernetes.io/part-of: argocd` must stay — ArgoCD only
   discovers plugin ConfigMaps that carry it.
3. **Consumers must deploy this chart on the ApplicationSet controller's
   cluster/namespace**, not on a workload cluster. This is an operational rule
   (see README → "Deploying with ArgoCD"); keep that section accurate if you
   change defaults.

## Validate changes

```bash
helm lint .
helm template t . --namespace argocd | less   # eyeball probes + configMap baseUrl
```

The render must show `tcpSocket` probes and a `baseUrl` ending in
`:{{ .Values.service.port }}` (e.g. `:4355`).

## Versioning / release

Bump `version` in `Chart.yaml` for chart changes, and `appVersion` when the plugin
image contract changes. This chart is frequently consumed directly from git at
`targetRevision: main` (ArgoCD git-as-Helm-source), so `main` must always render
cleanly.

## Housekeeping

If you add, rename, or change the default of a value, update the values table in
`README.md` to match.
