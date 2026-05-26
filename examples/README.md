# End-to-end example: deploy the plugin and use it as an ArgoCD ApplicationSet generator

This walkthrough deploys the `argocd-applicationset-json-plugin` Helm chart into the `argocd` namespace and registers it as an [ApplicationSet plugin generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Plugin/). The plugin fetches JSON from a URL, applies a JSONPath or jq filter, and emits one set of template parameters per match.

The companion plugin source lives at [cmehat/argocd-applicationset-json-plugin](https://github.com/cmehat/argocd-applicationset-json-plugin).

## Prerequisites

- A Kubernetes cluster with Argo CD installed (ApplicationSet controller enabled — it's bundled with Argo CD ≥ 2.3).
- `helm` ≥ 3.8 and `kubectl` configured against the cluster.
- The plugin image published somewhere the cluster can pull from. The chart defaults to `ghcr.io/cmehat/argocd-applicationset-json-plugin:jsonpath-1.0.0`; override `image.repository` / `image.tag` if you host it elsewhere.

## 1. Install the chart

```bash
helm install asplugin \
  --namespace argocd \
  --set plugin.url='https://example.com/data.json' \
  oci://ghcr.io/cmehat/charts/argocd-applicationset-json-plugin  # or: .  (when cloned)
```

This deploys:

- `Deployment` + `Service` running the plugin on port `4355`
- `ConfigMap` named `asplugin-argocd-applicationset-json-plugin` containing `baseUrl` and a `token` reference — this is what Argo CD's `configMapRef` points at
- `Secret` (or `ExternalSecret`) holding the plugin's bearer token
- `ServiceAccount`

Confirm it's running:

```bash
kubectl -n argocd get pods -l app=asplugin-argocd-applicationset-json-plugin
kubectl -n argocd rollout status deploy/asplugin-argocd-applicationset-json-plugin
```

## 2. Verify the plugin responds (battle-tested call)

Before wiring it into an ApplicationSet, hit it directly. This is the same call Argo CD makes — if this works, the generator will work.

```bash
./test-plugin.sh asplugin-argocd-applicationset-json-plugin argocd
```

Expected JSON shape:

```json
{
  "output": {
    "parameters": [
      {"name": "alpha"},
      {"name": "beta"},
      {"name": "gamma"}
    ]
  }
}
```

If you see an `error` field instead, check the plugin logs:

```bash
kubectl -n argocd logs deploy/asplugin-argocd-applicationset-json-plugin
```

Common failure modes:

| Symptom | Likely cause |
|---|---|
| `401 Unauthorized` | Bearer token in your test script doesn't match the Secret. |
| `Failed to fetch URL` | `plugin.url` not reachable from the pod's network namespace. |
| `Parse error` (jq mode) | `plugin.jq.filter` is malformed — test it locally with `jq '<filter>' < data.json`. |
| `JSONPath returned 0 items` | The path doesn't match the JSON structure; double-check with `JSON_PATH='$'` to dump the root. |

## 3. Register the plugin with an ApplicationSet

The chart already produces a ConfigMap formatted for the ApplicationSet plugin generator. Point your `ApplicationSet` at it via `configMapRef.name`:

- [applicationset-jsonpath.yaml](applicationset-jsonpath.yaml) — uses the chart's default JSONPath mode (key extraction + `aliasOf` filter)
- [applicationset-jq.yaml](applicationset-jq.yaml) — uses jq mode for the same source

Apply one:

```bash
kubectl -n argocd apply -f examples/applicationset-jsonpath.yaml
```

Watch Argo CD generate Applications from the plugin's output:

```bash
kubectl -n argocd get applicationset
kubectl -n argocd get applications -l app.kubernetes.io/managed-by=argocd-applicationset
```

Each match returned by the plugin becomes one Application named per the `template.metadata.name` in the ApplicationSet.

## 4. Updating the plugin's filter

The filter is held in `values.yaml` under `plugin.jsonpath.*` / `plugin.jq.filter`. Change it and re-`helm upgrade`:

```bash
helm upgrade asplugin --namespace argocd \
  --reuse-values \
  --set plugin.jsonpath.path='$.items[*]' \
  --set plugin.jsonpath.keysOnly=false \
  .
```

The Deployment is restarted because the env vars on the pod change. Re-run [`./test-plugin.sh`](test-plugin.sh) afterwards to confirm the new filter behaviour before letting Argo CD generate from it.

## 5. Switching modes (jsonpath → jq → dual)

`plugin.mode` chooses which evaluator the plugin starts in. **The image tag must match the mode** — the three variants are separate images.

| Mode | `plugin.mode` | `image.tag` |
|---|---|---|
| JSONPath (default) | `jsonpath` | `jsonpath-<version>` |
| jq | `jq` | `jq-<version>` |
| Dual (both) | `dual` | `dual-<version>` |

```bash
helm upgrade asplugin --namespace argocd \
  --reuse-values \
  --set plugin.mode=dual \
  --set image.tag=dual-1.0.0
```
