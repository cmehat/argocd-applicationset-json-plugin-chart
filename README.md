# argocd-applicationset-json-plugin

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

Helm chart for the [argocd-applicationset-json-plugin](https://github.com/cmehat/argocd-applicationset-json-plugin) — a generic ArgoCD ApplicationSet plugin that fetches JSON from a URL and applies JSONPath or jq filtering.

## Install

```bash
helm install my-plugin . \
  --namespace argocd \
  --set plugin.url=https://example.com/data.json
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
