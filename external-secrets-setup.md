# External Secrets Setup

## Using AWS Secret Manager

### Create AWS IAM User

- Create a new user e.g `external-secret-access-user`.
- Generate security credentials. You do not need to provide Console Access.
- Keep the `ARN` handy with you.

### Create AWS IAM Policy

In the below example, we are saving this policy as `external-secret-access-policy`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds"
      ],
      "Resource": [
        "arn:aws:secretsmanager:<REGION>:<ACCOUNT-ID>:secret:*"
      ]
    }
  ]
}
```

### Create AWS IAM Role

In the below example, we are saving this role as `external-secret-access-role`

Use the AWS IAM User ARN and replace it below

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "<IAM-USER-ARN>"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```

While creating this role, you need to select the previously saved policy `external-secret-access-policy`

### Create AWS Secrets

> As an example, we are creating **RABBITMQ** Secrets

| KEY | Value |
| --- | --- |
| RABBITMQ_DEFAULT_USER | plane |
| RABBITMQ_DEFAULT_PASS | plane123 |

Save it as e.g `prod/secrets/rabbitmq`

NOTE: The secret with AWS Credentials needs to be created in the particular application namespace

```sh
kubectl create secret generic aws-creds-secret \
  --from-literal=access-key=<AWS_ACCESS_KEY_ID> \
  --from-literal=secret-access-key=<AWS_SECRET_ACCESS_KEY> \
  -n <application_namespace>
```

### Create ClusterSecretStore

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: cluster-aws-secretsmanager
spec:
  provider:
    aws:
      service: SecretsManager
      role: arn:aws:iam::<ACCOUNT-ID>:role/<IAM ROLE>
      region: eu-west-1
      auth:
        secretRef:
          accessKeyIDSecretRef:
            name: aws-creds-secret
            key: access-key
          secretAccessKeySecretRef:
            name: aws-creds-secret
            key: secret-access-key
```

### Create ExternalSecret

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: secret
  namespace: <application_namespace>
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: cluster-aws-secretsmanager # ClusterSecretStore name
    kind: ClusterSecretStore
  target:
    name: rabbitmq-secret # Target Kubernetes secret name
    creationPolicy: Owner
  data:
    - secretKey: RABBITMQ_DEFAULT_USER # Specifies the key name for the secret value in the Kubernetes secret.
      remoteRef:
        key: prod/secrets/rabbitmq # Specifies the name to the secret in the AWS Secrets Manager
        property: RABBITMQ_DEFAULT_USER # Specifies the name of the secret property to retrieve from the AWS Secrets Manager
    - secretKey: RABBITMQ_DEFAULT_PASS
      remoteRef:
        key: prod/secrets/rabbitmq
        property: RABBITMQ_DEFAULT_PASS
```

In this way, please make sure to set all [environment variables ](https://github.com/makeplane/helm-charts/blob/e4ee1f26ab4e1f4c1a1703e1dc459fdca7171a43/charts/plane-ce/README.md#external-secrets-config) related to the plane application in the AWS Secrets Manager, and access them using the `ExternalSecret` resource.

## Using Hashicorp Vault

### Create the kv secrets engine

 Create the `rabbitmq-secret` using the Vault CLI or the Vault UI.

**Using the Vault UI:**

Access the Vault UI at https://&lt;vault-domain&gt;/.

In the Secrets Engines section, setup a new KV secrets engine.

Navigate to the KV secrets engine and create a new secret (eg. `secrets/rabbitmq_secrets` ).

\
Add the following keys and their respective values: 

> *Below values just for reference only considering RABBITMQ secret*

| KEY | Value |
| --- | --- |
| RABBITMQ_DEFAULT_USER | plane |
| RABBITMQ_DEFAULT_PASS | plane123 |

NOTE: The secret with the Vault token needs to be created in the particular **application_namespace**.

```sh
kubectl create secret generic vault-token -n <application_namespace> --from-literal=token=<VAULT-TOKEN>
```

### Create ClusterSecretStore

```yaml
#  cluster-store.yaml 
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore 
metadata:
  name: vault-backend
spec:
  provider:
    vault: 
      server: "https://<vault-domain>" #the address of your vault instance
      path: "secrets" #path for accessing the secrets
      version: "v2" #Vault API version
      auth:
        tokenSecretRef:
          name: "vault-token" #Use a k8s secret called vault-token
          key: "token" #Use this key to access the vault token
```

### Create ExternalSecret

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: rabbitmq-external-secrets
  namespace: <application_namespace> # application-namespace
spec:
  refreshInterval: "1m" 
  secretStoreRef:
    name: vault-backend # ClusterSecretStore name
    kind: ClusterSecretStore
  target: 
    name: rabbitmq-secret # Target Kubernetes secret name
    creationPolicy: Owner 
  data: 
    - secretKey: RABBITMQ_DEFAULT_USER # Specifies the key name for the secret value stored in the Kubernetes secret.
      remoteRef:
        key: secrets/data/rabbitmq_secrets # Specifies the name to the secret in the Vault secret store.
        property: RABBITMQ_DEFAULT_USER # Specifies the name of the secret property to retrieve from the Vault secret store.
    - secretKey: RABBITMQ_DEFAULT_PASS
      remoteRef:
        key: secrets/data/rabbitmq_secrets
        property: RABBITMQ_DEFAULT_PASS
```

In this way, please make sure to set all [environment variables ](https://github.com/makeplane/helm-charts/blob/e4ee1f26ab4e1f4c1a1703e1dc459fdca7171a43/charts/plane-ce/README.md#external-secrets-config)related to the plane application in the Vault, and access them using the `ExternalSecret` resource.
