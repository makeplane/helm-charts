# Upgrade Guide — Plane CE Helm Chart

## Migrating `ingress.ingressClass` to a concrete controller name

### Background

The chart selects between two ingress templates based on `ingress.ingressClass`:

| `ingressClass` value          | Template rendered                        | Resource kind                       |
| ----------------------------- | ---------------------------------------- | ----------------------------------- |
| `traefik` (or starts with it) | `templates/ingress-traefik.yaml`         | `traefik.io/v1alpha1 IngressRoute`  |
| Any other value (e.g. `nginx`)| `templates/ingress.yaml`                 | `networking.k8s.io/v1 Ingress`      |

The default value is `"traefik"`. If you previously relied on the implicit default without setting `ingressClass` explicitly, your cluster is running Traefik `IngressRoute` CRDs.

### Migrating from Traefik to a standard Ingress controller (e.g. nginx)

1. **Install your target ingress controller** if it is not already running (see the Pre-requisites section in [README.md](README.md)).

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

   After the upgrade:
   - The `IngressRoute`, `Middleware`, and (if enabled) RBAC resources created by the Traefik template are **no longer rendered** and will be orphaned — delete them manually:

     ```bash
     kubectl delete ingressroute  -n plane-ce -l app.kubernetes.io/instance=plane-app
     kubectl delete middleware     -n plane-ce -l app.kubernetes.io/instance=plane-app
     # If createSecretReadRBAC was true:
     kubectl delete role,rolebinding -n plane-ce -l app.kubernetes.io/instance=plane-app
     ```

   - A new `networking.k8s.io/v1 Ingress` resource is created and managed by Helm going forward.

4. **Verify** that the new `Ingress` is admitted and routes traffic before removing the old Traefik resources.

### Migrating from a standard Ingress controller to Traefik

1. **Install Traefik** with CRD support enabled (see Pre-requisites in [README.md](README.md)).

2. **Update `ingress.ingressClass`**:

   ```yaml
   ingress:
     ingressClass: "traefik"
   ```

3. **Run `helm upgrade`**. The old `Ingress` resource is orphaned — delete it:

   ```bash
   kubectl delete ingress -n plane-ce <release-name>-ingress
   ```

4. If Traefik needs permission to read TLS secrets from the release namespace, also set:

   ```yaml
   ingress:
     traefik:
       createSecretReadRBAC: true
   ```

### Key values that control template selection

| Value                      | Default    | Effect                                                                                           |
| -------------------------- | ---------- | ------------------------------------------------------------------------------------------------ |
| `ingress.enabled`          | `true`     | Master switch — set to `false` to render neither template.                                       |
| `ingress.appHost`          | _(empty)_  | Required for both templates; no ingress is rendered without it.                                  |
| `ingress.ingressClass`     | `traefik`  | Selects which template is active (see table above).                                              |
| `ingress.traefik.*`        | see values | Traefik-only settings (middleware body limit, RBAC). Ignored when using the standard `Ingress`.  |
| `ingress.ingress_annotations` | `{}`    | Standard `Ingress` annotations. Ignored when `ingressClass` starts with `traefik`.              |
