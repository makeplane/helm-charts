## Pre-requisite

- A working Kubernetes cluster
- `kubectl` and `helm` on the client system that you will use to install our Helm charts

## Installing Plane

  1. Open Terminal or any other command-line app that has access to Kubernetes tools on your local system.
  2. Set the following environment variables.
  
      Copy the format of constants below, paste it on Terminal to start setting environment variables, set values for each variable, and hit ENTER or RETURN.

      ```bash
      PLANE_VERSION=v1.14.0 # or the last released version
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
        helm upgrade --install plane-app plane/plane-enterprise \
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

        Using a Custom StorageClass

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
          - `planeVersion: v1.14.0 <or the last released version>`
          - `license.licenseDomain: <The domain you have specified to host Plane>`
          - `ingress.enabled: <true | false>`
          - `ingress.ingressClass: <nginx or any other ingress class configured in your cluster>`
          - `env.storageClass: <default storage class configured in your cluster>`

            > See `Available customizations` for more details.

          After saving the `values.yaml` file, continue to be on the same Terminal window as on the previous steps, copy the code below, and paste it on your Terminal screen.

          ```bash
          helm upgrade --install plane-app plane/plane-enterprise \
              --create-namespace \
              --namespace plane \
              -f values.yaml \
              --timeout 10m \
              --wait \
              --wait-for-jobs 
          ```

## Available customizations
   
### License

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| planeVersion | v1.14.0 | Yes |  Specifies the version of Plane to be deployed. Copy this from prime.plane.so. |
| airgapped.enabled | false | No |  Specifies the airgapped mode the Plane API runs in. |
| license.licenseDomain | plane.example.com | Yes | The fully-qualified domain name (FQDN) in the format `sudomain.domain.tld` or `domain.tld` that the license is bound to. It is also attached to your `ingress` host to access Plane. |

### Postgres

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.postgres.local_setup | true |  | Plane uses `postgres` as the primary database to store all the transactional data. This database can be hosted within kubernetes as part of helm chart deployment or can be used as hosted service remotely (e.g. aws rds or similar services). Set this to  `true` when you choose to setup stateful deployment of `postgres`. Mark it as `false` when using a remotely hosted database |
| services.postgres.image | postgres:15.7-alpine |  | Using this key, user must provide the docker image name to setup the stateful deployment of `postgres`. (must be set when `services.postgres.local_setup=true`)|
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
| services.redis.image | valkey/valkey:7.2.5-alpine |  | Using this key, user must provide the docker image name to setup the stateful deployment of `redis`. (must be set when `services.redis.local_setup=true`)|
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
| services.minio.image | minio/minio:latest |  | Using this key, user must provide the docker image name to setup the stateful deployment of `minio`. (must be set when `services.minio.local_setup=true`)|
| services.minio.image_mc | minio/mc:latest |  | Using this key, user must provide the docker image name to setup the job deployment of `minio client`. (must be set when `services.minio.local_setup=true`)|
| services.minio.pullPolicy | IfNotPresent |  | Using this key, user can set the pull policy for the stateful deployment of `minio`. (must be set when `services.minio.local_setup=true`)|
| services.minio.volumeSize | 3Gi |  | While setting up the stateful deployment, while creating the persistant volume, volume allocation size need to be provided. This key helps you set the volume allocation size. Unit of this value must be in Mi (megabyte) or Gi (gigabyte) |
| services.minio.root_user | admin |  |  Storage credentials are requried to access the hosted stateful deployment of `minio`.  Use this key to set the username for the stateful deployment. |
| services.minio.root_password | password |  | Storage credentials are requried to access the hosted stateful deployment of `minio`.  Use this key to set the password for the stateful deployment. |
| services.minio.env.minio_endpoint_ssl | false |  | (Optional) Env to enforce HTTPS when connecting to minio uploads bucket  |
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
| services.web.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| services.web.cpuLimit | 500m |  |  Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| services.web.memoryRequest | 50Mi |  | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.|
| services.web.cpuRequest | 50m |  | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.|
| services.web.image| artifacts.plane.so/makeplane/web-commercial |  |  This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |
| services.web.pullPolicy | Always |  | Using this key, user can set the pull policy for the deployment of `web`. |
| services.web.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |

### Space Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.space.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| services.space.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| services.space.cpuLimit | 500m |  | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| services.space.memoryRequest | 50Mi |  | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.|
| services.space.cpuRequest | 50m |  | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.|
| services.space.image| artifacts.plane.so/makeplane/space-commercial |  |  This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |
| services.space.pullPolicy | Always |  | Using this key, user can set the pull policy for the deployment of `space`. |
| services.space.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |

### Admin Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.admin.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| services.admin.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| services.admin.cpuLimit | 500m |  |  Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| services.admin.memoryRequest | 50Mi |  | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.|
| services.admin.cpuRequest | 50m |  | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.|
| services.admin.image| artifacts.plane.so/makeplane/admin-commercial |  |  This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |
| services.admin.pullPolicy | Always |  | Using this key, user can set the pull policy for the deployment of `admin`. |
| services.admin.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |

### Live Service Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.live.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| services.live.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| services.live.cpuLimit | 500m |  |  Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| services.live.memoryRequest | 50Mi |  | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.|
| services.live.cpuRequest | 50m |  | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.|
| services.live.image| artifacts.plane.so/makeplane/live-commercial |  |  This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |
| services.live.pullPolicy | Always |  | Using this key, user can set the pull policy for the deployment of `live`. |
| env.live_sentry_dsn |  |  | (optional) Live service deployment comes with some of the preconfigured integration. Sentry is one among those. Here user can set the Sentry provided DSN for this integration.|
| env.live_sentry_environment |  |  | (optional) Live service deployment comes with some of the preconfigured integration. Sentry is one among those. Here user can set the Sentry environment name (as configured in Sentry) for this integration.|
| env.live_sentry_traces_sample_rate |  |  | (optional) Live service deployment comes with some of the preconfigured integration. Sentry is one among those. Here user can set the Sentry trace sample rate (as configured in Sentry) for this integration.|
| env.live_server_secret_key | htbqvBJAgpm9bzvf3r4urJer0ENReatceh |  | Live Server Secret Key |
| env.live_iframely_url | "" |  | External Iframely service URL. If provided, the local Iframely deployment will be skipped and the live service will use this external URL |
| services.live.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |

### Monitor Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.monitor.memoryLimit | 1000Mi |  | Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| services.monitor.cpuLimit | 500m |  |  Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| services.monitor.memoryRequest | 50Mi |  | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.|
| services.monitor.cpuRequest | 50m |  | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.|
| services.monitor.image| artifacts.plane.so/makeplane/monitor-commercial |  |  This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |
| services.monitor.pullPolicy | Always |  | Using this key, user can set the pull policy for the deployment of `monitor`. |
| services.monitor.volumeSize | 100Mi |  | While setting up the stateful deployment, while creating the persistant volume, volume allocation size need to be provided. This key helps you set the volume allocation size. Unit of this value must be in Mi (megabyte) or Gi (gigabyte) |
| services.monitor.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |

### API Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.api.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| services.api.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| services.api.cpuLimit | 500m |  | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| services.api.memoryRequest | 50Mi |  | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.|
| services.api.cpuRequest | 50m |  | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.|
| services.api.image| artifacts.plane.so/makeplane/backend-commercial |  | This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |
| services.api.pullPolicy | Always |  | Using this key, user can set the pull policy for the deployment of `api`. |
| env.sentry_dsn |  |  | (optional) API service deployment comes with some of the preconfigured integration. Sentry is one among those. Here user can set the Sentry provided DSN for this integration.|
| env.sentry_environment |  |  | (optional) API service deployment comes with some of the preconfigured integration. Sentry is one among those. Here user can set the Sentry environment name (as configured in Sentry) for this integration.|
| env.api_key_rate_limit | 60/minute |  | (optional) User can set the maximum number of requests the API can handle in a given time frame.|
| services.api.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |

### Silo Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.silo.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| services.silo.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| services.silo.cpuLimit | 500m |  |  Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| services.silo.memoryRequest | 50Mi |  | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.|
| services.silo.cpuRequest | 50m |  | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.|
| services.silo.image| artifacts.plane.so/makeplane/silo-commercial |  |  This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment |
| services.silo.pullPolicy | Always |  | Using this key, user can set the pull policy for the deployment of `silo`. |
| services.silo.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service | 
| services.silo.connectors.slack.enabled | false |  | Slack Integration |
| services.silo.connectors.slack.client_id | "" | required if `services.silo.connectors.slack.enabled` is `true` | Slack Client ID |
| services.silo.connectors.slack.client_secret | "" | required if `services.silo.connectors.slack.enabled` is `true` | Slack Client Secret |
| services.silo.connectors.github.enabled | false |  | Github App Integration |
| services.silo.connectors.github.client_id | "" | required if `services.silo.connectors.github.enabled` is `true` | Github Client ID |
| services.silo.connectors.github.client_secret | "" | required if `services.silo.connectors.github.enabled` is `true` | Github Client Secret |
| services.silo.connectors.github.app_name | "" | required if `services.silo.connectors.github.enabled` is `true` | Github App Name |
| services.silo.connectors.github.app_id | "" | required if `services.silo.connectors.github.enabled` is `true` | Github App ID |
| services.silo.connectors.github.private_key | "" | required if `services.silo.connectors.github.enabled` is `true` | Github Private Key |
| services.silo.connectors.gitlab.enabled | false |  | Gitlab App Integration |
| services.silo.connectors.gitlab.client_id | "" | required if `services.silo.connectors.gitlab.enabled` is `true` | Gitlab Client ID |
| services.silo.connectors.gitlab.client_secret | "" | required if `services.silo.connectors.gitlab.enabled` is `true` | Gitlab Client Secret |
| env.silo_envs.mq_prefetch_count | 10 |  | Prefetch count for RabbitMQ |
| env.silo_envs.batch_size | 60 |  | Batch size for Silo |
| env.silo_envs.request_interval | 400 |  | Request interval for Silo |
| env.silo_envs.sentry_dsn |  |  | Sentry DSN |
| env.silo_envs.sentry_environment |  |  | Sentry Environment |
| env.silo_envs.sentry_traces_sample_rate |  |  | Sentry Traces Sample Rate | 
| env.silo_envs.hmac_secret_key |  &lt;random-32-bit-string&gt; |  | HMAC Secret Key |
| env.silo_envs.aes_secret_key | "dsOdt7YrvxsTIFJ37pOaEVvLxN8KGBCr" |  | AES Secret Key |

  
### Worker Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.worker.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| services.worker.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| services.worker.cpuLimit | 500m |  | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| services.worker.memoryRequest | 50Mi |  | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.|
| services.worker.cpuRequest | 50m |  | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.|

### Beat-Worker deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.beatworker.replicas | 1 | Yes | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| services.beatworker.memoryLimit | 1000Mi |  |  Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.|
| services.beatworker.cpuLimit | 500m |  | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.|
| services.beatworker.memoryRequest | 50Mi |  | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.|
| services.beatworker.cpuRequest | 50m |  | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.|

### Email Service Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.email_service.enabled | false |  | Set to `true` to enable the email service deployment |
| services.email_service.replicas | 1 |  | Number of replicas for the email service deployment |
| services.email_service.memoryLimit | 1000Mi |  | Memory limit for the email service deployment |
| services.email_service.cpuLimit | 500m |  | CPU limit for the email service deployment |
| services.email_service.memoryRequest | 50Mi |  | Memory request for the email service deployment |
| services.email_service.cpuRequest | 50m |  | CPU request for the email service deployment |
| services.email_service.image | artifacts.plane.so/makeplane/email-commercial |  | Docker image for the email service deployment |
| services.email_service.pullPolicy | Always |  | Image pull policy for the email service deployment |
| env.email_service_envs.smtp_domain |  | Yes | The SMTP Domain to be used with email service |

Note: When the email service is enabled, the cert-issuer will be automatically created to handle TLS certificates for the email service.


### Outbox Poller Service Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.outbox_poller.enabled | false |  | Set to `true` to enable the outbox poller service deployment |
| services.outbox_poller.replicas | 1 |  | Number of replicas for the outbox poller service deployment |
| services.outbox_poller.memoryLimit | 1000Mi |  | Memory limit for the outbox poller service deployment |
| services.outbox_poller.cpuLimit | 500m |  | CPU limit for the outbox poller service deployment |
| services.outbox_poller.memoryRequest | 50Mi |  | Memory request for the outbox poller service deployment |
| services.outbox_poller.cpuRequest | 50m |  | CPU request for the outbox poller service deployment |
| services.outbox_poller.image | artifacts.plane.so/makeplane/backend-commercial |  | Docker image for the outbox poller service deployment |
| services.outbox_poller.pullPolicy | Always |  | Image pull policy for the outbox poller service deployment |
| services.outbox_poller.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |
| env.outbox_poller_envs.memory_limit_mb | 400 |  | Memory limit in MB for the outbox poller |
| env.outbox_poller_envs.interval_min | 0.25 |  | Minimum interval in minutes for polling |
| env.outbox_poller_envs.interval_max | 2 |  | Maximum interval in minutes for polling |
| env.outbox_poller_envs.batch_size | 250 |  | Batch size for processing outbox messages |
| env.outbox_poller_envs.memory_check_interval | 30 |  | Memory check interval in seconds |
| env.outbox_poller_envs.pool.size | 4 |  | Pool size for database connections |
| env.outbox_poller_envs.pool.min_size | 2 |  | Minimum pool size for database connections |
| env.outbox_poller_envs.pool.max_size | 10 |  | Maximum pool size for database connections |
| env.outbox_poller_envs.pool.timeout | 30.0 |  | Pool timeout in seconds |
| env.outbox_poller_envs.pool.max_idle | 300.0 |  | Maximum idle time for connections in seconds |
| env.outbox_poller_envs.pool.max_lifetime | 3600 |  | Maximum lifetime for connections in seconds |
| env.outbox_poller_envs.pool.reconnect_timeout | 5.0 |  | Reconnect timeout in seconds |
| env.outbox_poller_envs.pool.health_check_interval | 60 |  | Health check interval in seconds |

### Automation Consumer Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.automation_consumer.enabled | false |  | Set to `true` to enable the automation consumer service deployment |
| services.automation_consumer.replicas | 1 |  | Number of replicas for the automation consumer service deployment |
| services.automation_consumer.memoryLimit | 1000Mi |  | Memory limit for the automation consumer service deployment |
| services.automation_consumer.cpuLimit | 500m |  | CPU limit for the automation consumer service deployment |
| services.automation_consumer.memoryRequest | 50Mi |  | Memory request for the automation consumer service deployment |
| services.automation_consumer.cpuRequest | 50m |  | CPU request for the automation consumer service deployment |
| services.automation_consumer.image | artifacts.plane.so/makeplane/backend-commercial |  | Docker image for the automation consumer service deployment |
| services.automation_consumer.pullPolicy | Always |  | Image pull policy for the automation consumer service deployment |
| services.automation_consumer.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |
| env.automation_consumer_envs.event_stream_queue_name | "plane.event_stream.automations" |  | Event stream queue name for automations |
| env.automation_consumer_envs.event_stream_prefetch | 10 |  | Event stream prefetch count |
| env.automation_consumer_envs.exchange_name | "plane.event_stream" |  | Exchange name for event stream |
| env.automation_consumer_envs.event_types | "issue" |  | Event types to process |

### Iframely Deployment

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| services.iframely.enabled | false |  | Set to `true` to enable the Iframely service deployment |
| services.iframely.replicas | 1 |  | Number of replicas for the Iframely service deployment |
| services.iframely.memoryLimit | 1000Mi |  | Memory limit for the Iframely service deployment |
| services.iframely.cpuLimit | 500m |  | CPU limit for the Iframely service deployment |
| services.iframely.memoryRequest | 50Mi |  | Memory request for the Iframely service deployment |
| services.iframely.cpuRequest | 50m |  | CPU request for the Iframely service deployment |
| services.iframely.image | artifacts.plane.so/makeplane/iframely:v1.2.0 |  | Docker image for the Iframely service deployment |
| services.iframely.pullPolicy | Always |  | Image pull policy for the Iframely service deployment |
| services.iframely.assign_cluster_ip | false |  | Set it to `true` if you want to assign `ClusterIP` to the service |


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
| ssl.tls_secret_name |  |  | If you have a custom TLS secret name, set this to the name of the secret. Applicable only when `ingress.enabled=true` and `ssl.createIssuer=false` |

### Common Environment Settings

| Setting | Default | Required | Description |
|---|:---:|:---:|---|
| env.storageClass | &lt;k8s-default-storage-class&gt; |  | Creating the persitant volumes for the stateful deployments needs the `storageClass` name. Set the correct value as per your kubernetes cluster configuration. |
| env.secret_key | 60gp0byfz2dvffa45cxl20p1scy9xbpf6d8c5y0geejgkyp1b5 | Yes | This must a random string which is used for hashing/encrypting the sensitive data within the application. Once set, changing this might impact the already hashed/encrypted data|


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
| live_env_existingSecret    | `REDIS_URL`              | Yes | Redis URL                                    | `redis://plane-redis.plane-ns.svc.cluster.local:6379/`  |
| silo_env_existingSecret    | `SILO_HMAC_SECRET_KEY`       | Yes | Silo HMAC secret Key                             | `<random-32-bit-string>`|
|     | `REDIS_URL`              | Yes | Redis URL                                    | `redis://plane-redis.plane-ns.svc.cluster.local:6379/`  |
|                            | `DATABASE_URL`           | Yes | PostgreSQL connection URL                    |  **k8s service example**: `postgresql://plane:plane@plane-pgdb.plane-ns.svc.cluster.local:5432/plane` <br> <br>**external service example**: `postgresql://username:password@your-db-host:5432/plane`|
|                            | `AMQP_URL`               | Yes | RabbitMQ connection URL                      | **k8s service example**: `amqp://plane:plane@plane-rabbitmq.plane-ns.svc.cluster.local:5672/`  <br> <br> **external service example**: `amqp://username:password@your-rabbitmq-host:5672/`  |
|                            | `GITHUB_APP_NAME`        | required if `services.silo.connectors.github.enabled` is `true` | GitHub app name                              | `your_github_app_name`|
|                            | `GITHUB_APP_ID`          | required if `services.silo.connectors.github.enabled` is `true` | GitHub app ID                                | `your_github_app_id`|
|                            | `GITHUB_CLIENT_ID`       | required if `services.silo.connectors.github.enabled` is `true` | GitHub client ID                             | `your_github_client_id`|
|                            | `GITHUB_CLIENT_SECRET` | required if `services.silo.connectors.github.enabled` is `true` | GitHub client secret key                     | `your_github_client_secret_key`|
|                            | `GITHUB_PRIVATE_KEY`     | required if `services.silo.connectors.github.enabled` is `true` | GitHub private key                           | `your_github_private_key`|
|                            | `SLACK_CLIENT_ID`        | required if `services.silo.connectors.slack.enabled` is `true` | Slack client ID                              | `your_slack_client_id`|
|                            | `SLACK_CLIENT_SECRET` | required if `services.silo.connectors.slack.enabled` is `true` | Slack client secret key                      | `your_slack_client_secret_key`|
|                            | `GITLAB_CLIENT_ID`      | required if `services.silo.connectors.gitlab.enabled` is `true` | GitLab client ID                             | `your_gitlab_client_id`|
|                            | `GITLAB_CLIENT_SECRET` | required if `services.silo.connectors.gitlab.enabled` is `true` | GitLab client secret key                     | `your_gitlab_client_secret_key`|
  
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