## Pre-requisite

- A working Kubernetes cluster
- `kubectl` and `helm` on the client system that you will use to install our Helm charts

## Installing Plane

  1. Open Terminal or any other command-line app that has access to Kubernetes tools on your local system.
  2. Set the following environment variables.
  
      Copy the format of constants below, paste it on Terminal to start setting environment variables, set values for each variable, and hit ENTER or RETURN.

      ```bash
      PLANE_VERSION=v1.5.1 # or the last released version
      DOMAIN_NAME=<subdomain.domain.tld or domain.tld>
      ```

  3. Add Plane helm chart repo

      Continue to be on the same Terminal window as with the previous steps, copy the code below, paste it on Terminal, and hit ENTER or RETURN.

      ```bash
      helm repo add plane https://helm.plane.so/
      ```

  4. Set-up and customization
      - Quick set-up

        This is the fastest way to deploy Plane with default settings. This will create stateful deployments for Postgres, Rabbitmq, Redis/Valkey, and Minio with a persistent volume claim using the default storage class.This also sets up the ingress routes for you using `nginx` ingress class.
        > To customize this, see `Custom ingress routes` below.

        Continue to be on the same Terminal window as you have so far, copy the code below, and paste it on your Terminal screen.

        ```bash
        helm install plane-app plane/plane-enterprise \
            --create-namespace \
            --namespace plane \
            --set license.licenseDomain=${DOMAIN_NAME} \
            --set planeVersion=${PLANE_VERSION} \
            --set ingress.enabled=true \
            --set ingress.ingressClass=nginx \
            --timeout 10m \
            --wait \
            --wait-for-jobs
        ```

        > This is the basic setup required for Plane-EE. You can customize the default values for namespace and appname as needed. Additional settings can be configured by referring to the Configuration Settings section.<br>

        **Using a Custom StorageClass**

        To specify a custom StorageClass for Plane-Enterprise components, add the following options to the above `helm upgrade --install` command:
        ```bash
        --set env.storageClass=<your-storageclass-name>
        ```

        

      - Advance set-up

          For more control over your set-up, run the script below to download the `values.yaml` file and and edit using any editor like Vim or Nano. 

          ```bash
          helm  show values plane/plane-enterprise > values.yaml
          vi values.yaml
          ```

          Make sure you set the minimum required values as below.
          - `planeVersion: v1.5.1 <or the last released version>`
          - `license.licenseDomain: <The domain you have specified to host Plane>`
          - `ingress.enabled: <true | false>`
          - `ingress.ingressClass: <nginx or any other ingress class configured in your cluster>`
          - `env.storageClass: <default storage class configured in your cluster>`

            > See `Available customizations` for more details.

          After saving the `values.yaml` file, continue to be on the same Terminal window as on the previous steps, copy the code below, and paste it on your Terminal screen.

          ```bash
          helm install plane-app plane/plane-enterprise \
              --create-namespace \
              --namespace plane \
              -f values.yaml \
              --timeout 10m \
              --wait \
              --wait-for-jobs 
          ```

## Available customizations

<!-- ### Docker registry

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| dockerRegistry.enabled | false |  | Plane uses a private Docker registry which needs authenticated login. This must be set to `true` to install Plane Enterprise. |
| dockerRegistry.registry |  registry.plane.tools| Yes | The host that will serve the required Docker images; Don't change this. |
| dockerRegistry.loginid |  | Yes | Sets the `loginid` for the Docker registry. This is the same as the REG_USER_ID value on prime. plane.so |
| dockerRegistry.password |  | Yes | Sets the `password` for the Docker registry. This is the same as the REG_PASSWORD value on prime.plane.so|
   -->
### License

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| planeVersion | v1.5.1 | Yes |  Specifies the version of Plane to be deployed. Copy this from prime.plane.so. |
| license.licenseDomain | plane.example.com | Yes | The fully-qualified domain name (FQDN) in the format `sudomain.domain.tld` or `domain.tld` that the license is bound to. It is also attached to your `ingress` host to access Plane. |

### Postgres

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.postgres.local_setup | true |  | Plane uses `postgres` as the primary database to store all the transactional data. This database can be hosted within kubernetes as part of helm chart deployment or can be used as hosted service remotely (e.g. aws rds or similar services). Set this to  `true` when you choose to setup stateful deployment of `postgres`. Mark it as `false` when using a remotely hosted database |
| services.postgres.image | registry.plane.tools/plane/postgres:15.7-alpine |  | Using this key, user must provide the docker image name to setup the stateful deployment of `postgres`. (must be set when `services.postgres.local_setup=true`)|
| services.postgres.pullPolicy | IfNotPresent |  | Using this key, user can set the pull policy for the stateful deployment of `postgres`. (must be set when `services.postgres.local_setup=true`)|
| services.postgres.servicePort | 5432 |  | This key sets the default port number to be used while setting up stateful deployment of `postgres`. |
| services.postgres.volumeSize | 2Gi |  | While setting up the stateful deployment, while creating the persistant volume, volume allocation size need to be provided. This key helps you set the volume allocation size. Unit of this value must be in Mi (megabyte) or Gi (gigabyte) |
| env.pgdb_username | plane |  | Database credentials are requried to access the hosted stateful deployment of `postgres`.  Use this key to set the username for the stateful deployment. |
| env.pgdb_password | plane |  | Database credentials are requried to access the hosted stateful deployment of `postgres`.  Use this key to set the password for the stateful deployment. |
| env.pgdb_name | plane |  |  Database name to be used while setting up stateful deployment of `Postgres`|
| services.postgres.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |
| env.pgdb_remote_url |  |  | Users can also decide to use the remote hosted database and link to Plane deployment. Ignoring all the above keys, set `services.postgres.local_setup` to `false` and set this key with remote connection url. |

### Redis/Valkey Setup

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.redis.local_setup | true |  | Plane uses `valkey` to cache the session authentication and other static data. This database can be hosted within kubernetes as part of helm chart deployment or can be used as hosted service remotely (e.g. aws rds or similar services). Set this to  `true` when you choose to setup stateful deployment of `redis`. Mark it as `false` when using a remotely hosted database |
| services.redis.image | registry.plane.tools/plane/valkey:7.2.5-alpine |  | Using this key, user must provide the docker image name to setup the stateful deployment of `redis`. (must be set when `services.redis.local_setup=true`)|
| services.redis.pullPolicy | IfNotPresent |  | Using this key, user can set the pull policy for the stateful deployment of `redis`. (must be set when `services.redis.local_setup=true`)|
| services.redis.servicePort | 6379 |  | This key sets the default port number to be used while setting up stateful deployment of `redis`. |
| services.redis.volumeSize | 500Mi |  | While setting up the stateful deployment, while creating the persistant volume, volume allocation size need to be provided. This key helps you set the volume allocation size. Unit of this value must be in Mi (megabyte) or Gi (gigabyte) |
| services.redis.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |
| env.remote_redis_url |  |  | Users can also decide to use the remote hosted database and link to Plane deployment. Ignoring all the above keys, set `services.redis.local_setup` to `false` and set this key with remote connection url. |

### RabbitMQ Setup

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.rabbitmq.local_setup | true |  | Plane uses `rabbitmq` as message queuing system. This can be hosted within kubernetes as part of helm chart deployment or can be used as hosted service remotely (e.g. aws mq or similar services). Set this to  `true` when you choose to setup stateful deployment of `rabbitmq`. Mark it as `false` when using a remotely hosted service |
| services.rabbitmq.image | rabbitmq:3.13.6-management-alpine |  | Using this key, user must provide the docker image name to setup the stateful deployment of `rabbitmq`. (must be set when `services.rabbitmq.local_setup=true`)|
| services.rabbitmq.pullPolicy | IfNotPresent |  | Using this key, user can set the pull policy for the stateful deployment of `rabbitmq`. (must be set when `services.rabbitmq.local_setup=true`)|
| services.rabbitmq.servicePort | 5672 |  | This key sets the default port number to be used while setting up stateful deployment of `rabbitmq`. |
| services.rabbitmq.managementPort | 15672 |  | This key sets the default management port number to be used while setting up stateful deployment of `rabbitmq`. |
| services.rabbitmq.volumeSize | 100Mi |  | While setting up the stateful deployment, while creating the persistant volume, volume allocation size need to be provided. This key helps you set the volume allocation size. Unit of this value must be in Mi (megabyte) or Gi (gigabyte) |
| services.rabbitmq.default_user | plane |  | Credentials are requried to access the hosted stateful deployment of `rabbitmq`.  Use this key to set the username for the stateful deployment. |
| services.rabbitmq.default_password | plane |  | Credentials are requried to access the hosted stateful deployment of `rabbitmq`.  Use this key to set the password for the stateful deployment. |
| services.rabbitmq.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |
| services.rabbitmq.external_rabbitmq_url |  |  | Users can also decide to use the remote hosted service and link to Plane deployment. Ignoring all the above keys, set `services.rabbitmq.local_setup` to `false` and set this key with remote connection url. |

### Doc Store (Minio/S3) Setup

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.minio.local_setup | true |  | Plane uses `minio` as the default file storage drive. This storage can be hosted within kubernetes as part of helm chart deployment or can be used as hosted service remotely (e.g. aws S3 or similar services). Set this to  `true` when you choose to setup stateful deployment of `minio`. Mark it as `false` when using a remotely hosted database |
| services.minio.image | registry.plane.tools/plane/minio:latest |  | Using this key, user must provide the docker image name to setup the stateful deployment of `minio`. (must be set when `services.minio.local_setup=true`)|
| services.minio.image_mc | minio/mc:latest |  | Using this key, user must provide the docker image name to setup the job deployment of `minio client`. (must be set when `services.minio.local_setup=true`)|
| services.minio.pullPolicy | IfNotPresent |  | Using this key, user can set the pull policy for the stateful deployment of `minio`. (must be set when `services.minio.local_setup=true`)|
| services.minio.volumeSize | 3Gi |  | While setting up the stateful deployment, while creating the persistant volume, volume allocation size need to be provided. This key helps you set the volume allocation size. Unit of this value must be in Mi (megabyte) or Gi (gigabyte) |
| services.minio.root_user | admin |  |  Storage credentials are requried to access the hosted stateful deployment of `minio`.  Use this key to set the username for the stateful deployment. |
| services.minio.root_password | password |  | Storage credentials are requried to access the hosted stateful deployment of `minio`.  Use this key to set the password for the stateful deployment. |
| env.docstore_bucket | uploads | Yes | Storage bucket name is required as part of configuration. This is where files will be uploaded irrespective of if you are using `Minio` or external `S3` (or compatible) storage service |
| env.doc_upload_size_limit | 5242880 | Yes | Document Upload Size Limit (default to 5Mb) |
| services.minio.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |
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
| services.web.pullPolicy | Always |  | Using this key, user can set the pull policy for the deployment of `web`. |
| services.web.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |

### Space Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.space.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| services.space.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| services.space.cpuLimit | 500m |  | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| services.space.image| registry.plane.tools/plane/space-enterprise |  |  This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |
| services.space.pullPolicy | Always |  | Using this key, user can set the pull policy for the deployment of `space`. |
| services.space.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |

### Admin Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.admin.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| services.admin.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| services.admin.cpuLimit | 500m |  |  Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| services.admin.image| registry.plane.tools/plane/admin-enterprise |  |  This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |
| services.admin.pullPolicy | Always |  | Using this key, user can set the pull policy for the deployment of `admin`. |
| services.admin.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |

### Live Service Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.live.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| services.live.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| services.live.cpuLimit | 500m |  |  Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| services.live.image| registry.plane.tools/plane/live-enterprise |  |  This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |
| services.live.pullPolicy | Always |  | Using this key, user can set the pull policy for the deployment of `live`. |
| env.live_sentry_dsn |  |  | (optional) Live service deployment comes with some of the preconfigured integration. Sentry is one among those. Here user can set the Sentry provided DSN for this integration.|
| env.live_sentry_environment |  |  | (optional) Live service deployment comes with some of the preconfigured integration. Sentry is one among those. Here user can set the Sentry environment name (as configured in Sentry) for this integration.|
| env.live_sentry_traces_sample_rate |  |  | (optional) Live service deployment comes with some of the preconfigured integration. Sentry is one among those. Here user can set the Sentry trace sample rate (as configured in Sentry) for this integration.|
| services.live.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |

### Monitor Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.monitor.memoryLimit | 1000Mi |  | Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| services.monitor.cpuLimit | 500m |  |  Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| services.monitor.image| registry.plane.tools/plane/monitor-enterprise |  |  This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |
| services.monitor.pullPolicy | Always |  | Using this key, user can set the pull policy for the deployment of `monitor`. |
| services.monitor.volumeSize | 100Mi |  | While setting up the stateful deployment, while creating the persistant volume, volume allocation size need to be provided. This key helps you set the volume allocation size. Unit of this value must be in Mi (megabyte) or Gi (gigabyte) |
| services.monitor.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |

### API Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.api.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| services.api.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| services.api.cpuLimit | 500m |  | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| services.api.image| registry.plane.tools/plane/backend-enterprise |  | This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |
| services.api.pullPolicy | Always |  | Using this key, user can set the pull policy for the deployment of `api`. |
| env.sentry_dsn |  |  | (optional) API service deployment comes with some of the preconfigured integration. Sentry is one among those. Here user can set the Sentry provided DSN for this integration.|
| env.sentry_environment |  |  | (optional) API service deployment comes with some of the preconfigured integration. Sentry is one among those. Here user can set the Sentry environment name (as configured in Sentry) for this integration.|
| services.api.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |
  
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
| ingress.minioHost |  |  | Based on above configuration, if you want to expose the `minio` web console to set of users, use this key to set the `host` mapping or leave it as `EMPTY` to not expose interface. |
| ingress.rabbitmqHost |  |  | Based on above configuration, if you want to expose the `rabbitmq` web console to set of users, use this key to set the `host` mapping or leave it as `EMPTY` to not expose interface. |
| ingress.ingressClass | nginx | Yes | Kubernetes cluster setup comes with various options of `ingressClass`. Based on your setup, set this value to the right one (eg. nginx, traefik, etc). Leave it to default in case you are using external ingress provider.|
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
| env.storageClass | &lt;default-sc-on-k8s-cluster&gt; |  | Creating the persitant volumes for the stateful deployments needs the `storageClass` name. Set the correct value as per your kubernetes cluster configuration. |
| env.secret_key | 60gp0byfz2dvffa45cxl20p1scy9xbpf6d8c5y0geejgkyp1b5 | Yes | This must a random string which is used for hashing/encrypting the sensitive data within the application. Once set, changing this might impact the already hashed/encrypted data|
  
## Custom Ingress Routes

If you are planning to use 3rd party ingress providers, here is the available route configuration

| Host | Path | Service | Required |
|---    |:---:|---|:--- |
| plane.example.com | /  | <http://plane-app-web.plane:3000> | Yes |
| plane.example.com | /spaces/*  | <http://plane-app-space.plane:3000> | Yes |
| plane.example.com | /god-mode/* | <http://plane-app-admin.plane:3000> | Yes |
| plane.example.com | /live/* | <http://plane-app-live.plane:3000> | Yes |
| plane.example.com | /api/*  |  <http://plane-app-api.plane:8000> | Yes |
| plane.example.com | /auth/* | <http://plane-app-api.plane:8000> | Yes |
| plane.example.com | /uploads/* | <http://plane-app-minio.plane:9000> | Yes (Only if using local setup) |
| plane-minio.example.com | / | <http://plane-app-minio.plane:9090> | (Optional) if using local setup, this will enable minio console access |
| plane-mq.example.com | / | <http://plane-app-rabbitmq.plane:15672> | (Optional) if using local setup, this will enable management console access |
