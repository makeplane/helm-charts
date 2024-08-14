# Plane One Helm Chart

## Pre-requisite

- A Plane One license
  > If you don’t have a license, get it at [prime.plane.so](https://prime.plane.so)
- A working Kubernetes cluster
- `kubectl` and `helm` on the client system that you will use to install our Helm charts

## Installing Plane One

  1. Open Terminal or any other command-line app that has access to Kubernetes tools on your local system.
  2. Set the following environment variables.
  
      Copy the format of constants below, paste it on Terminal to start setting environment variables, set values for each variable, and hit ENTER or RETURN.
      > You will get the values for the variables from [prime.plane.so](https://prime.plane.so) under the Kuberntes tab of your license's details page. When installing Plane One for the first time, remember to specify a domain name.

      ```bash
      LICENSE_KEY=<your_license_key>
      REG_USER_ID=<license-XXXXX+XXXX-XXXX-XXX-XXXXX>
      REG_PASSWORD=<******>
      PLANE_VERSION=<v1.xx.x>
      DOMAIN_NAME=<subdomain.domain.tld or domain.tld>
      ```

  3. Add Plane helm chart repo

      Continue to be on the same Terminal window as with the previous steps, copy the code below, paste it on Terminal, and hit ENTER or RETURN.

      ```bash
      helm repo add plane https://helm.plane.so/
      ```

  4. Set-up and customization
      - Quick set-up

        This is the fastest way to deploy Plane with default settings. This will create stateful deployments for Postgres, Redis, and Minio with a persistent volume claim using the `longhorn` storage class. This also sets up the ingress routes for you using `nginx` ingress class.
        > To customize this, see `Custom ingress routes` below.

        Continue to be on the same Terminal window as you have so far, copy the code below, and paste it on your Terminal screen.

        ```bash
        helm install one-app plane/plane-enterprise \
            --create-namespace \
            --namespace plane-one \
            --set dockerRegistry.loginid=${REG_USER_ID} \
            --set dockerRegistry.password=${REG_PASSWORD} \
            --set license.licenseKey=${LICENSE_KEY} \
            --set license.licenseDomain=${DOMAIN_NAME} \
            --set license.licenseServer=https://prime.plane.so \
            --set planeVersion=${PLANE_VERSION} \
            --set ingress.ingressClass=nginx \
            --set env.storageClass=longhorn \
            --timeout 10m \
            --wait \
            --wait-for-jobs
        ```

        > This is the minimum required to set up Plane One. You can change the default namespace from `plane-one`, the default appname
        from `one-app`, the default storage class from `env.storageClass`, and the default ingress class from `ingress.ingressClass` to 
        whatever you would like to.<br> <br>
        You can also pass other settings referring to `Configuration Settings` section.

      - Advance set-up

          For more control over your set-up, run the script below to download the `values.yaml` file and and edit using any editor like Vim or Nano. 

          ```bash
          helm  show values plane/plane-enterprise > values.yaml
          vi values.yaml
          ```

          Make sure you set the minimum required values as below.
          - `planeVersion: <v1.xx.x>`
          - `dockerRegistry.loginid: <REG_USER_ID as on prime.plane.so>`
          - `dockerRegistry.password: <REG_PASSWORD as on prime.plane.so>`
          - `license.licenseKey: <LICENSE_KEY as on prime.plane.so>`
          - `license.licenseDomain: <The domain you have specified to host Plane>`
          - `license.licenseServer: https://prime.plane.so`
          - `ingress.ingressClass: <nginx or any other ingress class configured in your cluster>`
          - `env.storageClass: <longhorn or any other storage class configured in your cluster>`

            > See `Available customizations` for more details.

          After saving the `values.yaml` file, continue to be on the same Terminal window as on the previous steps, copy the code below, and paste it on your Terminal screen.

          ```bash
          helm install one-app plane/plane-enterprise \
              --create-namespace \
              --namespace plane-one \
              -f values.yaml \
              --timeout 10m \
              --wait \
              --wait-for-jobs 
          ```

## Available customizations

### Docker registry

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| dockerRegistry.enabled | true | Yes | Plane uses a private Docker registry which needs authenticated login. This must be set to `true` to install Plane One. |
| dockerRegistry.registry |  registry.plane.tools| Yes | The host that will serve the required Docker images; Don't change this. |
| dockerRegistry.loginid |  | Yes | Sets the `loginid` for the Docker registry. This is the same as the REG_USER_ID value on prime. plane.so |
| dockerRegistry.password |  | Yes | Sets the `password` for the Docker registry. This is the same as the REG_PASSWORD value on prime.plane.so|
  
### License

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| planeVersion | v1.1.1 | Yes |  Specifies the version of Plane to be deployed. Copy this from prime.plane.so. |
| license.licenseServer | <https://prime.plane.so> | Yes | Sets the value of the `licenseServer` that gets you your license and validates it periodically. Don't change this. |
| license.licenseKey |  | Yes | Holds your license key to Plane One. Copy this from prime.plane.so. |
| license.licenseDomain | 'plane.example.com' | Yes | The fully-qualified domain name (FQDN) in the format `sudomain.domain.tld` or `domain.tld` that the license is bound to. It is also attached to your `ingress` host to access Plane. |

### Postgres

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.postgres.local_setup | true |  | Plane uses `postgres` as the primary database to store all the transactional data. This database can be hosted within kubernetes as part of helm chart deployment or can be used as hosted service remotely (e.g. aws rds or similar services). Set this to  `true` when you choose to setup stateful deployment of `postgres`. Mark it as `false` when using a remotely hosted database |
| services.postgres.image | registry.plane.tools/plane/postgres:15.5-alpine |  | Using this key, user must provide the docker image name to setup the stateful deployment of `postgres`. (must be set when `services.postgres.local_setup=true`)|
| services.postgres.servicePort | 5432 |  | This key sets the default port number to be used while setting up stateful deployment of `postgres`. |
| services.postgres.cliConnectPort |  | | If you intend to access the hosted stateful deployment of postgres using any of the client tools (e.g Postico), this key helps you expose the port. The mentioned port must not be occupied by any other applicaiton|
| services.postgres.volumeSize | 2Gi |  | While setting up the stateful deployment, while creating the persistant volume, volume allocation size need to be provided. This key helps you set the volume allocation size. Unit of this value must be in Mi (megabyte) or Gi (gigabyte) |
| env.pgdb_username | plane |  | Database credentials are requried to access the hosted stateful deployment of `postgres`.  Use this key to set the username for the stateful deployment. |
| env.pgdb_password | plane |  | Database credentials are requried to access the hosted stateful deployment of `postgres`.  Use this key to set the password for the stateful deployment. |
| env.pgdb_name | plane |  |  Database name to be used while setting up stateful deployment of `Postgres`|
| env.pgdb_remote_url |  |  | Users can also decide to use the remote hosted database and link to Plane deployment. Ignoring all the above keys, set `services.postgres.local_setup` to `false` and set this key with remote connection url. |

### Redis Setup

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.redis.local_setup | true |  | Plane uses `redis` to cache the session authentication and other static data. This database can be hosted within kubernetes as part of helm chart deployment or can be used as hosted service remotely (e.g. aws rds or similar services). Set this to  `true` when you choose to setup stateful deployment of `redis`. Mark it as `false` when using a remotely hosted database |
| services.redis.image | registry.plane.tools/plane/valkey:7.2.5-alpine |  | Using this key, user must provide the docker image name to setup the stateful deployment of `redis`. (must be set when `services.redis.local_setup=true`)|
| services.redis.servicePort | 6379 |  | This key sets the default port number to be used while setting up stateful deployment of `redis`. |
| services.redis.volumeSize | 500Mi |  | While setting up the stateful deployment, while creating the persistant volume, volume allocation size need to be provided. This key helps you set the volume allocation size. Unit of this value must be in Mi (megabyte) or Gi (gigabyte) |
| env.remote_redis_url |  |  | Users can also decide to use the remote hosted database and link to Plane deployment. Ignoring all the above keys, set `services.redis.local_setup` to `false` and set this key with remote connection url. |

### Doc Store (Minio/S3) Setup

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.minio.local_setup | true |  | Plane uses `minio` as the default file storage drive. This storage can be hosted within kubernetes as part of helm chart deployment or can be used as hosted service remotely (e.g. aws S3 or similar services). Set this to  `true` when you choose to setup stateful deployment of `minio`. Mark it as `false` when using a remotely hosted database |
| services.minio.image | registry.plane.tools/plane/minio:latest |  | Using this key, user must provide the docker image name to setup the stateful deployment of `minio`. (must be set when `services.minio.local_setup=true`)|
| services.minio.volumeSize | 3Gi |  | While setting up the stateful deployment, while creating the persistant volume, volume allocation size need to be provided. This key helps you set the volume allocation size. Unit of this value must be in Mi (megabyte) or Gi (gigabyte) |
| services.minio.root_user | admin |  |  Storage credentials are requried to access the hosted stateful deployment of `minio`.  Use this key to set the username for the stateful deployment. |
| services.minio.root_password | password |  | Storage credentials are requried to access the hosted stateful deployment of `minio`.  Use this key to set the password for the stateful deployment. |
| env.docstore_bucket | uploads | Yes | Storage bucket name is required as part of configuration. This is where files will be uploaded irrespective of if you are using `Minio` or external `S3` (or compatible) storage service |
| env.doc_upload_size_limit | 5242880 | Yes | Document Upload Size Limit (default to 5Mb) |
| env.aws_access_key |  |  | External `S3` (or compatible) storage service provides `access key` for the application to connect and do the necessary upload/download operations. To be provided when `services.minio.local_setup=false`  |
| env.aws_secret_access_key |  |  | External `S3` (or compatible) storage service provides `secret access key` for the application to connect and do the necessary upload/download operations. To be provided when `services.minio.local_setup=false`  |
| env.aws_region |  |  | External `S3` (or compatible) storage service providers creates any buckets in user selected region. This is also shared with the user as `region` for the application to connect and do the necessary upload/download operations. To be provided when `services.minio.local_setup=false`  |
| env.aws_s3_endpoint_url |  |  | External `S3` (or compatible) storage service providers shares a `endpoint_url` for the integration purpose for the application to connect and do the necessary upload/download operations. To be provided when `services.minio.local_setup=false`  |

### Web Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.web.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| services.web.memoryLimit | 1000Mi |  | Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| services.web.cpuLimit | 500m |  |  Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| services.web.image| registry.plane.tools/plane/web-enterprise |  |  This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |

### Space Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.space.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| services.space.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| services.space.cpuLimit | 500m |  | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| services.space.image| registry.plane.tools/plane/space-enterprise |  |  This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |

### Admin Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.admin.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| services.admin.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| services.admin.cpuLimit | 500m |  |  Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| services.admin.image| registry.plane.tools/plane/admin-enterprise |  |  This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |

### API Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.api.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| services.api.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| services.api.cpuLimit | 500m |  | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| services.api.image| registry.plane.tools/plane/backend-enterprise |  | This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |
| env.sentry_dsn |  |  | (optional) API service deployment comes with some of the preconfigured integration. Sentry is one among those. Here user can set the Sentry provided DSN for this integration.|
| env.sentry_environment |  |  | (optional) API service deployment comes with some of the preconfigured integration. Sentry is one among those. Here user can set the Sentry environment name (as configured in Sentry) for this integration.|
  
### Worker Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.worker.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| services.worker.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| services.worker.cpuLimit | 500m |  | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|

### Beat-Worker deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.beatworker.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| services.beatworker.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| services.beatworker.cpuLimit | 500m |  | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
  
### Ingress and SSL Setup

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| ingress.enabled | true |  | Ingress setup in kubernetes is a common practice to expose application to the intended audience.  Set it to `false` if you are using external ingress providers like `Cloudflare` |
| ingress.minioHost | 'plane-services.minio.example.com' |  | Based on above configuration, if you want to expose the `minio` web console to set of users, use this key to set the `host` mapping or leave it as `EMPTY` to not expose interface. |
| ingress.ingressClass | 'nginx' | Yes | Kubernetes cluster setup comes with various options of `ingressClass`. Based on your setup, set this value to the right one (eg. nginx, traefik, etc). Leave it to default in case you are using external ingress provider.|
| ingress.ingress_annotations | `{ "nginx.ingress.kubernetes.io/proxy-body-size": "5m" }` |  | Ingress controllers comes with various configuration options which can be passed as annotations. Setting this value lets you change the default value to user required. |
| ssl.createIssuer | false |  | Kubernets cluster setup supports creating `issuer` type resource. After deployment, this is step towards creating secure access to the ingress url. Issuer is required for you generate SSL certifiate. Kubernetes can be configured to use any of the certificate authority to generate SSL (depending on CertManager configuration). Set it to `true` to create the issuer. Applicable only when `ingress.enabled=true`|
| ssl.issuer | http |  | CertManager configuration allows user to create issuers using `http` or any of the other DNS Providers like `cloudflare`, `digitalocean`, etc. As of now Plane supports `http`, `cloudflare`, `digitalocean`|
| ssl.token |  |  | To create issuers using DNS challenge, set the issuer api token of dns provider like cloudflare` or `digitalocean`(not required for http) |
| ssl.server | <https://acme-v02.api.letsencrypt.org/directory> |  | Issuer creation configuration need the certificate generation authority server url. Default URL is the `Let's Encrypt` server|
| ssl.email | <plane@example.com> |  | Certificate generation authority needs a valid email id before generating certificate. Required when `ssl.createIssuer=true`  |
| ssl.generateCerts | false |  | After creating the issuers, user can still not create the certificate untill sure of configuration. Setting this to `true` will try to generate SSL certificate and associate with ingress. Applicable only when `ingress.enabled=true` and `ssl.createIssuer=true` |

### Common Environment Settings

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| env.storageClass | longhorn |  | Creating the persitant volumes for the stateful deployments needs the `storageClass` name. Set the correct value as per your kubernetes cluster configuration. |
| env.secret_key | 60gp0byfz2dvffa45cxl20p1scy9xbpf6d8c5y0geejgkyp1b5 | Yes | This must a random string which is used for hashing/encrypting the sensitive data within the application. Once set, changing this might impact the already hashed/encrypted data|
  
## Custom Ingress Routes

If you are planning to use 3rd party ingress providers, here is the available route configuration

| Host | Path | Service |
|---    |:---:|---|
| plane.example.com | /  | <http://plane-web.plane-one:3000> |
| plane.example.com | /spaces/*  | <http://plane-space.plane-one:3000> |
| plane.example.com | /god-mode/* | <http://plane-admin.plane-one:3000> |
| plane.example.com | /api/*  |  <http://plane-api.plane-one:8000> |
| plane.example.com | /auth/* | <http://plane-api.plane-one:8000> |
| plane.example.com | /uploads/* | <http://plane-minio.plane-one:9000> |
| plane-minio.example.com | / | <http://plane-minio.plane-one:9090> |
