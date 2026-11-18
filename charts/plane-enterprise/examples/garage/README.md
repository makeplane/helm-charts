# Use Garage as Plane's object store on Kubernetes (self-managed)

The Plane charts bundle MinIO as the object store for attachments, images, avatars, covers and exports.
This directory shows how to run [Garage](https://garagehq.deuxfleurs.fr), a lightweight S3-compatible store,
next to Plane instead, and how to copy your existing files into it.

> **You run Garage, not Plane.** Garage is not part of the Plane charts: installing, upgrading, backing up,
> monitoring and securing it is your responsibility. Plane uses it as any S3-compatible store, through the
> chart's existing external-storage settings, so no chart change is needed. A managed store such as
> Amazon S3 or Google Cloud Storage remains the recommended option for production.

| File | Purpose |
|---|---|
| `garage-values.yaml` | Values for Garage's own Helm chart: 3 nodes, every object stored on all three |
| `copy-minio-to-garage.yaml` | A one-off Job that copies Plane's MinIO bucket into Garage and verifies it |
| `plane-values.yaml` | The Plane values that switch to Garage |

The examples assume Plane is installed as release `plane` in namespace `plane`, and Garage goes in
namespace `garage`. Adjust the names to yours.

## How Plane reaches Garage

**plane-enterprise:** set `env.use_storage_proxy: true`. Plane's API then carries every upload and download,
so Garage stays private inside the cluster, with no ingress and no CORS. The cost is that file bytes now
flow through the API pods, so size them for your upload traffic.

**plane-ce** has no storage proxy, so browsers talk to the object store directly. Expose Garage's S3 API on an
ingress with TLS (`ingress.s3.api` in `garage-values.yaml`), set `env.aws_s3_endpoint_url` to that public URL,
and add a CORS rule on the bucket allowing your Plane origin to `GET`, `PUT`, `POST` and `HEAD`.
`plane-ce` uses `minio.local_setup` and `env.*` at the top level, rather than under `services`.

## 1. Install Garage

Garage's chart is installed from its source repository:

```sh
git clone --depth 1 --branch v2.4.1 https://github.com/deuxfleurs-org/garage.git   # GitHub mirror; pin the tag matching image.tag
helm install garage ./garage/script/helm/garage -n garage --create-namespace \
  -f garage-values.yaml --set garage.rpcSecret="$(openssl rand -hex 32)"
kubectl -n garage rollout status statefulset/garage
```

Keep the RPC secret, for example in a Secret referenced by `garage.existingRpcSecret`: every node must use
the same one.

## 2. Bring the Garage cluster up

Each node joins with no role. Give every node a role, then apply the layout:

```sh
alias garage='kubectl -n garage exec garage-0 -- /garage'
garage status                                    # lists the node IDs
garage layout assign -z dc1 -c 50G <node-id>     # once per node; -c is the capacity it offers
garage layout apply --version 1
```

`garage status` should now show all three nodes with zone `dc1` and a capacity.

## 3. Create Plane's key and bucket

```sh
garage key create plane          # prints the Key ID (GK…) and the Secret key: keep both
garage bucket create uploads     # use your env.docstore_bucket
garage bucket allow --read --write --owner uploads --key plane
```

Keep the secret key safe. Garage shows it only once.

## 4. Copy your files from MinIO

Skip this step on a new installation.

1. Fill in the Secret at the top of `copy-minio-to-garage.yaml`.
   - The MinIO user and password are your `services.minio.root_user` and `root_password`. Read them from
     the cluster with:
     ```sh
     kubectl -n plane get secret plane-doc-store-secrets -o jsonpath='{.data.MINIO_ROOT_USER}' | base64 -d
     kubectl -n plane get secret plane-doc-store-secrets -o jsonpath='{.data.MINIO_ROOT_PASSWORD}' | base64 -d
     ```
   - The Garage key is the one from step 3.
2. Run a first copy while Plane is still up:
   ```sh
   kubectl -n plane apply -f copy-minio-to-garage.yaml
   kubectl -n plane logs -f job/plane-minio-to-garage
   ```
   It ends with `OK: N objects in Garage, names and sizes identical`.
3. Stop Plane's application so nothing new is written to MinIO, and leave MinIO itself running:
   ```sh
   kubectl -n plane scale deployment --all --replicas=0
   ```
4. Run the Job again for the final pass. It copies only what changed since the first pass:
   ```sh
   kubectl -n plane delete job plane-minio-to-garage
   kubectl -n plane apply -f copy-minio-to-garage.yaml
   kubectl -n plane wait --for=condition=complete job/plane-minio-to-garage --timeout=1h
   ```

The Job only reads from MinIO. If it fails partway, run it again: objects already in Garage are skipped. Set
`VERIFY_CONTENT: "1"` in the Secret to also compare the SHA-256 of every object. If the bucket allowed
anonymous reads, the Job prints a warning: links that very old Plane releases saved as plain `/uploads/<file>`
addresses won't load from Garage.

## 5. Switch Plane to Garage

Merge `plane-values.yaml` into your values, filling in the Garage key from step 3. Prefer
`external_secrets.storage` over plain values. Then upgrade:

```sh
helm upgrade plane makeplane/plane-enterprise -n plane -f your-values.yaml
```

This scales your application back up and removes the bundled MinIO StatefulSet. Its PersistentVolumeClaim
(`pvc-plane-minio-vol-plane-minio-wl-0`) is kept, so your old files stay where they were.

## 6. Check it works

- Open older content: work-item attachments, images in descriptions and pages, project covers, workspace
  logos and profile pictures.
- Upload a new file and open it.

## Roll back

Set `services.minio.local_setup: true` again and remove the storage values you added, then
`helm upgrade` (or `helm rollback`). MinIO comes back on its retained volume. Files uploaded while Plane used
Garage exist only in Garage: to keep them, run the copy Job with source and destination swapped before you
switch back.

Once you're confident in Garage, delete the old MinIO volume:

```sh
kubectl -n plane delete pvc pvc-plane-minio-vol-plane-minio-wl-0
```

## Operating Garage

- **Redundancy:** with `replicationFactor: "3"`, every object is on all three nodes, and the cluster
  survives the loss of one node. Spread the pods across nodes or zones, for example with affinity rules in
  the Garage chart, or two copies can share a machine.
- **Backups:** Garage takes a metadata snapshot every 6 hours (`metadataAutoSnapshotInterval`). Take one
  on demand with `garage meta snapshot --all`. Replication protects against a lost node, not against
  deleted data, so back up the volumes too.
- **Health:** `garage status` should list every node as healthy. Run
  `garage repair --yes scrub start` periodically to verify stored blocks.
- **Capacity:** each node stores a full copy at replication factor 3, so watch each data volume. To grow,
  enlarge the volumes, raise the node capacities with `garage layout assign`, and run `garage layout apply`.
- **Upgrades:** read Garage's release notes, then `helm upgrade` the Garage release with the new
  `image.tag`.
- **Key rotation:** create a new key, grant it access to the bucket, update Plane's values or secret,
  then delete the old key.
- **Region:** `garage.s3.api.region` must equal Plane's `env.aws_region`, or uploads fail with
  `AuthorizationHeaderMalformed`.
