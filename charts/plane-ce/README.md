# Plane-CE Helm Chart

## Pre-requisite

- A working Kubernetes cluster
- `kubectl` and `helm` on the client system that you will use to install our Helm charts
- An ingress controller installed in your cluster:
  - **Traefik** — install via Helm: [`traefik/traefik`](https://artifacthub.io/packages/helm/traefik/traefik)
    ```bash
    helm repo add traefik https://traefik.github.io/charts
    helm repo update
    helm upgrade --install traefik traefik/traefik \
      --create-namespace \
      --namespace traefik \
      --wait
    ```
  - **nginx** — install via Helm: [`ingress-nginx/ingress-nginx`](https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx)
    ```bash
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace
    ```

## Installing Plane

1. Open Terminal or any other command-line app that has access to Kubernetes tools on your local system.
1. Add Helm Repo

   ```bash
   helm repo add makeplane https://helm.plane.so/
   ```

1. Set-up and customization

   - Quick set-up

     This is the fastest way to deploy Plane with default settings. This will create stateful deployments for Postgres, Rabbitmq, Redis, and Minio with a persistent volume claim using the default storage class. This also sets up the ingress routes for you using `nginx` ingress class.

     > To customize this, see `Custom ingress routes` below.

     Continue to be on the same Terminal window as you have so far, copy the code below, and paste it on your Terminal screen.

     ```bash
       helm upgrade --install plane-app makeplane/plane-ce \
           --create-namespace \
           --namespace plane-ce \
           --set planeVersion=v1.4.1 \
           --set ingress.appHost="plane.example.com" \
           --set ingress.minioHost="plane-minio.example.com" \
           --set ingress.rabbitmqHost="plane-mq.example.com" \
           --set ingress.ingressClass=nginx \
           --timeout 10m \
           --wait \
           --wait-for-jobs
     ```

     > This is the basic setup required for Plane-CE. You can customize the default values for namespace and appname as needed. Additional settings can be configured by referring to the Configuration Settings section.

     Using a Custom StorageClass

     To specify a custom StorageClass for Plane-CE components, add the following options to the above `helm upgrade --install` command:

     ```bash
     --set postgres.storageClass=<your-storageclass-name>
     --set redis.storageClass=<your-storageclass-name>
     --set minio.storageClass=<your-storageclass-name>
     --set rabbitmq.storageClass=<your-storageclass-name>
     ```

   - Advance set-up

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

## Migrating the Ingress Controller

The chart selects between two ingress templates based on `ingress.ingressClass`:

| `ingressClass` value           | Template rendered                | Resource kind                      |
| ------------------------------ | -------------------------------- | ---------------------------------- |
| `traefik` (or starts with it)  | `templates/ingress-traefik.yaml` | `traefik.io/v1alpha1 IngressRoute` |
| Any other value (e.g. `nginx`) | `templates/ingress.yaml`         | `networking.k8s.io/v1 Ingress`     |

The default value is `"traefik"`. If you previously relied on the implicit default without setting `ingressClass` explicitly, your cluster is running Traefik `IngressRoute` CRDs.

### Switching from Traefik to a standard Ingress controller (e.g. nginx)

1. **Install your target ingress controller** if it is not already running (see Pre-requisites above).

2. **Update `ingress.ingressClass`** in your `values.yaml`:

   ```yaml
   ingress:
     ingressClass: "nginx"   # or whichever class your controller exposes
   ```

3. **Run `helm upgrade`**:

   ```bash
   helm upgrade plane-app makeplane/plane-ce \
     --namespace plane-ce \
     -f values.yaml \
     --wait
   ```

   After the upgrade the `IngressRoute` and `Middleware` resources are no longer rendered and will be orphaned — delete them manually:

   ```bash
   kubectl delete ingressroute -n plane-ce -l app.kubernetes.io/instance=plane-app
   kubectl delete middleware    -n plane-ce -l app.kubernetes.io/instance=plane-app
   ```

4. **Verify** that the new `Ingress` is admitted and routes traffic before removing the old Traefik resources.

### Switching from a standard Ingress controller to Traefik

1. **Install Traefik** with CRD support enabled (see Pre-requisites above).

2. **Update `ingress.ingressClass`**:

   ```yaml
   ingress:
     ingressClass: "traefik"
   ```

3. **Run `helm upgrade`**. The old `Ingress` resource is orphaned — delete it:

   ```bash
   kubectl delete ingress -n plane-ce <release-name>-ingress
   ```

### Key values controlling template selection

| Value                         | Default    | Effect                                                                                          |
| ----------------------------- | ---------- | ----------------------------------------------------------------------------------------------- |
| `ingress.enabled`             | `true`     | Master switch — set to `false` to render neither template.                                      |
| `ingress.appHost`             | _(empty)_  | Required for both templates; no ingress is rendered without it.                                 |
| `ingress.ingressClass`        | `traefik`  | Selects which template is active (see table above).                                             |
| `ingress.traefik.*`           | see values | Traefik-only settings (middleware body limit). Ignored when using the standard `Ingress`.       |
| `ingress.ingress_annotations` | `{}`       | Standard `Ingress` annotations. Ignored when `ingressClass` starts with `traefik`.             |

## Configuration Settings Available

### Plane Version

| Setting      | Default | Required | Description |
| ------------ | :-----: | :------: | ----------- |
| planeVersion | v1.4.1  |   Yes    |             |

### Postgress DB Setup

| Setting                    |              Default              | Required | Description                                                                                                                                                                                                                                                                                                                                                                             |
| -------------------------- | :-------------------------------: | :------: | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| postgres.local_setup       |               true                |          | Plane uses `postgres` as the primary database to store all the transactional data. This database can be hosted within kubernetes as part of helm chart deployment or can be used as hosted service remotely (e.g. aws rds or similar services). Set this to `true` when you choose to setup stateful deployment of `postgres`. Mark it as `false` when using a remotely hosted database |
| postgres.image             |       postgres:15.7-alpine        |          | Using this key, user must provide the docker image name to setup the stateful deployment of `postgres`. (must be set when `postgres.local_setup=true`)                                                                                                                                                                                                                                  |
| postgres.pullPolicy        |           IfNotPresent            |          | Using this key, user can set the pull policy for the stateful deployment of `postgres`. (must be set when `postgres.local_setup=true`)                                                                                                                                                                                                                                                  |
| postgres.servicePort       |               5432                |          | This key sets the default port number to be used while setting up stateful deployment of `postgres`.                                                                                                                                                                                                                                                                                    |
| postgres.volumeSize        |                5Gi                |          | While setting up the stateful deployment, while creating the persistant volume, volume allocation size need to be provided. This key helps you set the volume allocation size. Unit of this value must be in Mi (megabyte) or Gi (gigabyte)                                                                                                                                             |
| env.pgdb_username          |               plane               |          | Database credentials are requried to access the hosted stateful deployment of `postgres`. Use this key to set the username for the stateful deployment.                                                                                                                                                                                                                                 |
| env.pgdb_password          |               plane               |          | Database credentials are requried to access the hosted stateful deployment of `postgres`. Use this key to set the password for the stateful deployment.                                                                                                                                                                                                                                 |
| env.pgdb_name              |               plane               |          | Database name to be used while setting up stateful deployment of `Postgres`                                                                                                                                                                                                                                                                                                             |
| env.pgdb_remote_url        |                                   |          | Users can also decide to use the remote hosted database and link to Plane deployment. Ignoring all the above keys, set `postgres.local_setup` to `false` and set this key with remote connection url.                                                                                                                                                                                   |
| postgres.storageClass      | &lt;k8s-default-storage-class&gt; |          | Creating the persitant volumes for the stateful deployments needs the `storageClass` name. Set the correct value as per your kubernetes cluster configuration.                                                                                                                                                                                                                          |
| postgres.assign_cluster_ip |               false               |          | Set it to `true` if you want to assign `ClusterIP` to the service                                                                                                                                                                                                                                                                                                                       |
| postgres.nodeSelector      |                {}                 |          | This key allows you to set the node selector for the stateful deployment of `postgres`. This is useful when you want to run the deployment on specific nodes in your Kubernetes cluster.                                                                                                                                                                                                |
| postgres.tolerations       |                []                 |          | This key allows you to set the tolerations for the stateful deployment of `postgres`. This is useful when you want to run the deployment on nodes with specific taints in your Kubernetes cluster.                                                                                                                                                                                      |
| postgres.affinity          |                {}                 |          | This key allows you to set the affinity rules for the stateful deployment of `postgres`. This is useful when you want to control how pods are scheduled on nodes in your Kubernetes cluster.                                                                                                                                                                                            |
| postgres.labels | {} |  | This key allows you to set custom labels for the stateful deployment of `postgres`. This is useful for organizing and selecting resources in your Kubernetes cluster. |
| postgres.annotations | {} |  | This key allows you to set custom annotations for the stateful deployment of postgres. This is useful for adding metadata or configuration hints to your resources. |

### Redis/Valkey Setup

| Setting                 |              Default              | Required | Description                                                                                                                                                                                                                                                                                                                                                                     |
| ----------------------- | :-------------------------------: | :------: | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| redis.local_setup       |               true                |          | Plane uses `redis` to cache the session authentication and other static data. This database can be hosted within kubernetes as part of helm chart deployment or can be used as hosted service remotely (e.g. aws rds or similar services). Set this to `true` when you choose to setup stateful deployment of `redis`. Mark it as `false` when using a remotely hosted database |
| redis.image             |    valkey/valkey:7.2.5-alpine     |          | Using this key, user must provide the docker image name to setup the stateful deployment of `redis`. (must be set when `redis.local_setup=true`)                                                                                                                                                                                                                                |
| redis.pullPolicy        |           IfNotPresent            |          | Using this key, user can set the pull policy for the stateful deployment of `redis`. (must be set when `redis.local_setup=true`)                                                                                                                                                                                                                                                |
| redis.servicePort       |               6379                |          | This key sets the default port number to be used while setting up stateful deployment of `redis`.                                                                                                                                                                                                                                                                               |
| redis.volumeSize        |                1Gi                |          | While setting up the stateful deployment, while creating the persistant volume, volume allocation size need to be provided. This key helps you set the volume allocation size. Unit of this value must be in Mi (megabyte) or Gi (gigabyte)                                                                                                                                     |
| env.remote_redis_url    |                                   |          | Users can also decide to use the remote hosted database and link to Plane deployment. Ignoring all the above keys, set `redis.local_setup` to `false` and set this key with remote connection url.                                                                                                                                                                              |
| redis.storageClass      | &lt;k8s-default-storage-class&gt; |          | Creating the persitant volumes for the stateful deployments needs the `storageClass` name. Set the correct value as per your kubernetes cluster configuration.                                                                                                                                                                                                                  |
| redis.assign_cluster_ip |               false               |          | Set it to `true` if you want to assign `ClusterIP` to the service                                                                                                                                                                                                                                                                                                               |
| redis.nodeSelector      |                {}                 |          | This key allows you to set the node selector for the stateful deployment of `redis`. This is useful when you want to run the deployment on specific nodes in your Kubernetes cluster.                                                                                                                                                                                           |
| redis.tolerations       |                []                 |          | This key allows you to set the tolerations for the stateful deployment of `redis`. This is useful when you want to run the deployment on nodes with specific taints in your Kubernetes cluster.                                                                                                                                                                                 |
| redis.affinity          |                {}                 |          | This key allows you to set the affinity rules for the stateful deployment of `redis`. This is useful when you want to control how pods are scheduled on nodes in your Kubernetes cluster.                                                                                                                                                                                       |
| redis.labels | {} |  | This key allows you to set custom labels for the stateful deployment of `redis`. This is useful for organizing and selecting resources in your Kubernetes cluster. |
| redis.annotations | {} |  | This key allows you to set custom annotations for the stateful deployment of `redis`. This is useful for adding metadata or configuration hints to your resources. |


### RabbitMQ Setup

| Setting                        |              Default              | Required | Description                                                                                                                                                                                                                                                                                                                                |
| ------------------------------ | :-------------------------------: | :------: | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| rabbitmq.local_setup           |               true                |          | Plane uses `rabbitmq` as message queuing system. This can be hosted within kubernetes as part of helm chart deployment or can be used as hosted service remotely (e.g. aws mq or similar services). Set this to `true` when you choose to setup stateful deployment of `rabbitmq`. Mark it as `false` when using a remotely hosted service |
| rabbitmq.image                 | rabbitmq:3.13.6-management-alpine |          | Using this key, user must provide the docker image name to setup the stateful deployment of `rabbitmq`. (must be set when `rabbitmq.local_setup=true`)                                                                                                                                                                                     |
| rabbitmq.pullPolicy            |           IfNotPresent            |          | Using this key, user can set the pull policy for the stateful deployment of `rabbitmq`. (must be set when `rabbitmq.local_setup=true`)                                                                                                                                                                                                     |
| rabbitmq.servicePort           |               5672                |          | This key sets the default port number to be used while setting up stateful deployment of `rabbitmq`.                                                                                                                                                                                                                                       |
| rabbitmq.managementPort        |               15672               |          | This key sets the default management port number to be used while setting up stateful deployment of `rabbitmq`.                                                                                                                                                                                                                            |
| rabbitmq.volumeSize            |               100Mi               |          | While setting up the stateful deployment, while creating the persistant volume, volume allocation size need to be provided. This key helps you set the volume allocation size. Unit of this value must be in Mi (megabyte) or Gi (gigabyte)                                                                                                |
| rabbitmq.storageClass          | &lt;k8s-default-storage-class&gt; |          | Creating the persitant volumes for the stateful deployments needs the `storageClass` name. Set the correct value as per your kubernetes cluster configuration.                                                                                                                                                                             |
| rabbitmq.default_user          |               plane               |          | Credentials are requried to access the hosted stateful deployment of `rabbitmq`. Use this key to set the username for the stateful deployment.                                                                                                                                                                                             |
| rabbitmq.default_password      |               plane               |          | Credentials are requried to access the hosted stateful deployment of `rabbitmq`. Use this key to set the password for the stateful deployment.                                                                                                                                                                                             |
| rabbitmq.assign_cluster_ip     |               false               |          | Set it to `true` if you want to assign `ClusterIP` to the service                                                                                                                                                                                                                                                                          |
| rabbitmq.external_rabbitmq_url |                                   |          | Users can also decide to use the remote hosted service and link to Plane deployment. Ignoring all the above keys, set `rabbitmq.local_setup` to `false` and set this key with remote connection url.                                                                                                                                       |
| rabbitmq.nodeSelector          |                {}                 |          | This key allows you to set the node selector for the stateful deployment of `rabbitmq`. This is useful when you want to run the deployment on specific nodes in your Kubernetes cluster.                                                                                                                                                   |
| rabbitmq.tolerations           |                []                 |          | This key allows you to set the tolerations for the stateful deployment of `rabbitmq`. This is useful when you want to run the deployment on nodes with specific taints in your Kubernetes cluster.                                                                                                                                         |
| rabbitmq.affinity              |                {}                 |          | This key allows you to set the affinity rules for the stateful deployment of `rabbitmq`. This is useful when you want to control how pods are scheduled on nodes in your Kubernetes cluster.                                                                                                                                               |
| rabbitmq.labels | {} |  | This key allows you to set custom labels for the stateful deployment of `rabbitmq`. This is useful for organizing and selecting resources in your Kubernetes cluster. |
| rabbitmq.annotations | {} |  | This key allows you to set custom annotations for the stateful deployment of `rabbitmq`. This is useful for adding metadata or configuration hints to your resources. |

### Doc Store (Minio/S3) Setup

| Setting                      |              Default              | Required | Description                                                                                                                                                                                                                                                                                                                                              |
| ---------------------------- | :-------------------------------: | :------: | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| minio.local_setup            |               true                |          | Plane uses `minio` as the default file storage drive. This storage can be hosted within kubernetes as part of helm chart deployment or can be used as hosted service remotely (e.g. aws S3 or similar services). Set this to `true` when you choose to setup stateful deployment of `postgres`. Mark it as `false` when using a remotely hosted database |
| minio.image                  |        minio/minio:latest         |          | Using this key, user must provide the docker image name to setup the stateful deployment of `minio`. (must be set when `minio.local_setup=true`)                                                                                                                                                                                                         |
| minio.image_mc               |          minio/mc:latest          |          | Using this key, user must provide the docker image name to setup the job deployment of `minio client`. (must be set when `minio.local_setup=true`)                                                                                                                                                                                              |
| minio.init_image             |              busybox              |          | Using this key, user must provide the docker image name used by the init container of the `minio client` job, which waits for `minio` to become resolvable. (must be set when `minio.local_setup=true`)                                                                                                                                                    |
| minio.pullPolicy             |           IfNotPresent            |          | Using this key, user can set the pull policy for the stateful deployment of `minio`. (must be set when `minio.local_setup=true`)                                                                                                                                                                                                                         |
| minio.volumeSize             |                5Gi                |          | While setting up the stateful deployment, while creating the persistant volume, volume allocation size need to be provided. This key helps you set the volume allocation size. Unit of this value must be in Mi (megabyte) or Gi (gigabyte)                                                                                                              |
| minio.root_user              |               admin               |          | Storage credentials are requried to access the hosted stateful deployment of `minio`. Use this key to set the username for the stateful deployment.                                                                                                                                                                                                      |
| minio.root_password          |             password              |          | Storage credentials are requried to access the hosted stateful deployment of `minio`. Use this key to set the password for the stateful deployment.                                                                                                                                                                                                      |
| minio.env.minio_endpoint_ssl |               false               |          | (Optional) Env to enforce HTTPS when connecting to minio uploads bucket                                                                                                                                                                                                                                                                                  |
| env.docstore_bucket          |              uploads              |   Yes    | Storage bucket name is required as part of configuration. This is where files will be uploaded irrespective of if you are using `Minio` or external `S3` (or compatible) storage service                                                                                                                                                                 |
| env.doc_upload_size_limit    |              5242880              |   Yes    | Document Upload Size Limit (default to 5Mb)                                                                                                                                                                                                                                                                                                              |
| env.aws_access_key           |                                   |          | External `S3` (or compatible) storage service provides `access key` for the application to connect and do the necessary upload/download operations. To be provided when `minio.local_setup=false`                                                                                                                                                        |
| env.aws_secret_access_key    |                                   |          | External `S3` (or compatible) storage service provides `secret access key` for the application to connect and do the necessary upload/download operations. To be provided when `minio.local_setup=false`                                                                                                                                                 |
| env.aws_region               |                                   |          | External `S3` (or compatible) storage service providers creates any buckets in user selected region. This is also shared with the user as `region` for the application to connect and do the necessary upload/download operations. To be provided when `minio.local_setup=false`                                                                         |
| env.aws_s3_endpoint_url      |                                   |          | External `S3` (or compatible) storage service providers shares a `endpoint_url` for the integration purpose for the application to connect and do the necessary upload/download operations. To be provided when `minio.local_setup=false`                                                                                                                |
| minio.storageClass           | &lt;k8s-default-storage-class&gt; |          | Creating the persitant volumes for the stateful deployments needs the `storageClass` name. Set the correct value as per your kubernetes cluster configuration.                                                                                                                                                                                           |
| minio.assign_cluster_ip      |               false               |          | Set it to `true` if you want to assign `ClusterIP` to the service                                                                                                                                                                                                                                                                                        |
| minio.nodeSelector           |                {}                 |          | This key allows you to set the node selector for the stateful deployment of `minio`. This is useful when you want to run the deployment on specific nodes in your Kubernetes cluster.                                                                                                                                                                    |
| minio.tolerations            |                []                 |          | This key allows you to set the tolerations for the stateful deployment of `minio`. This is useful when you want to run the deployment on nodes with specific taints in your Kubernetes cluster.                                                                                                                                                          |
| minio.affinity               |                {}                 |          | This key allows you to set the affinity rules for the stateful deployment of `minio`. This is useful when you want to control how pods are scheduled on nodes in your Kubernetes cluster.                                                                                                                                                                |
| minio.labels | {} |  | This key allows you to set custom labels for the stateful deployment of `minio`. This is useful for organizing and selecting resources in your Kubernetes cluster. |
| minio.annotations | {} |  | This key allows you to set custom annotations for the stateful deployment of `minio`. This is useful for adding metadata or configuration hints to your resources. |


### Web Deployment

| Setting               |                   Default                   | Required | Description                                                                                                                                                                                                     |
| --------------------- | :-----------------------------------------: | :------: | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| web.replicas          |                      1                      |   Yes    | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| web.memoryLimit       |                   1000Mi                    |          | Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.                                                             |
| web.cpuLimit          |                    500m                     |          | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.                                                                   |
| web.memoryRequest     |                    50Mi                     |          | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.                                                           |
| web.cpuRequest        |                     50m                     |          | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.                                                                 |
| web.image             | artifacts.plane.so/makeplane/plane-frontend |          | This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment                                                          |
| web.pullPolicy        |                   Always                    |          | Using this key, user can set the pull policy for the deployment of `web`.                                                                                                                                       |
| web.assign_cluster_ip |                    false                    |          | Set it to `true` if you want to assign `ClusterIP` to the service                                                                                                                                               |
| web.nodeSelector      |                     {}                      |          | This key allows you to set the node selector for the deployment of `web`. This is useful when you want to run the deployment on specific nodes in your Kubernetes cluster.                                      |
| web.tolerations       |                     []                      |          | This key allows you to set the tolerations for the deployment of `web`. This is useful when you want to run the deployment on nodes with specific taints in your Kubernetes cluster.                            |
| web.affinity          |                     {}                      |          | This key allows you to set the affinity rules for the deployment of `web`. This is useful when you want to control how pods are scheduled on nodes in your Kubernetes cluster.                                  |
| web.labels | {} |  | Custom labels to add to the web deployment |
| web.annotations | {} |  | Custom annotations to add to the web deployment |

### Space Deployment

| Setting                 |                 Default                  | Required | Description                                                                                                                                                                                                     |
| ----------------------- | :--------------------------------------: | :------: | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| space.replicas          |                    1                     |   Yes    | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| space.memoryLimit       |                  1000Mi                  |          | Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.                                                             |
| space.cpuLimit          |                   500m                   |          | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.                                                                   |
| space.memoryRequest     |                   50Mi                   |          | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.                                                           |
| space.cpuRequest        |                   50m                    |          | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.                                                                 |
| space.image             | artifacts.plane.so/makeplane/plane-space |          | This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment                                                          |
| space.pullPolicy        |                  Always                  |          | Using this key, user can set the pull policy for the deployment of `space`.                                                                                                                                     |
| space.assign_cluster_ip |                  false                   |          | Set it to `true` if you want to assign `ClusterIP` to the service                                                                                                                                               |
| space.nodeSelector      |                    {}                    |          | This key allows you to set the node selector for the deployment of `space`. This is useful when you want to run the deployment on specific nodes in your Kubernetes cluster.                                    |
| space.tolerations       |                    []                    |          | This key allows you to set the tolerations for the deployment of `space`. This is useful when you want to run the deployment on nodes with specific taints in your Kubernetes cluster.                          |
| space.affinity          |                    {}                    |          | This key allows you to set the affinity rules for the deployment of `space`. This is useful when you want to control how pods are scheduled on nodes in your Kubernetes cluster.                                |
| space.labels | {} |  | Custom labels to add to the space deployment |
| space.annotations | {} |  | Custom annotations to add to the space deployment |

### Admin Deployment

| Setting                 |                 Default                  | Required | Description                                                                                                                                                                                                     |
| ----------------------- | :--------------------------------------: | :------: | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| admin.replicas          |                    1                     |   Yes    | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| admin.memoryLimit       |                  1000Mi                  |          | Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.                                                             |
| admin.cpuLimit          |                   500m                   |          | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.                                                                   |
| admin.memoryRequest     |                   50Mi                   |          | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.                                                           |
| admin.cpuRequest        |                   50m                    |          | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.                                                                 |
| admin.image             | artifacts.plane.so/makeplane/plane-admin |          | This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment                                                          |
| admin.pullPolicy        |                  Always                  |          | Using this key, user can set the pull policy for the deployment of `admin`.                                                                                                                                     |
| admin.assign_cluster_ip |                  false                   |          | Set it to `true` if you want to assign `ClusterIP` to the service                                                                                                                                               |
| admin.nodeSelector      |                    {}                    |          | This key allows you to set the node selector for the deployment of `admin`. This is useful when you want to run the deployment on specific nodes in your Kubernetes cluster.                                    |
| admin.tolerations       |                    []                    |          | This key allows you to set the tolerations for the deployment of `admin`. This is useful when you want to run the deployment on nodes with specific taints in your Kubernetes cluster.                          |
| admin.affinity          |                    {}                    |          | This key allows you to set the affinity rules for the deployment of `admin`. This is useful when you want to control how pods are scheduled on nodes in your Kubernetes cluster.                                |
| admin.labels | {} |  | Custom labels to add to the admin deployment |
| admin.annotations | {} |  | Custom annotations to add to the admin deployment |

### Live Service Deployment

| Setting                |                 Default                 | Required | Description                                                                                                                                                                                                     |
| ---------------------- | :-------------------------------------: | :------: | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| live.replicas          |                    1                    |   Yes    | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| live.memoryLimit       |                 1000Mi                  |          | Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.                                                             |
| live.cpuLimit          |                  500m                   |          | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.                                                                   |
| live.memoryRequest     |                  50Mi                   |          | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.                                                           |
| live.cpuRequest        |                   50m                   |          | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.                                                                 |
| live.image             | artifacts.plane.so/makeplane/plane-live |          | This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment                                                          |
| live.pullPolicy        |                 Always                  |          | Using this key, user can set the pull policy for the deployment of `live`.                                                                                                                                      |
| live.assign_cluster_ip |                  false                  |          | Set it to `true` if you want to assign `ClusterIP` to the service                                                                                                                                               |
| live.nodeSelector      |                   {}                    |          | This key allows you to set the node selector for the deployment of `live`. This is useful when you want to run the deployment on specific nodes in your Kubernetes cluster.                                     |
| live.tolerations       |                   []                    |          | This key allows you to set the tolerations for the deployment of `live`. This is useful when you want to run the deployment on nodes with specific taints in your Kubernetes cluster.                           |
| live.affinity          |                   {}                    |          | This key allows you to set the affinity rules for the deployment of `live`. This is useful when you want to control how pods are scheduled on nodes in your Kubernetes cluster.                                 |
| live_server_secret_key |   htbqvBJAgpm9bzvf3r4urJer0ENReatceh    |   Yes    | This key sets the secret key for the live server. This is required for secure communication and authentication in the live server component.                                                                    |
| live.labels | {} |  | Custom labels to add to the live deployment |
| live.annotations | {} |  | Custom annotations to add to the live deployment |

### API Deployment

| Setting                |                  Default                   | Required | Description                                                                                                                                                                                                     |
| ---------------------- | :----------------------------------------: | :------: | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| api.replicas           |                     1                      |   Yes    | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| api.memoryLimit        |                   1000Mi                   |          | Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.                                                             |
| api.cpuLimit           |                    500m                    |          | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.                                                                   |
| api.memoryRequest      |                    50Mi                    |          | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.                                                           |
| api.cpuRequest         |                    50m                     |          | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.                                                                 |
| api.image              | artifacts.plane.so/makeplane/plane-backend |          | This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment                                                          |
| api.pullPolicy         |                   Always                   |          | Using this key, user can set the pull policy for the deployment of `api`.                                                                                                                                       |
| env.sentry_dsn         |                                            |          | (optional) API service deployment comes with some of the preconfigured integration. Sentry is one among those. Here user can set the Sentry provided DSN for this integration.                                  |
| env.sentry_environment |                                            |          | (optional) API service deployment comes with some of the preconfigured integration. Sentry is one among those. Here user can set the Sentry environment name (as configured in Sentry) for this integration.    |
| env.api_key_rate_limit |                 60/minute                  |          | (optional) User can set the maximum number of requests the API can handle in a given time frame.                                                                                                                |
| api.assign_cluster_ip  |                   false                    |          | Set it to `true` if you want to assign `ClusterIP` to the service                                                                                                                                               |
| api.nodeSelector       |                     {}                     |          | This key allows you to set the node selector for the deployment of `api`. This is useful when you want to run the deployment on specific nodes in your Kubernetes cluster.                                      |
| api.tolerations        |                     []                     |          | This key allows you to set the tolerations for the deployment of `api`. This is useful when you want to run the deployment on nodes with specific taints in your Kubernetes cluster.                            |
| api.affinity           |                     {}                     |          | This key allows you to set the affinity rules for the deployment of `api`. This is useful when you want to control how pods are scheduled on nodes in your Kubernetes cluster.                                  |
| api.labels | {} |  | Custom labels to add to the API deployment |
| api.annotations | {} |  | Custom annotations to add to the API deployment |

### Worker Deployment

| Setting              |                  Default                   | Required | Description                                                                                                                                                                                                     |
| -------------------- | :----------------------------------------: | :------: | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| worker.replicas      |                     1                      |   Yes    | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| worker.memoryLimit   |                   1000Mi                   |          | Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.                                                             |
| worker.cpuLimit      |                    500m                    |          | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.                                                                   |
| worker.memoryRequest |                    50Mi                    |          | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.                                                           |
| worker.cpuRequest    |                    50m                     |          | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.                                                                 |
| worker.image         | artifacts.plane.so/makeplane/plane-backend |          | This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment                                                          |
| worker.nodeSelector  |                     {}                     |          | This key allows you to set the node selector for the deployment of `worker`. This is useful when you want to run the deployment on specific nodes in your Kubernetes cluster.                                   |
| worker.tolerations   |                     []                     |          | This key allows you to set the tolerations for the deployment of `worker`. This is useful when you want to run the deployment on nodes with specific taints in your Kubernetes cluster.                         |
| worker.affinity      |                     {}                     |          | This key allows you to set the affinity rules for the deployment of `worker`. This is useful when you want to control how pods are scheduled on nodes in your Kubernetes cluster.                               |
| worker.labels | {} |  | Custom labels to add to the worker deployment |
| worker.annotations | {} |  | Custom annotations to add to the worker deployment |

### Beat-Worker deployment

| Setting                  |                  Default                   | Required | Description                                                                                                                                                                                                     |
| ------------------------ | :----------------------------------------: | :------: | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| beatworker.replicas      |                     1                      |   Yes    | Kubernetes helps you with scaling up/down the deployments. You can run 1 or more pods for each deployment. This key helps you setting up number of replicas you want to run for this deployment. It must be >=1 |
| beatworker.memoryLimit   |                   1000Mi                   |          | Every deployment in kubernetes can be set to use maximum memory they are allowed to use. This key sets the memory limit for this deployment to use.                                                             |
| beatworker.cpuLimit      |                    500m                    |          | Every deployment in kubernetes can be set to use maximum cpu they are allowed to use. This key sets the cpu limit for this deployment to use.                                                                   |
| beatworker.memoryRequest |                    50Mi                    |          | Every deployment in kubernetes can be set to use minimum memory they are allowed to use. This key sets the memory request for this deployment to use.                                                           |
| beatworker.cpuRequest    |                    50m                     |          | Every deployment in kubernetes can be set to use minimum cpu they are allowed to use. This key sets the cpu request for this deployment to use.                                                                 |
| beatworker.image         | artifacts.plane.so/makeplane/plane-backend |          | This deployment needs a preconfigured docker image to function. Docker image name is provided by the owner and must not be changed for this deployment                                                          |
| beatworker.nodeSelector  |                     {}                     |          | This key allows you to set the node selector for the deployment of `beatworker`. This is useful when you want to run the deployment on specific nodes in your Kubernetes cluster.                               |
| beatworker.tolerations   |                     []                     |          | This key allows you to set the tolerations for the deployment of `beatworker`. This is useful when you want to run the deployment on nodes with specific taints in your Kubernetes cluster.                     |
| beatworker.affinity      |                     {}                     |          | This key allows you to set the affinity rules for the deployment of `beatworker`. This is useful when you want to control how pods are scheduled on nodes in your Kubernetes cluster.                           |
| beatworker.labels | {} |  | Custom labels to add to the beat-worker deployment |
| beatworker.annotations | {} |  | Custom annotations to add to the beat-worker deployment |

### Ingress and SSL Setup

| Setting                     |                          Default                          | Required | Description                                                                                                                                                                                                                                                                                                                                                                                                               |
| --------------------------- | :-------------------------------------------------------: | :------: | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ingress.enabled             |                           true                            |          | Ingress setup in kubernetes is a common practice to expose application to the intended audience. Set it to `false` if you are using external ingress providers like `Cloudflare`                                                                                                                                                                                                                                          |
| ingress.appHost             |                     plane.example.com                     |   Yes    | The fully-qualified domain name (FQDN) in the format `sudomain.domain.tld` or `domain.tld` that the license is bound to. It is also attached to your `ingress` host to access Plane.                                                                                                                                                                                                                                      |
| ingress.minioHost           |                                                           |          | Based on above configuration, if you want to expose the `minio` web console to set of users, use this key to set the `host` mapping or leave it as `EMPTY` to not expose interface.                                                                                                                                                                                                                                       |
| ingress.rabbitmqHost        |                                                           |          | Based on above configuration, if you want to expose the `rabbitmq` web console to set of users, use this key to set the `host` mapping or leave it as `EMPTY` to not expose interface.                                                                                                                                                                                                                                    |
| ingress.ingressClass        |                          traefik                          |   Yes    | Set to `traefik` (or a name starting with `traefik`) to use native Traefik `IngressRoute` CRDs. Set to `nginx` (or any other class) to use a standard `networking.k8s.io/v1 Ingress` resource. |
| ingress.ingress_annotations | `{ "nginx.ingress.kubernetes.io/proxy-body-size": "5m" }` |          | Annotations applied to the standard `Ingress` resource. **Only used when `ingressClass` is not `traefik`.** When Traefik is selected, use `ingress.traefik.maxRequestBodyBytes` to control request body size instead. |
| ingress.traefik.maxRequestBodyBytes | `5242880` |          | Maximum allowed request body size in bytes for Traefik's buffering middleware (default: 5 MiB). Only used when `ingressClass` starts with `traefik`. |
| ssl.createIssuer            |                           false                           |          | Kubernets cluster setup supports creating `issuer` type resource. After deployment, this is step towards creating secure access to the ingress url. Issuer is required for you generate SSL certifiate. Kubernetes can be configured to use any of the certificate authority to generate SSL (depending on CertManager configuration). Set it to `true` to create the issuer. Applicable only when `ingress.enabled=true` |
| ssl.issuer                  |                           http                            |          | CertManager configuration allows user to create issuers using `http` or any of the other DNS Providers like `cloudflare`, `digitalocean`, etc. As of now Plane supports `http`, `cloudflare`, `digitalocean`                                                                                                                                                                                                              |
| ssl.token                   |                                                           |          | To create issuers using DNS challenge, set the issuer api token of dns provider like cloudflare`or`digitalocean`(not required for http)                                                                                                                                                                                                                                                                                   |
| ssl.server                  |     <https://acme-v02.api.letsencrypt.org/directory>      |          | Issuer creation configuration need the certificate generation authority server url. Default URL is the `Let's Encrypt` server                                                                                                                                                                                                                                                                                             |
| ssl.email                   |                    <plane@example.com>                    |          | Certificate generation authority needs a valid email id before generating certificate. Required when `ssl.createIssuer=true`                                                                                                                                                                                                                                                                                              |
| ssl.generateCerts           |                           false                           |          | After creating the issuers, user can still not create the certificate untill sure of configuration. Setting this to `true` will try to generate SSL certificate and associate with ingress. Applicable only when `ingress.enabled=true` and `ssl.createIssuer=true`                                                                                                                                                       |
| ssl.tls_secret_name         |                                                           |          | If you have a custom TLS secret name, set this to the name of the secret. Applicable only when `ingress.enabled=true` and `ssl.createIssuer=false`                                                                                                                                                                                                                                                                        |
| ssl.externalTermination     |                           false                           |          | Set `true` when TLS is terminated **in front of** Plane and this chart manages no certificate — a cloud load balancer, Cloudflare, a service mesh, or a Traefik entrypoint carrying its own cert. Renders `WEB_URL` as `https://` and emits **no** `tls:` block. Does not move the Traefik entrypoint; see [TLS options](#tls-options-choosing-how-https-is-handled) options 4a/4b. |
| ingress.traefik.entryPoints |                           `[]`                            |          | Traefik entrypoints the `IngressRoute`s attach to. Empty (default) derives them from your TLS settings: `websecure` when this chart terminates TLS, otherwise `web`. Set explicitly if your Traefik renamed the defaults, to serve both schemes, or to select `websecure` for option 4b. A bare string is accepted. **Only used when `ingressClass` starts with `traefik`.** |

#### Using Traefik as the ingress controller

When `ingress.ingressClass` starts with `traefik`, the chart deploys native Traefik CRDs instead of a standard `Ingress` resource:

- **`IngressRoute`** (`traefik.io/v1alpha1`) — routes traffic to each Plane service via `Host` + `PathPrefix` rules, on the entrypoint derived from your TLS settings (see [TLS options](#tls-options-choosing-how-https-is-handled))
- **`Middleware`** (`traefik.io/v1alpha1`) — enforces a request body size limit on every route (default 5 MiB, configurable via `ingress.traefik.maxRequestBodyBytes`)

This requires the Traefik Helm chart to be installed with `providers.kubernetesCRD.enabled=true` (enabled by default in Traefik v3), as shown in the pre-requisites above.

**Switching between controllers**

```yaml
# Traefik — uses native IngressRoute CRDs
ingress:
  ingressClass: 'traefik'

# nginx — uses standard networking.k8s.io/v1 Ingress
ingress:
  ingressClass: 'nginx'
```

#### TLS options: choosing how HTTPS is handled

TLS is **optional**. Your `ssl.*` settings drive two *separate* derivations —
separate because "users are on HTTPS" and "this chart holds the certificate" are
different facts:

1. whether a `tls:` block is emitted, and which Traefik entrypoint the
   `IngressRoute`s bind to — both from whether **this chart** terminates TLS;
2. the scheme of `WEB_URL`, the URL Plane is told about itself.
   (`CORS_ALLOWED_ORIGINS` always lists both schemes and is unaffected.)

Find the row that matches your environment:

| Your setup | Set | Entrypoint | `tls:` block | `WEB_URL` |
| --- | --- | :---: | :---: | :---: |
| No certificate yet — trial, internal network | *nothing* (default) | `web` | — | `http://` |
| You already hold a TLS Secret | `ssl.tls_secret_name` | `websecure` | your Secret | `https://` |
| Let cert-manager issue one | `ssl.createIssuer` + `ssl.generateCerts` | `websecure` | `<release>-ssl-cert` | `https://` |
| TLS terminated upstream (ALB, NLB TLS listener, Cloudflare) | `ssl.externalTermination: true` | `web` | — | `https://` |
| TLS terminated by Traefik's own entrypoint | `ssl.externalTermination: true` + `ingress.traefik.entryPoints: ['websecure']` | `websecure` | — | `https://` |

Only the `tls:` block requires a Secret this chart can actually see, which is why
the last two rows emit none — the chart never names a Secret it does not create.

Note the last two rows share a scheme but need **opposite entrypoints**: an
upstream terminator forwards cleartext, which arrives on `web`, whereas a Traefik
entrypoint carrying its own certificate serves TLS on `websecure`. That is why
`ssl.externalTermination` sets the URL scheme only and never moves the
entrypoint.

All three `IngressRoute`s the chart can emit — the app, the MinIO console
(`ingress.minioHost`) and the RabbitMQ console (`ingress.rabbitmqHost`) — follow
the same derivation.

##### Option 1 — No TLS, plain HTTP

The default. Nothing to set; leave the `ssl` block alone:

```yaml
ingress:
  enabled: true
  ingressClass: traefik
  appHost: plane.example.com
```

Renders `entryPoints: ['web']`, no `tls:` block, and `WEB_URL: "http://plane.example.com"`.
Good for a trial, an internal network, or while you are still sorting out DNS and
certificates. See the [caveat](#caveat-check-your-traefik-entrypoints-before-relying-on-plain-http)
below before relying on it.

##### Option 2 — Bring your own certificate

You already hold a `kubernetes.io/tls` Secret in the release namespace:

```yaml
ssl:
  tls_secret_name: 'my-tls-secret'
```

Renders `entryPoints: ['websecure']`, `tls.secretName: my-tls-secret`, and
`WEB_URL: "https://..."`.

##### Option 3 — Let cert-manager issue the certificate

Requires cert-manager installed in the cluster and a publicly-resolvable host if
you use the HTTP-01 challenge:

```yaml
ssl:
  createIssuer: true
  generateCerts: true
  issuer: http            # or cloudflare / digitalocean for DNS-01
  email: you@example.com
```

The chart creates an `Issuer` and a `Certificate`, cert-manager writes
`<release>-ssl-cert`, and the routes reference it. **Both** `createIssuer` and
`generateCerts` are required — `generateCerts` alone creates nothing and is
treated as "no TLS".

For DNS-01 also set `ssl.token` to your provider API token. To test without
burning Let's Encrypt rate limits, point at staging first:

```yaml
ssl:
  server: https://acme-staging-v02.api.letsencrypt.org/directory
```

##### Option 4 — TLS terminated in front of Plane

Use this when something ahead of Plane already terminates TLS and this chart
manages no certificate. `ssl.externalTermination` renders `WEB_URL` as `https://`
and emits no `tls:` block. It does **not** move the entrypoint, so pick the
sub-case that matches where TLS actually ends.

**4a — an upstream terminator forwards cleartext** (ALB with an ACM cert, NLB
with a TLS listener, Cloudflare, most service meshes). Traffic reaches Traefik as
plain HTTP, so the routes stay on `web` — the default:

```yaml
ssl:
  externalTermination: true
```

**4b — Traefik's own entrypoint terminates TLS** (`websecure.http.tls=true`, an
ACME `certResolver`, or a default `TLSStore`). Traffic reaches Traefik as TLS, so
the routes must bind `websecure` as well:

```yaml
ssl:
  externalTermination: true
ingress:
  traefik:
    entryPoints: ['websecure']
```

Getting the sub-case wrong is a routing failure, not a certificate failure: a
route bound only to `websecure` never matches cleartext arriving on `web`, so
requests 404 instead of reaching Plane.

Leave `externalTermination` `false` if you set `ssl.tls_secret_name` or
`ssl.generateCerts`; those already imply HTTPS. Use it *only* for TLS this chart
cannot see. Without it, such an install would advertise `http://` to itself while
being served over HTTPS, breaking OAuth callbacks and asset links.

##### Overriding the entrypoint names

Only needed if your Traefik installation renamed the default `web` / `websecure`
entrypoints, or you want to serve both schemes at once:

```yaml
ingress:
  traefik:
    entryPoints: ['websecure', 'web']   # a bare string also works
```

Leave it empty (the default) to derive the entrypoint from the table above. This
setting controls the entrypoint *only* — whether a `tls:` block is emitted still
follows your `ssl.*` configuration. It is also how you select `websecure` for
option 4b, where TLS ends at Traefik itself.

##### Caveat: check your Traefik entrypoints before relying on plain HTTP

Many Traefik installations redirect `web` to HTTPS in Traefik's own static
configuration:

```text
--entryPoints.web.http.redirections.entryPoint.to=:443
--entryPoints.web.http.redirections.entryPoint.scheme=https
--entryPoints.websecure.http.tls=true
```

Check yours with:

```bash
kubectl get deploy -n <traefik-ns> <traefik-deployment> \
  -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\n' | grep -i redirect
```

If the redirection is present, every plain-HTTP request is answered with a
permanent redirect *before* it reaches a route, so Option 1 cannot serve Plane on
that cluster. Either drop the redirection, or use Option 2/3/4.

##### A note on nginx (`ingress.ingressClass: nginx`)

The `ssl.*` settings above drive the standard `Ingress` path too — everything in
the table applies except the **Entrypoint** column, which is Traefik-only:

- Options 2 and 3 emit the `Ingress` `tls:` block, exactly as before.
- Option 4 (`ssl.externalTermination`) emits **no** `tls:` block and only sets
  the URL scheme — which is what you want when an ALB, an NLB TLS listener, or
  nginx-ingress in front of Plane holds the certificate.

```yaml
ingress:
  ingressClass: nginx
  ingress_annotations: { "nginx.ingress.kubernetes.io/proxy-body-size": "5m" }
ssl:
  externalTermination: true    # ALB/NLB/Cloudflare terminates; no Secret here
```

> **Known issue, unrelated to TLS:** `ingress.ingress_annotations` is commented
> out in the shipped `values.yaml`, and the `Ingress` template calls `len` on it,
> so `ingressClass: nginx` fails to render with
> `error calling len: len of nil pointer` unless you set at least one annotation.
> Passing any annotation — as above — works around it.

##### Upgrading from 1.6.3 or earlier

Two changes to be aware of.

**1. `WEB_URL` now follows your TLS configuration.** Earlier releases hardcoded
`WEB_URL: "http://<appHost>"` regardless of `ssl.*`, so a TLS-configured install
served Plane over HTTPS while telling the app it lived at `http://`. It is now
`https://` whenever TLS is in effect (options 2, 3 and 4). If you worked around
the old behaviour by overriding `WEB_URL` downstream, drop the override.

**2. The Traefik routes no longer force TLS.** Earlier releases always bound all
three `IngressRoute`s to `websecure` and always emitted a `tls:` block, even when
no certificate was configured — pointing at a `<release>-ssl-cert` Secret that
was never created, so Traefik fell back to its built-in self-signed certificate.
If you relied on that, or on TLS terminated at Traefik itself, adopt Option 4b:

```yaml
ssl:
  externalTermination: true
ingress:
  traefik:
    entryPoints: ['websecure']
```

If you configure TLS through `ssl.tls_secret_name` or `ssl.generateCerts` +
`ssl.createIssuer`, the rendered ingress is unchanged and only `WEB_URL` moves.

### Common Environment Settings

| Setting                    |                      Default                       | Required | Description                                                                                                                                                                      |
| -------------------------- | :------------------------------------------------: | :------: | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| env.secret_key             | 60gp0byfz2dvffa45cxl20p1scy9xbpf6d8c5y0geejgkyp1b5 |   Yes    | This must a random string which is used for hashing/encrypting the sensitive data within the application. Once set, changing this might impact the already hashed/encrypted data |
| env.default_cluster_domain |                   cluster.local                    |   Yes    | Set this value as configured in your kubernetes cluster. `cluster.local` is usally the default in most cases.                                                                    |

## External Secrets Config

To configure the external secrets for your application, you need to define specific environment variables for each secret category. Below is a list of the required secrets and their respective environment variables.

| Secret Name              | Env Var Name            | Required                                | Description                                 | Example Value                                                                                                                                                                                        |
| ------------------------ | :---------------------- | :-------------------------------------- | :------------------------------------------ | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| rabbitmq_existingSecret  | `RABBITMQ_DEFAULT_USER` | Required if `rabbitmq.local_setup=true` | The default RabbitMQ user                   | `plane`                                                                                                                                                                                              |
|                          | `RABBITMQ_DEFAULT_PASS` | Required if `rabbitmq.local_setup=true` | The default RabbitMQ password               | `plane`                                                                                                                                                                                              |
| pgdb_existingSecret      | `POSTGRES_PASSWORD`     | Required if `postgres.local_setup=true` | Password for PostgreSQL database            | `plane`                                                                                                                                                                                              |
|                          | `POSTGRES_DB`           | Required if `postgres.local_setup=true` | Name of the PostgreSQL database             | `plane`                                                                                                                                                                                              |
|                          | `POSTGRES_USER`         | Required if `postgres.local_setup=true` | PostgreSQL user                             | `plane`                                                                                                                                                                                              |
| doc_store_existingSecret | `USE_MINIO`             | Yes                                     | Flag to enable MinIO as the storage backend | `1`                                                                                                                                                                                                  |
|                          | `MINIO_ROOT_USER`       | Yes                                     | MinIO root user                             | `admin`                                                                                                                                                                                              |
|                          | `MINIO_ROOT_PASSWORD`   | Yes                                     | MinIO root password                         | `password`                                                                                                                                                                                           |
|                          | `AWS_ACCESS_KEY_ID`     | Yes                                     | AWS Access Key ID                           | `your_aws_key`                                                                                                                                                                                       |
|                          | `AWS_SECRET_ACCESS_KEY` | Yes                                     | AWS Secret Access Key                       | `your_aws_secret`                                                                                                                                                                                    |
|                          | `AWS_S3_BUCKET_NAME`    | Yes                                     | AWS S3 Bucket Name                          | `your_bucket_name`                                                                                                                                                                                   |
|                          | `AWS_S3_ENDPOINT_URL`   | Yes                                     | Endpoint URL for AWS S3 or MinIO            | `http://plane-minio.plane-ns.svc.cluster.local:9000`                                                                                                                                                 |
|                          | `AWS_REGION`            | Optional                                | AWS region where your S3 bucket is located  | `your_aws_region`                                                                                                                                                                                    |
|                          | `FILE_SIZE_LIMIT`       | Yes                                     | Limit for file uploads in your system       | `5MB`                                                                                                                                                                                                |
| app_env_existingSecret   | `SECRET_KEY`            | Yes                                     | Random secret key                           | `60gp0byfz2dvffa45cxl20p1scy9xbpf6d8c5y0geejgkyp1b5`                                                                                                                                                 |
|                          | `REDIS_URL`             | Yes                                     | Redis URL                                   | `redis://plane-redis.plane-ns.svc.cluster.local:6379/`                                                                                                                                               |
|                          | `DATABASE_URL`          | Yes                                     | PostgreSQL connection URL                   | **k8s service example**: `postgresql://plane:plane@plane-pgdb.plane-ns.svc.cluster.local:5432/plane` <br> <br>**external service example**: `postgresql://username:password@your-db-host:5432/plane` |
|                          | `AMQP_URL`              | Yes                                     | RabbitMQ connection URL                     | **k8s service example**: `amqp://plane:plane@plane-rabbitmq.plane-ns.svc.cluster.local:5672/` <br> <br> **external service example**: `amqp://username:password@your-rabbitmq-host:5672/`            |
| live_env_existingSecret  | `REDIS_URL`             | Yes                                     | Redis URL                                   | `redis://plane-redis.plane-ns.svc.cluster.local:6379/`                                                                                                                                               |

## Custom Ingress Routes

If you are planning to use 3rd party ingress providers, here is the available route configuration

| Host                    |     Path     | Service                                 | Required                                                                    |
| ----------------------- | :----------: | --------------------------------------- | :-------------------------------------------------------------------------- |
| plane.example.com       |      /       | <http://plane-app-web.plane:3000>       | Yes                                                                         |
| plane.example.com       |  /spaces/\*  | <http://plane-app-space.plane:3000>     | Yes                                                                         |
| plane.example.com       | /god-mode/\* | <http://plane-app-admin.plane:3000>     | Yes                                                                         |
| plane.example.com       |   /live/\*   | <http://plane-app-live.plane:3000>      | Yes                                                                         |
| plane.example.com       |   /api/\*    | <http://plane-app-api.plane:8000>       | Yes                                                                         |
| plane.example.com       |   /auth/\*   | <http://plane-app-api.plane:8000>       | Yes                                                                         |
| plane.example.com       | /uploads/\*  | <http://plane-app-minio.plane:9000>     | Yes (Only if using local setup)                                             |
| plane-minio.example.com |      /       | <http://plane-app-minio.plane:9090>     | (Optional) if using local setup, this will enable minio console access      |
| plane-mq.example.com    |      /       | <http://plane-app-rabbitmq.plane:15672> | (Optional) if using local setup, this will enable management console access |
