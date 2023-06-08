# Loose Coupling

Contrary to the title, this section is actually about the benefits of strong coupling that fails in a way that you can debug and rectify in an incremental way rather than deleting the entire cluster and starting again.

Coupling in the kubernetes sense is a two part subject:

- Internal component coupling - Custom Resource Definitions, ConfigMaps and Secrets needing to exist before Objects referencing them.
- External component coupling - [IAM](https://aws.amazon.com/iam/getting-started/) roles needing to exist with the right trust relationship to a [OIDC provider](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html) to permit [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) access from a Service Account.

## Internal Components

FluxCD offers two ways to handle coupling of components when applied to a cluster:

- Direct dependencies that force ordering of reconciliation.
- Indirect dependencies that fail open and operate safely with a race condition, waiting for the resource to exist before the HelmChart or similar can install.

They are pros and cons to both methods; direct dependencies are explicit. Take this example:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: platform-service-configs
  namespace: flux-system
spec:
  dependsOn:
  - name: platform-services
  interval: 1m
  path: ./platform/service-configs
  prune: true
  sourceRef:
    kind: OCIRepository
    name: platform
```

This Kustomization resource will not attempt to reconcile until the Kustomizations that are referenced in the `.spec.dependsOn` array are successfully showing a ready status, until then it will just be pending.

You can also do indirect component coupling as cited above, and this is best suited when handling coupling of application helm charts. If you enforce strict ordering and dependencies in your applications they're probably not as isolated or stand alone - and this almost definitely causes headaches.

## External Components

This is tricker, because the cluster has to lazily assume these objects exist outside of the cluster due to the lack of ability to check.

IRSA role ARN annotations on Service Accounts would be the most common example, where in you have to assume an IAM role has been provisioned outside the account, with the correct trust relationship and scoped to the correct namespace and service account name.

With this example you are forced into extremely tight coupling but indirectly - predictable ARNs for role names for example. You can't know the ARN of the service created for sure, so helm charts will need to guess when creating service account annotations.

To aid in this problem you can bootstrap the cluster with a ConfigMap at creation time to include variables that can be used by Kustomization and HelmRelease objects to inject variables into YAML. 

On EKS the primary beneficial minimum values you would want to include would be:

- Cluster AWS Region
- Cluster Name
- Cluster AWS Account ID

Using these three things you should be able to script access to other resources in downstream use-cases.
