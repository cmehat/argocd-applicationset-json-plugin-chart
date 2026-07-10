# argocd-applicationset-json-plugin

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

Helm chart for the [argocd-applicationset-json-plugin](https://github.com/cmehat/argocd-applicationset-json-plugin) — a generic ArgoCD ApplicationSet plugin that fetches JSON from a URL and applies JSONPath or jq filtering.

## Install

```bash
helm install my-plugin . \
  --namespace argocd \
  --set plugin.url=https://example.com/data.json
```

## End-to-end example

See [`examples/`](examples/) for a battle-tested walkthrough that:

- installs the chart,
- verifies the plugin responds to the same call ArgoCD makes (see [`examples/test-plugin.sh`](examples/test-plugin.sh)),
- wires it up as an ApplicationSet generator ([`examples/applicationset-jsonpath.yaml`](examples/applicationset-jsonpath.yaml), [`examples/applicationset-jq.yaml`](examples/applicationset-jq.yaml)).

## Deploying with ArgoCD — required topology & gotchas

This chart deploys the *backend* that an ArgoCD ApplicationSet **plugin generator**
calls. Three things must be right, or generation fails silently:

### 1. Install on the cluster/namespace that runs the ApplicationSet controller

A plugin generator (`generators[].plugin.configMapRef`) is resolved by the
`argocd-applicationset-controller` **in its own namespace**, and the controller
reaches the plugin over the in-cluster network at
`http://<release>.<namespace>.svc.cluster.local:<service.port>`.

So install this chart into the **same cluster and namespace as the ApplicationSet
controller** (typically `argocd`). Installing it on a *workload* cluster — even the
one your generated Applications target — makes the controller fail every reconcile:

```
error getting plugin from generator: error fetching ConfigMap "<release>" not found
```

Where the generated Applications *deploy* is independent of this: that is decided
by the consumer ApplicationSet's own generators/template, not by where the plugin
backend runs.

### 2. Probes are `tcpSocket`, not `httpGet`

The plugin's only route, `POST /api/v1/getparams.execute`, is POST-only and
token-authenticated — a `GET` returns `501`. The chart's liveness/readiness/startup
probes therefore use `tcpSocket` against the listening port. **Do not** point an
`httpGet` probe at that path: the kubelet fails the liveness check and crash-loops
the pod (`exitCode 137`).

### 3. `image.tag` must be a tag that CI actually published

Image tags are variant-prefixed semver built by the plugin repo's CI
(`jsonpath-1.0.0`, `jq-1.0.0`, `dual-1.0.0`, plus `<variant>-latest`). Pinning a tag
that was never built yields `ImagePullBackOff`. See the plugin repo's `AGENTS.md`
for the release/tag scheme.

The ConfigMap this chart renders already advertises the correct `baseUrl` (including
the Service port) and token; reference it from your ApplicationSet as:

```yaml
generators:
  - plugin:
      configMapRef:
        name: <release-name>   # this chart's fullname
      input:
        parameters: {}
      requeueAfterSeconds: 300
```

## Plugin modes

`plugin.mode` selects which evaluator to enable: `jsonpath` (default), `jq`, or `dual`. The image tag in `image.tag` should match (`jsonpath-1.0.0`, `jq-1.0.0`, or `dual-1.0.0`).

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| externalSecrets.enabled | bool | `false` | Enable External Secrets integration (if false, uses inline values below) |
| externalSecrets.secretStore.kind | string | `"ClusterSecretStore"` | Kind of secret store (ClusterSecretStore or SecretStore) |
| externalSecrets.secretStore.name | string | `"gcp-secrets"` | Name of the secret store |
| externalSecrets.tokenSecretKey | string | `"argocd-applicationset-json-plugin-token"` | Secret key in the external secret store containing the plugin token |
| fullNameOverride | string | `""` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"ghcr.io/cmehat/argocd-applicationset-json-plugin"` |  |
| image.tag | string | `"jsonpath-1.0.0"` | Image tag. Use variant prefix for specific variants: `jsonpath-1.0.0`, `jq-1.0.0`, `dual-1.0.0`. |
| livenessProbe.enabled | bool | `true` |  |
| livenessProbe.failureThreshold | int | `3` |  |
| livenessProbe.initialDelaySeconds | int | `5` |  |
| livenessProbe.periodSeconds | int | `30` |  |
| nameOverride | string | `""` |  |
| plugin.dual.filterType | string | `"auto"` | Dual mode filter selection: `auto`, `jq`, or `jsonpath` |
| plugin.jq.filter | string | `'to_entries \| map(select(.value.aliasOf == null) \| {name: .key})'` | jq filter expression |
| plugin.jsonpath.excludeIfExists | string | `"aliasOf"` | Exclude objects where this field exists |
| plugin.jsonpath.keyField | string | `"name"` | Field name for extracted keys |
| plugin.jsonpath.keysOnly | bool | `true` | Return only `{keyField: "key"}` instead of full objects |
| plugin.jsonpath.path | string | `"$.*"` | JSONPath expression to filter data |
| plugin.mode | string | `"jsonpath"` | Plugin mode: `jsonpath`, `jq`, or `dual` |
| plugin.requeueAfterSeconds | int | `300` | Requeue interval in seconds for ArgoCD ApplicationSet |
| plugin.url | string | `"https://example.com/data.json"` | URL to fetch JSON data from |
| readinessProbe.enabled | bool | `true` |  |
| readinessProbe.failureThreshold | int | `3` |  |
| readinessProbe.initialDelaySeconds | int | `5` |  |
| readinessProbe.periodSeconds | int | `10` |  |
| replicaCount | int | `1` |  |
| resources.limits.cpu | string | `"200m"` |  |
| resources.limits.memory | string | `"128Mi"` |  |
| resources.requests.cpu | string | `"100m"` |  |
| resources.requests.memory | string | `"64Mi"` |  |
| secrets.existingSecret | string | `""` | Name of an existing secret to use for the token (if set, no secret will be created) |
| secrets.existingSecretKey | string | `""` | Key in the existing secret that contains the token value (defaults to `token`) |
| secrets.inline.token | string | `"argocd-applicationset-plugin-token"` | Inline token value used when no existing/external secret is configured. Change for production. |
| service.port | int | `4355` |  |
| service.targetPort | int | `4355` |  |
| service.type | string | `"ClusterIP"` |  |
| startupProbe.enabled | bool | `true` |  |
| startupProbe.failureThreshold | int | `30` |  |
| startupProbe.initialDelaySeconds | int | `0` |  |
| startupProbe.periodSeconds | int | `5` |  |

## License

MIT
