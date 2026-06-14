# Plane MCP Server Helm Chart

## Pre-requisite

- A working Kubernetes cluster
- `kubectl` and `helm` on the client system that you will use to install our Helm charts

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

### Docker Registry Configuration

| Setting                      |        Default                | Required | Description                                                                 |
| ---------------------------- | :---------------------------: | :------: | --------------------------------------------------------------------------- |
| dockerRegistry.enabled       |         true                  |          | Enable Docker registry authentication for pulling images                    |
| dockerRegistry.loginid       |     planeengineering          |          | Docker registry login ID/username                                           |
| dockerRegistry.password      |                               |          | Docker registry password or token                                           |
| dockerRegistry.default_tag   |        latest                 |          | Default image tag for MCP server image                                      |
| services.api.image           | makeplane/plane-mcp-server    |          | MCP Server Docker image name (without tag)                                  |

### MCP Server Setup

| Setting                      |        Default         | Required | Description                                                                 |
| ---------------------------- | :--------------------: | :------: | --------------------------------------------------------------------------- |
| services.api.replicas        |           1            |          | Number of MCP Server replicas                                               |
| services.api.memoryLimit     |        1000Mi          |          | Memory limit for MCP Server pods                                            |
| services.api.cpuLimit        |         500m           |          | CPU limit for MCP Server pods                                               |
| services.api.memoryRequest   |         50Mi           |          | Memory request for MCP Server pods                                          |
| services.api.cpuRequest      |         50m            |          | CPU request for MCP Server pods                                             |

### Plane OAuth Configuration

| Setting                               |   Default   | Required | Description                                                                 |
| ------------------------------------- | :---------: | :------: | --------------------------------------------------------------------------- |
| services.api.plane_oauth.client_id    |             |    Yes   | Plane OAuth Client ID for authentication                                    |
| services.api.plane_oauth.client_secret|             |    Yes   | Plane OAuth Client Secret for authentication                                |
| services.api.plane_oauth.redirect_uri |             |    Yes   | OAuth redirect URI for callback handling                                    |
| services.api.plane_oauth.base_url     |             |    Yes   | Plane instance base URL for OAuth                                           |

### Redis/Valkey Setup

| Setting                          |              Default              | Required | Description                                                                                                                                                                                                                                                                                                                                                                     |
| -------------------------------- | :-------------------------------: | :------: | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| services.redis.local_setup       |               true                |          | Plane MCP Server uses `redis` to cache session data. This can be hosted within kubernetes as part of helm chart deployment or can be used as hosted service remotely. Set this to `true` when you choose to setup stateful deployment of `redis`. Mark it as `false` when using a remotely hosted database |
| services.redis.image             |    valkey/valkey:7.2.11-alpine    |          | Using this key, user must provide the docker image name to setup the stateful deployment of `redis`. (must be set when `services.redis.local_setup=true`)                                                                                                                                                                                                                        |
| services.redis.volume_size       |              500Mi                |          | While setting up the stateful deployment, while creating the persistent volume, volume allocation size need to be provided. This key helps you set the volume allocation size. Unit of this value must be in Mi (megabyte) or Gi (gigabyte)                                                                                                                                     |
| services.redis.external_redis_url|                                   |          | Users can also decide to use the remote hosted database and link to Plane MCP Server deployment. Ignoring all the above keys, set `services.redis.local_setup` to `false` and set this key with remote connection url                                                                                                 |

### Ingress Configuration

| Setting                          |        Default                                                | Required | Description                                                                                                                                                                                                                                                                                                                                                                     |
| -------------------------------- | :-----------------------------------------------------------: | :------: | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ingress.enabled                  |         true                                                  |          | Enable ingress for Plane MCP Server                                                                                                                                                                                                                                                                                                                                             |
| ingress.host                     |  mcp.example.com                                              |    Yes   | Main hostname for Plane MCP Server application                                                                                                                                                                                                                                                                                                                                  |
| ingress.ingressClass             |         nginx                                                 |    Yes   | Kubernetes cluster setup comes with various options of `ingressClass`. Based on your setup, set this value to the right one (eg. nginx, traefik, etc). Leave it to default in case you are using external ingress provider |
| ingress.ingressAnnotations       | { nginx.ingress.kubernetes.io/proxy-body-size: "10m" }        |          | Ingress controllers comes with various configuration options which can be passed as annotations. Setting this value lets you change the default value to user required |
| ingress.ssl.enabled              |         false                                                 |          | Enable SSL/TLS for ingress                                                                                                                                                                                                                                                                                                                                                      |
| ingress.ssl.issuer               |      cloudflare                                               |          | CertManager configuration allows user to create issuers using `http` or any of the other DNS Providers like `cloudflare`, `digitalocean`, etc. As of now Plane MCP Server supports `http`, `cloudflare`, `digitalocean` |
| ingress.ssl.token                |                                                               |          | To create issuers using DNS challenge, set the issuer api token of dns provider like `cloudflare` or `digitalocean` (not required for http)                                                                                                                                                                                                                                   |
| ingress.ssl.server               | https://acme-v02.api.letsencrypt.org/directory                |          | Issuer creation configuration need the certificate generation authority server url. Default URL is the `Let's Encrypt` server |
| ingress.ssl.email                |  engineering@plane.so                                         |          | Certificate generation authority needs a valid email id before generating certificate. Required when `ingress.ssl.enabled=true`                                                                                                                                                                                                                                                 |

## Custom Ingress Routes

If you are planning to use 3rd party ingress providers, here is the available route configuration

| Host                    |     Path      | Service                                    | Required |
| ----------------------- | :-----------: | ------------------------------------------ | :------: |
| mcp.example.com         |      /        | <http://<release-name>-api:8000>           |   Yes    |

## Verify

- After install, the MCP Server listens on Service `<release-name>-api` port 8000
- If ingress is enabled, access the application at `https://<host>/` via Ingress
- Check all pods are running: `kubectl get pods -n <namespace>`
- Check services: `kubectl get svc -n <namespace>`

## Troubleshooting

- Ensure `ingress.host` resolves to your ingress controller
- For TLS issues, check cert-manager events and Issuer/Certificate resources in the install namespace
- If using external Redis, verify `services.redis.external_redis_url` is reachable from the cluster
- Confirm Redis/Valkey pods are Ready; caching depends on it
- Ensure all Plane OAuth configuration values are correctly set (client_id, client_secret, redirect_uri, base_url)
