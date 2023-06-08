# External Resources

Related to the [loose coupling](../concepts/loose-coupling.md) problems talked about some applications inevitably need to store state and often that state is best serviced in a place outside the kubernetes cluster itself. Databases would be top of the list of resources that make sense to store outside of a cluster, utilising cloud provided managed databases wherever possible.

It is a common pattern to pre-provision these resources prior to installing helm charts and hoping the connection lines up using things like AWS Secrets Manager to lazily pass connection details down to a consuming application, but this model creates issues with shared resources and cleaning up of resources on uninstallation of an application from the cluster.

Given this problem multiple solutions have been build to aid in handling infrastructure from inside your kubernetes manifests natively, so you can deployment alongside your deployments in your helm charts.

![externally managed resources](../images/external-resource-problem.drawio.svg)

- [Crossplane](https://www.crossplane.io/why-control-planes)
- [AWS Controllers for Kubernetes](https://aws-controllers-k8s.github.io/community/)
- [Terranetes](https://terranetes.appvia.io/)
- [TF-controller](https://github.com/weaveworks/tf-controller)
- [Cloud Config](https://cloud.google.com/anthos-config-management/docs/concepts/config-controller-overview)

All of these options follow a similar pattern:

1. Helm chart includes deployments that need externally provisioned resources.
1. FluxCD installs this HelmRelease that includes a custom resource object for the cloud resource.
1. The cloud resource controller picks up the object, provisions it, and returns outputs like connection strings to a kubernetes secret object.
1. Deployment sits in a waiting to schedule state until the secret exists, then when it does, mounts the secret in a path to use in the application.

![external resource controllers](../images/external-resource-controllers.drawio.svg)

