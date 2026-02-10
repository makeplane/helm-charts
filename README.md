# Plane Helm Charts

This repository contains the official Helm charts for deploying Plane on Kubernetes. The charts are maintained by the Plane team and are intended to provide a consistent, production-ready installation experience across common Kubernetes environments.

Each chart includes defaults, is configurable via `values.yaml`, and follows standard Helm conventions to support repeatable upgrades, rollbacks, and environment-specific customization. For deployment prerequisites, configuration options, and installation/upgrade instructions, refer to the chart-specific documentation linked below.

## Available charts

- **plane-ce**  
   Helm chart for deploying Plane Community Edition.  
   Refer to: [charts/plane-ce/README.md](./charts/plane-ce/README.md)

- **plane-enterprise**  
   Helm chart for deploying Plane Enterprise Edition.  
   Refer to: [charts/plane-enterprise/README.md](./charts/plane-enterprise/README.md)

## Getting started

Choose the edition you want to deploy and follow the instructions in the corresponding chart README. Each chart README documents:
- supported Kubernetes and Helm versions
- required configuration (ingress, storage, secrets, database, etc.)
- installation and upgrade steps
- values reference and examples

## Choosing the right chart

If you are unsure which chart to use, we generally recommend starting with the **plane-enterprise** chart. Plane Enterprise includes a free plan, and you can begin without a commercial license. If you later decide to upgrade to a paid plan, you can do so by adding a license key, there is no need to migrate data or reinstall the deployment.

If you prefer to stay on **plane-ce** indefinitely and want a fully open-source deployment without Enterprise licensing, you can continue using Plane Community Edition with no change required.

For additional guidance on self-hosting Plane, including Kubernetes deployment methods and operational considerations, see the Plane developer documentation: https://developers.plane.so/self-hosting/methods/kubernetes
