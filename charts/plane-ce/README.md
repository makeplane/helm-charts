## Pre-requisite

- A working Kubernetes cluster
- `kubectl` and `helm` on the client system that you will use to install our Helm charts

## Installing Plane

  1. Open Terminal or any other command-line app that has access to Kubernetes tools on your local system.
  1. Add Helm Repo

      ```bash
      helm repo add makeplane https://helm.plane.so/
      ```

  1. Set-up and customization

      - Quick set-up<br>
        This is the fastest way to deploy Plane with default settings. This will create stateful deployments for Postgres, Rabbitmq, Redis, and Minio with a persistent volume claim using the default storage class. This also sets up the ingress routes for you using `nginx` ingress class.
        > To customize this, see `Custom ingress routes` below.

        Continue to be on the same Terminal window as you have so far, copy the code below, and paste it on your Terminal screen.

        ```bash
          helm upgrade --install plane-app makeplane/plane-ce \
              --create-namespace \
              --namespace plane-ce \
              --set planeVersion=stable \
              --set ingress.appHost="plane.example.com" \
              --set ingress.minioHost="plane-minio.example.com" \
              --set ingress.rabbitmqHost="plane-mq.example.com" \
              --set ingress.ingressClass=nginx \
              --timeout 10m \
              --wait \
              --wait-for-jobs
          ```

        > This is the basic setup required for Plane-CE. You can customize the default values for namespace and appname as needed. Additional settings can be configured by referring to the Configuration Settings section.<br>

        Using a Custom StorageClass

        To specify a custom StorageClass for Plane-CE components, add the following options to the above `helm upgrade --install` command:
        ```bash
        --set postgres.storageClass=<your-storageclass-name>
        --set redis.storageClass=<your-storageclass-name>
        --set minio.storageClass=<your-storageclass-name>
        --set rabbitmq.storageClass=<your-storageclass-name>
        ```
      - Advance set-up<br>
        For more control over your set-up, run the script below to download the `values.yaml` file and and edit using any editor like Vim or Nano. 

        ```bash
        helm  show values makeplane/plane-ce > values.yaml
        vi values.yaml
        ```

        > See `Available customizations` for more details.

        After saving the `values.yaml` file, continue to be on the same Terminal window as on the previous steps, copy the code below, and paste it on your Terminal screen.

        ```bash
        helm upgrade --install plane-app makeplane/plane-ce \
            --create-namespace \
            --namespace plane-ce \
            -f values.yaml \
            --timeout 10m \
            --wait \
            --wait-for-jobs 
        ```

## Configuration Settings Available

### Plane Version

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| planeVersion | stable | Yes |  |

### Postgress DB Setup

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| postgres.local_setup | true |  | Plane uses `postgres` as the primary database to store all the transactional data. This database can be hosted within kubernetes as part of helm chart deployment or can be used as hosted service remotely (e.g. aws rds or similar services). Set this to  `true` when you choose to setup stateful deployment of `postgres`. Mark it as `false` when using a remotely hosted database |
| postgres.image | postgres:15.7-alpine |  | Using this key, user must provide the docker image name to setup the stateful deployment of `postgres`. (must be set when `postgres.local_setup=true`)|
| postgres.pullPolicy | IfNotPresent |  | Using this key, user can set the pull policy for the stateful deployment of `postgres`. (must be set when `postgres.local_setup=true`)|
| postgres.servicePort | 5432 |  | This key sets the default port number to be used while setting up stateful deployment of `postgres`. |
| postgres.volumeSize | 5Gi |  | While setting up the stateful deployment, while creating the persistant volume, volume allocation size need to be provided. This key helps you set the volume allocation size. Unit of this value must be in Mi (megabyte) or Gi (gigabyte) |
| env.pgdb_username | plane |  | Database credentials are requried to access the hosted stateful deployment of `postgres`.  Use this key to set the username for the stateful deployment. |
| env.pgdb_password | plane |  | Database credentials are requried to access the hosted stateful deployment of `postgres`.  Use this key to set the password for the stateful deployment. |
| env.pgdb_name | plane |  |  Database name to be used while setting up stateful deployment of `Postgres`|
| env.pgdb_remote_url |  |  | Users can also decide to use the remote hosted database and link to Plane deployment. Ignoring all the above keys, set `postgres.local_setup` to `false` and set this key with remote connection url. |
| postgres.storageClass | &lt;k8s-default-storage-class&gt; |  | Creating the persitant volumes for the stateful deployments needs the `storageClass` name. Set the correct value as per your kubernetes cluster configuration. |
| postgres.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |

### Redis/Valkey Setup

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| redis.local_setup | true |  | Plane uses `redis` to cache the session authentication and other static data. This database can be hosted within kubernetes as part of helm chart deployment or can be used as hosted service remotely (e.g. aws rds or similar services). Set this to  `true` when you choose to setup stateful deployment of `redis`. Mark it as `false` when using a remotely hosted database |
| redis.image | valkey/valkey:7.2.5-alpine |  | Using this key, user must provide the docker image name to setup the stateful deployment of `redis`. (must be set when `redis.local_setup=true`)|
| redis.pullPolicy | IfNotPresent |  | Using this key, user can set the pull policy for the stateful deployment of `redis`. (must be set when `redis.local_setup=true`)|
| redis.servicePort | 6379 |  | This key sets the default port number to be used while setting up stateful deployment of `redis`. |
| redis.volumeSize | 1Gi |  | While setting up the stateful deployment, while creating the persistant volume, volume allocation size need to be provided. This key helps you set the volume allocation size. Unit of this value must be in Mi (megabyte) or Gi (gigabyte) |
| env.remote_redis_url |  |  | Users can also decide to use the remote hosted database and link to Plane deployment. Ignoring all the above keys, set `redis.local_setup` to `false` and set this key with remote connection url. |
| redis.storageClass | &lt;k8s-default-storage-class&gt; |  | Creating the persitant volumes for the stateful deployments needs the `storageClass` name. Set the correct value as per your kubernetes cluster configuration. |
| redis.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |


### RabbitMQ Setup

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| rabbitmq.local_setup | true |  | Plane uses `rabbitmq` as message queuing system. This can be hosted within kubernetes as part of helm chart deployment or can be used as hosted service remotely (e.g. aws mq or similar services). Set this to  `true` when you choose to setup stateful deployment of `rabbitmq`. Mark it as `false` when using a remotely hosted service |
| rabbitmq.image | rabbitmq:3.13.6-management-alpine |  | Using this key, user must provide the docker image name to setup the stateful deployment of `rabbitmq`. (must be set when `rabbitmq.local_setup=true`)|
| rabbitmq.pullPolicy | IfNotPresent |  | Using this key, user can set the pull policy for the stateful deployment of `rabbitmq`. (must be set when `rabbitmq.local_setup=true`)|
| rabbitmq.servicePort | 5672 |  | This key sets the default port number to be used while setting up stateful deployment of `rabbitmq`. |
| rabbitmq.managementPort | 15672 |  | This key sets the default management port number to be used while setting up stateful deployment of `rabbitmq`. |
| rabbitmq.volumeSize | 100Mi |  | While setting up the stateful deployment, while creating the persistant volume, volume allocation size need to be provided. This key helps you set the volume allocation size. Unit of this value must be in Mi (megabyte) or Gi (gigabyte) |
| rabbitmq.storageClass | &lt;k8s-default-storage-class&gt; |  | Creating the persitant volumes for the stateful deployments needs the `storageClass` name. Set the correct value as per your kubernetes cluster configuration. |
| rabbitmq.default_user | plane |  | Credentials are requried to access the hosted stateful deployment of `rabbitmq`.  Use this key to set the username for the stateful deployment. |
| rabbitmq.default_password | plane |  | Credentials are requried to access the hosted stateful deployment of `rabbitmq`.  Use this key to set the password for the stateful deployment. |
| rabbitmq.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |
| rabbitmq.external_rabbitmq_url |  |  | Users can also decide to use the remote hosted service and link to Plane deployment. Ignoring all the above keys, set `rabbitmq.local_setup` to `false` and set this key with remote connection url. |

### Doc Store (Minio/S3) Setup

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| minio.local_setup | true |  | Plane uses `minio` as the default file storage drive. This storage can be hosted within kubernetes as part of helm chart deployment or can be used as hosted service remotely (e.g. aws S3 or similar services). Set this to  `true` when you choose to setup stateful deployment of `postgres`. Mark it as `false` when using a remotely hosted database |
| minio.image | minio/minio:latest |  | Using this key, user must provide the docker image name to setup the stateful deployment of `minio`. (must be set when `minio.local_setup=true`)|
| minio.image_mc | minio/mc:latest |  | Using this key, user must provide the docker image name to setup the job deployment of `minio client`. (must be set when `services.minio.local_setup=true`)|
| minio.pullPolicy | IfNotPresent |  | Using this key, user can set the pull policy for the stateful deployment of `minio`. (must be set when `minio.local_setup=true`)|
| minio.volumeSize | 5Gi |  | While setting up the stateful deployment, while creating the persistant volume, volume allocation size need to be provided. This key helps you set the volume allocation size. Unit of this value must be in Mi (megabyte) or Gi (gigabyte) |
| minio.root_user | admin |  | Storage credentials are requried to access the hosted stateful deployment of `minio`.  Use this key to set the username for the stateful deployment. |
| minio.root_password | password |  | Storage credentials are requried to access the hosted stateful deployment of `minio`.  Use this key to set the password for the stateful deployment. |
| minio.env.minio_endpoint_ssl | false |  | (Optional) Env to enforce HTTPS when connecting to minio uploads bucket  |
| env.docstore_bucket | uploads | Yes | Storage bucket name is required as part of configuration. This is where files will be uploaded irrespective of if you are using `Minio` or external `S3` (or compatible) storage service |
| env.doc_upload_size_limit | 5242880 | Yes | Document Upload Size Limit (default to 5Mb) |
| env.aws_access_key |  |  | External `S3` (or compatible) storage service provides `access key` for the application to connect and do the necessary upload/download operations. To be provided when `minio.local_setup=false`  |
| env.aws_secret_access_key |  |  | External `S3` (or compatible) storage service provides `secret access key` for the application to connect and do the necessary upload/download operations. To be provided when `minio.local_setup=false`  |
| env.aws_region |  |  | External `S3` (or compatible) storage service providers creates any buckets in user selected region. This is also shared with the user as `region` for the application to connect and do the necessary upload/download operations. To be provided when `minio.local_setup=false`  |
| env.aws_s3_endpoint_url |  |  | External `S3` (or compatible) storage service providers shares a `endpoint_url` for the integration purpose for the application to connect and do the necessary upload/download operations. To be provided when `minio.local_setup=false`  |
| minio.storageClass | &lt;k8s-default-storage-class&gt; |  | Creating the persitant volumes for the stateful deployments needs the `storageClass` name. Set the correct value as per your kubernetes cluster configuration. |
| minio.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |

### Web Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| web.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| web.memoryLimit | 1000Mi |  | Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| web.cpuLimit | 500m |  |  Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| web.memoryRequest | 50Mi |  | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.|
| web.cpuRequest | 50m |  | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.|
| web.image| artifacts.plane.so/makeplane/plane-frontend |  |  This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |
| web.pullPolicy | Always |  | Using this key, user can set the pull policy for the deployment of `web`. |  
| web.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |

### Space Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| space.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| space.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| space.cpuLimit | 500m |  | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| space.memoryRequest | 50Mi |  | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.|
| space.cpuRequest | 50m |  | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.|
| space.image| artifacts.plane.so/makeplane/plane-space|  |  This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |
| space.pullPolicy | Always |  | Using this key, user can set the pull policy for the deployment of `space`. |
| space.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |

### Admin Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| admin.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| admin.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| admin.cpuLimit | 500m |  |  Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| admin.memoryRequest | 50Mi |  | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.|
| admin.cpuRequest | 50m |  | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.|
| admin.image| artifacts.plane.so/makeplane/plane-admin |  |  This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |
| admin.pullPolicy | Always |  | Using this key, user can set the pull policy for the deployment of `admin`. |
| admin.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |

### Live Service Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| live.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| live.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| live.cpuLimit | 500m |  |  Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| live.memoryRequest | 50Mi |  | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.|
| live.cpuRequest | 50m |  | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.|
| live.image| artifacts.plane.so/makeplane/plane-live |  |  This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |
| live.pullPolicy | Always |  | Using this key, user can set the pull policy for the deployment of `live`. |
| env.live_sentry_dsn |  |  | (optional) Live service deployment comes with some of the preconfigured integration. Sentry is one among those. Here user can set the Sentry provided DSN for this integration.|
| env.live_sentry_environment |  |  | (optional) Live service deployment comes with some of the preconfigured integration. Sentry is one among those. Here user can set the Sentry environment name (as configured in Sentry) for this integration.|
| env.live_sentry_traces_sample_rate |  |  | (optional) Live service deployment comes with some of the preconfigured integration. Sentry is one among those. Here user can set the Sentry trace sample rate (as configured in Sentry) for this integration.|
| live.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |

### API Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| api.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| api.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| api.cpuLimit | 500m |  | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| api.memoryRequest | 50Mi |  | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.|
| api.cpuRequest | 50m |  | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.|
| api.image| artifacts.plane.so/makeplane/plane-backend |  | This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |
| api.pullPolicy | Always |  | Using this key, user can set the pull policy for the deployment of `api`. |
| env.sentry_dsn |  |  | (optional) API service deployment comes with some of the preconfigured integration. Sentry is one among those. Here user can set the Sentry provided DSN for this integration.|
| env.sentry_environment |  |  | (optional) API service deployment comes with some of the preconfigured integration. Sentry is one among those. Here user can set the Sentry environment name (as configured in Sentry) for this integration.|
| env.api_key_rate_limit | 60/minute |  | (optional) User can set the maximum number of requests the API can handle in a given time frame.|
| api.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |

### Worker Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| worker.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| worker.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| worker.cpuLimit | 500m |  | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| worker.memoryRequest | 50Mi |  | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.|
| worker.cpuRequest | 50m |  | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.|
| worker.image| artifacts.plane.so/makeplane/plane-backend |  | This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |

### Beat-Worker deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| beatworker.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| beatworker.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| beatworker.cpuLimit | 500m |  | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| beatworker.memoryRequest | 50Mi |  | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.|
| beatworker.cpuRequest | 50m |  | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.|
| beatworker.image| artifacts.plane.so/makeplane/plane-backend |  | This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |

### Ingress and SSL Setup

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| ingress.enabled | true |  | Ingress setup in kubernetes is a common practice to expose application to the intended audience.  Set it to `false` if you are using external ingress providers like `Cloudflare` |
| ingress.appHost | plane.example.com | Yes | The fully-qualified domain name (FQDN) in the format `sudomain.domain.tld` or `domain.tld` that the license is bound to. It is also attached to your `ingress` host to access Plane. |
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
| ssl.tls_secret_name |  |  | If you have a custom TLS secret name, set this to the name of the secret. Applicable only when `ingress.enabled=true` and `ssl.createIssuer=false` |

### Common Environment Settings

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| env.secret_key | 60gp0byfz2dvffa45cxl20p1scy9xbpf6d8c5y0geejgkyp1b5 | Yes | This must a random string which is used for hashing/encrypting the sensitive data within the application. Once set, changing this might impact the already hashed/encrypted data|
| env.default_cluster_domain | cluster.local | Yes | Set this value as configured in your kubernetes cluster. `cluster.local` is usally the default in most cases. |


## External Secrets Config

To configure the external secrets for your application, you need to define specific environment variables for each secret category. Below is a list of the required secrets and their respective environment variables.

| Secret Name | Env Var Name | Required | Description | Example Value |
|--- |:---|:---|:---|:---|
| rabbitmq_existingSecret     | `RABBITMQ_DEFAULT_USER`  | Required if `rabbitmq.local_setup=true` | The default RabbitMQ user                    | `plane`      |
|                      | `RABBITMQ_DEFAULT_PASS`  | Required if `rabbitmq.local_setup=true` | The default RabbitMQ password                | `plane`      |
| pgdb_existingSecret         | `POSTGRES_PASSWORD`      | Required if `postgres.local_setup=true` | Password for PostgreSQL database             | `plane`   |
|                      | `POSTGRES_DB`            | Required if `postgres.local_setup=true` | Name of the PostgreSQL database              | `plane`      |
|                      | `POSTGRES_USER`          | Required if `postgres.local_setup=true` | PostgreSQL user                              | `plane`       |
|  doc_store_existingSecret                 | `USE_MINIO`              | Yes | Flag to enable MinIO as the storage backend  | `1`         |
|                      | `MINIO_ROOT_USER`        | Yes | MinIO root user                              | `admin`    |
|     | `MINIO_ROOT_PASSWORD`    | Yes | MinIO root password                          | `password`    |
|                      | `AWS_ACCESS_KEY_ID`      | Yes | AWS Access Key ID                            | `your_aws_key`       |
|                      | `AWS_SECRET_ACCESS_KEY`  | Yes | AWS Secret Access Key                        | `your_aws_secret`    |
|                      | `AWS_S3_BUCKET_NAME`     | Yes | AWS S3 Bucket Name                           | `your_bucket_name`   |
|                      | `AWS_S3_ENDPOINT_URL`    | Yes | Endpoint URL for AWS S3 or MinIO             | `http://plane-minio.plane-ns.svc.cluster.local:9000`  |
|                      | `AWS_REGION`             | Optional | AWS region where your S3 bucket is located   | `your_aws_region`    |
|                      | `FILE_SIZE_LIMIT`        | Yes | Limit for file uploads in your system        | `5MB`               |
| app_env_existingSecret      | `SECRET_KEY`             | Yes | Random secret key                            | `60gp0byfz2dvffa45cxl20p1scy9xbpf6d8c5y0geejgkyp1b5`  |
|                      | `REDIS_URL`              | Yes | Redis URL                                    | `redis://plane-redis.plane-ns.svc.cluster.local:6379/`  |
|                      | `DATABASE_URL`           | Yes | PostgreSQL connection URL                    | **k8s service example**: `postgresql://plane:plane@plane-pgdb.plane-ns.svc.cluster.local:5432/plane` <br> <br>**external service example**: `postgresql://username:password@your-db-host:5432/plane` |
|                      | `AMQP_URL`               | Yes | RabbitMQ connection URL                      | **k8s service example**: `amqp://plane:plane@plane-rabbitmq.plane-ns.svc.cluster.local:5672/`  <br> <br> **external service example**: `amqp://username:password@your-rabbitmq-host:5672/` |
| live_env_existingSecret      | `REDIS_URL`              | Yes | Redis URL                                    | `redis://plane-redis.plane-ns.svc.cluster.local:6379/` |


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
