# End to End - From Requirements to Delivery

This page serves as a step by step guide on taking requirements and following a change control system to complete a change request.

## Requirements

Let us imagine a ticket to a platform team where an application team to change the state of the clusters via their platform deployment.

Framing it as a user story helps frame the use case and deliverable.

> **As a** application developer
>
> **I want** utilise the [`keda`](https://keda.sh/) service to provide [`ScaledObject`](https://keda.sh/docs/2.0/concepts/scaling-deployments/#scaledobject-spec) functionality on deployments
>
> **So that** I can deploy a horizontally scaled service

!!! note

    It is worth noting that this ticket is asking for a new service, rather than an upgrade to an existing service. 
    
    Adding services is the easiest change, removing them the next easiest and upgrading them is the hardest. This is because adding a service has no current users and a hard deprecation of a service is final - ideally with a lot of forewarning for platform users to have removed the dependency in their applications.

    Upgrading is the most difficult because applications have to be thoroughly tested against a new version of the service. Maintaining a production service through an upgrade cycle is always the most challenging part of the software development lifecycle.

## Planning

The first step to a platform change is to establish if the functionality requested can be achieved in the existing component stack. In this specific example `keda` is a wrapper around a built in kubernetes component ([HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)) so the first step would be to check if this functionality can service the needs of the application team. The best component to deploy is none at all.

In this fictional scenario the application team has confirmed they need one of the custom scaler policies provided by `keda` and the HPA only being able to scale on basic resource utilisation statistics is not sufficient.

The next step is to scope out if the current kubernetes deployments can support the requested service. The documentation found at [https://keda.sh/docs/2.0/deploy/](https://keda.sh/docs/2.0/deploy/) states the only requirement is a kubernetes cluster version 1.16 or greater.

In this theoretical example the prerequisite is met in all the currently supported environments.

!!! note

    Additionally to reviewing the requirements of the service installation against your supported clusters it is worth doing additional due diligence around the service maturity.

    - Has the service only recently come into being? (risk of unstable API and increased upgrade burden due to rapid changes having to be propagated through the environments)
    - Is the service relying on pre-stable API groups in kubernetes? While not critical it will mean you need to be extra vigilant on kubernetes control plane upgrade change notes for the inevitable loss of the beta API the service relies on.
    - Does the service have a commerical support offering? Examples include Confluent for Kubernetes and Druid/Imply. _These may be requirements for production deployments._

The change request does not necessitate a newer control plane but this may not always be the case - additional planning and testing may be needed if you need to add an external cluster change to internal platform component changes but the same process would be followed with the additional step if pushing a sandbox in the first stage forward on the kubernetes upgrade lifecycle and then propagating those changes up the chain in addition to the internal to the cluster platform deployments.

To summarise:

- The prerequisites of the change request have been met in the current clusters.
- The request is a new service rather than a removal or upgrade of an existing service.
- The request cannot be met using existing components in a different configuration.

## Implementation

First task is to imagine the change control flow and quality gates that are between a platform change and production deployment:

- Creation of a sandbox to do the initial investigation and configuration.
- Promotion of changes from a sandbox to the Development environment.
- Packaging those changes into a versioned artifact for deployment on staging.
- Promotion of this package into production.

![sandbox promotion](images/change-promotion-platform-a.drawio.svg)

--8<-- "docs/implementation/change-promotion.md:create-sandbox"

At this point you have a point in time snapshot clone of the Development environment - by virtue of creating a branch in the git repository. Now you're free to make changes to the cluster.

To install a service like `keda` you will need to create a YAML manifest of the components needed to be deployed using FluxCD:

!!! info

    This is just an example for this documentation but most services prefer or mandate to run in their own namespace to make RBAC simpler to implement e.g cert-manager, kyverno.

```yaml title="platform/services/keda.yaml (example)" linenums="1"
--8<--- "docs/manifests/keda.yaml"
```

FluxCD will take these three objects, apply them to the cluster and own the reconciliation loop of the objects. 

!!! tip

    The upgrade procedure for most charts would be a version bump in the `.spec.chart.spec.version` value and any changes mandated in the `.spec.values` map.

At this point it would be prudent to deploy an example to confirm the installation of the controller.

```yaml title="scaler.yaml" linenums="1"
--8<--- "docs/manifests/scaler.yaml"
```

```yaml title="load-test.yaml" linenums="1"
--8<--- "docs/manifests/load-test.yaml"
```

