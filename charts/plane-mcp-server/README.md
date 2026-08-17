# Plane MCP Server Helm Chart

## Pre-requisite

- A working Kubernetes cluster
- `kubectl` and `helm` on the client system that you will use to install our Helm charts
- [cert-manager](https://cert-manager.io/) installed in the cluster (required when `ingress.ssl.enabled=true`)

## Installing Plane MCP Server

1. Open Terminal or any other command-line app that has access to Kubernetes tools on your local system.

1. Set-up and customization

   For more control over your set-up, extract the Helm chart to access the values file and edit using any editor like Vim or Nano.

   ```bash
   # Extract the Helm chart to access the values file
   helm show values plane-mcp-server --repo https://private-helm.plane.tools > custom-values.yaml
   vi custom-values.yaml
   ```

   > See `Configuration Settings` for more details.

   After saving the `custom-values.yaml` file, continue to be on the same Terminal window as on the previous steps, copy the code below, and paste it on your Terminal screen.

   ```bash
   helm upgrade plane-mcp-server-app plane-mcp-server  \
       --repo https://private-helm.plane.tools \
       --install \
       --create-namespace \
       --namespace plane-mcp-server \
       -f custom-values.yaml \
       --timeout 10m \
       --wait \
       --wait-for-jobs
   ```

## Configuration Settings

### MCP Server Setup

| Setting                      |        Default                | Required | Description                                                                 |
| ---------------------------- | :---------------------------: | :------: | --------------------------------------------------------------------------- |
| services.api.image           | makeplane/plane-mcp-server    |          | MCP Server Docker image name (without tag)                                  |
| services.api.tag             |       v0.3.0                 |          | Docker image tag for the MCP server                                         |
| services.api.replicas        |           1                   |          | Number of MCP Server replicas                                               |
| services.api.memoryLimit     |        1000Mi                 |          | Memory limit for MCP Server pods                                            |
| services.api.cpuLimit        |         500m                  |          | CPU limit for MCP Server pods                                               |
| services.api.memoryRequest   |         50Mi                  |          | Memory request for MCP Server pods                                          |
| services.api.cpuRequest      |         50m                   |          | CPU request for MCP Server pods                                             |

### Plane OAuth Configuration

| Setting                               |   Default   | Required | Description                                                                 |
| ------------------------------------- | :---------: | :------: | --------------------------------------------------------------------------- |
| services.api.plane_oauth.enabled         |    false    |          | Enable Plane OAuth authentication                                           |
| services.api.plane_oauth.client_id       |             |    Yes   | Plane OAuth Client ID for authentication                                    |
| services.api.plane_oauth.client_secret   |             |    Yes   | Plane OAuth Client Secret for authentication                                |
| services.api.plane_oauth.provider_base_url|            |    Yes   | Plane instance base URL for OAuth                                           |
| services.api.plane_base_url              |             |    Yes   | Public base URL of your Plane instance                                      |
| services.api.plane_internal_base_url     |             |          | Internal base URL of your Plane instance (for in-cluster communication)     |
| services.api.path_prefix                 |             |          | HTTP route prefix when mounted behind a proxy. E.g. `/plane` serves `/plane/http/mcp` |

### Valkey Setup

Plane MCP Server uses [Valkey](https://valkey.io) (via the upstream [valkey-helm](https://github.com/valkey-io/valkey-helm) chart) to cache session data. It can be deployed in-cluster or pointed at an external Valkey/Redis instance.

| Setting                               |        Default         | Required | Description                                                                                          |
| ------------------------------------- | :--------------------: | :------: | ---------------------------------------------------------------------------------------------------- |
| services.valkey.local_setup           |          true          |          | Set to `true` to deploy Valkey in-cluster. Set to `false` to use an external Valkey/Redis instance.  |
| services.valkey.remote_host                    |                        |          | Hostname of the external Valkey/Redis instance (used when `services.valkey.local_setup=false`)           |
| services.valkey.remote_port                    |         6379           |          | Port of the external Valkey/Redis instance                                                               |
| services.valkey.remote_password                |                        |          | Password for the external Valkey/Redis instance                                                          |
| services.valkey.remote_ssl                     |         false          |          | Enable TLS for the external Valkey/Redis connection                                                      |
| valkey.nameOverride                   |                        |          | Override the Valkey service name. Defaults to `<release>-valkey`                                     |
| valkey.image.repository               |     valkey/valkey      |          | Valkey Docker image repository                                                                        |
| valkey.image.tag                      |         9.1.1          |          | Valkey Docker image tag                                                                               |
| valkey.dataStorage.enabled            |         true           |          | Enable persistent storage for Valkey data                                                             |
| valkey.dataStorage.className          |                        |          | Kubernetes storage class for the Valkey persistent volume                                             |
| valkey.dataStorage.requestedSize      |         500Mi          |          | Persistent volume size. Unit must be in Mi or Gi                                                      |
| valkey.auth.enabled                   |         true           |          | Enable ACL-based authentication for Valkey                                                            |
| valkey.auth.aclUsers.default.password | pleasechangeme         |    Yes   | Password for the default Valkey user                                                                  |

### Ingress Configuration

| Setting                          |        Default                                                | Required | Description                                                                                                                                                                                                                                                                                                                                                                     |
| -------------------------------- | :-----------------------------------------------------------: | :------: | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ingress.enabled                      |         true                                                  |          | Enable ingress for Plane MCP Server                                                                                                                                                                                                                                                                                                                                             |
| ingress.host                         |  mcp.example.com                                              |    Yes   | Main hostname for Plane MCP Server application                                                                                                                                                                                                                                                                                                                                  |
| ingress.ingressController            |         traefik                                               |          | Ingress controller type. Allowed: `nginx`, `traefik`. When set to `traefik`, a native Traefik `IngressRoute` CRD is rendered.                                                                                                                                                                                                                                                   |
| ingress.traefik.ingressClassName     |         traefik                                               |          | Traefik only. The `ingressClassName` used by cert-manager http01 challenge solvers.                                                                                                                                                                                                                                                                                             |
| ingress.traefik.maxRequestBodyBytes  |         10485760                                              |          | Traefik only. Maximum request body size in bytes enforced via the Traefik `buffering` Middleware. Default is 10 MiB.                                                                                                                                                                                                                                                            |
| ingress.nginx.ingressClassName       |         nginx                                                 |          | nginx only. The `ingressClassName` set on the Kubernetes `Ingress` resource.                                                                                                                                                                                                                                                                                                    |
| ingress.nginx.annotations            | `nginx.ingress.kubernetes.io/proxy-body-size: "10m"`          |          | nginx only. Additional annotations to add to the `Ingress` resource.                                                                                                                                                                                                                                                                                                           |
| ingress.ssl.enabled              |         false                                                 |          | Enable SSL/TLS for ingress                                                                                                                                                                                                                                                                                                                                                      |
| ingress.ssl.issuer               |      cloudflare                                               |          | CertManager configuration allows user to create issuers using `http` or any of the other DNS Providers like `cloudflare`, `digitalocean`, etc. As of now Plane MCP Server supports `http`, `cloudflare`, `digitalocean` |
| ingress.ssl.token                |                                                               |          | To create issuers using DNS challenge, set the issuer api token of dns provider like `cloudflare` or `digitalocean` (not required for http)                                                                                                                                                                                                                                   |
| ingress.ssl.server               | https://acme-v02.api.letsencrypt.org/directory                |          | Issuer creation configuration need the certificate generation authority server url. Default URL is the `Let's Encrypt` server |
| ingress.ssl.email                |  admin@example.com                                         |          | Certificate generation authority needs a valid email id before generating certificate. Required when `ingress.ssl.enabled=true`                                                                                                                                                                                                                                                 |

## Custom Ingress Routes

If you are planning to use 3rd party ingress providers, here is the available route configuration

| Host                    |     Path      | Service                                    | Required |
| ----------------------- | :-----------: | ------------------------------------------ | :------: |
| mcp.example.com         |      /        | <http://<release-name>-api:8211>           |   Yes    |

## Verify

- After install, the MCP Server listens on Service `<release-name>-api` port 8211
- If ingress is enabled, access the application at `https://<host>/` via Ingress
- Check all pods are running: `kubectl get pods -n <namespace>`
- Check services: `kubectl get svc -n <namespace>`

## Troubleshooting

- Ensure `ingress.host` resolves to your ingress controller
- For TLS issues, check cert-manager events and Issuer/Certificate resources in the install namespace
- If using external Valkey/Redis, verify `services.valkey.remote_host` is reachable from the cluster
- Confirm Valkey pod is Ready; caching depends on it
- Ensure all Plane OAuth configuration values are correctly set (client_id, client_secret, provider_base_url)
- For Traefik: ensure Traefik CRDs (`IngressRoute`) are installed in your cluster before deploying
