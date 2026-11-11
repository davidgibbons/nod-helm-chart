# nod-helm-chart

Helm chart for running [Nod](https://github.com/n8n-io/nod), n8n's self-hosted personal agent, on Kubernetes. It follows Nod's [Docker Compose self-host setup](https://nod.n8n.io/docs/deploy/self-host/), with each Compose service as a pod.

Upstream publishes no container images, so this repo's CI builds them from the release tag `nod-v<appVersion>` and pushes them to `ghcr.io/davidgibbons/nod-{server,workspace,browser}`.

## Install

```sh
helm install nod oci://ghcr.io/davidgibbons/charts/nod \
  --namespace nod --create-namespace \
  --set publicUrl=https://nod.example.com \
  --set ingress.enabled=true --set ingress.host=nod.example.com
kubectl label namespace nod pod-security.kubernetes.io/enforce=privileged
```

Then follow the printed notes to read the server token.

Requirements:

- **A privileged namespace.** The workspace firewall sidecar needs `NET_ADMIN`, which the `baseline` Pod Security level rejects.
- **One release per namespace.** The server finds its workspace and browser by the fixed pod names `nod-workspace-0` and `nod-browser-0`.
- **A NetworkPolicy-enforcing CNI**, to keep the browser off private addresses.

## Secrets

With `existingSecret` empty, the chart generates the `nod` Secret on first install and keeps it on upgrade and uninstall. This needs Helm's `lookup`, so ArgoCD and other tools that render with `helm template` must set `existingSecret` to a Secret with these keys:

| Key | Format |
| --- | --- |
| `NOD_AUTH_TOKEN` | At least 43 characters from `A-Z a-z 0-9 _ -`. Users sign in with it. |
| `NOD_VAULT_KEY` | 32 random bytes, base64: `openssl rand -base64 32`. |
| `NOD_POSTGRES_PASSWORD` | Password for the bundled PostgreSQL. Not needed with `externalDatabase`. |

Back up `NOD_VAULT_KEY` off the cluster. Without it, saved credentials cannot be decrypted, and the database backup alone cannot recover them.

## External PostgreSQL

Point `externalDatabase.secretName` at a Secret holding a `postgresql://` URL, and the chart skips its bundled PostgreSQL. For a Crunchy PGO cluster, which accepts TLS connections only:

```yaml
externalDatabase:
  secretName: nod-postgres-pguser-nod
  key: uri
  query: sslmode=require&uselibpqcompat=true
```

Nod's `pg` client treats `sslmode=require` as `verify-full`. `uselibpqcompat=true` restores the libpq meaning: encrypt, without verifying the certificate.

## How it differs from Compose

| Compose | This chart |
| --- | --- |
| `runtime` proxies a narrow subset of the Docker API to the host socket. | The server image replaces the `docker` CLI with [a shim](images/server/docker) that runs the same `docker exec` calls as `kubectl exec`. A Role limits the server to exec on the two sandbox pods. |
| `docker exec --user` picks each command's uid. | Kubernetes exec cannot pick a user, so the workspace container runs as root with only `SETUID`/`SETGID`, and the shim drops to the requested uid with `setpriv`. |
| `workspace-network` shares its network namespace with the workspace. | The same image and script run as a native sidecar in the workspace pod. |
| Named volume `workspace-data` is shared by the server and workspace. | A `ReadWriteOnce` PVC, with pod affinity keeping both pods on one node. |
| The `browser` network reaches the host's LAN. | A NetworkPolicy limits the browser and workspace to DNS and public addresses. |
| Caddy `https` profile. | Not included; use `ingress`. |

## Values

See [`values.yaml`](charts/nod/values.yaml). `publicUrl` is required, and must match the origin users browse to.

## Releasing

Bump `appVersion` in `charts/nod/Chart.yaml` to a Nod release, and bump `version` for chart changes. Each push to `main` rebuilds the images and pushes the chart.

Check the shim after changing it:

```sh
sh images/server/test.sh
```
