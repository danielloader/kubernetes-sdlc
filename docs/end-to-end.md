# End to End - From Requirements to Delivery

This page serves as a step by step guide on taking requirements and following a change control system to complete a change request.

## Requirements

Let us imagine a ticket to a platform team where an application team to change the state of the clusters via their platform deployment.

Framing it as a user story helps frame the use case and deliverable.

> **As a** application developer
>
> **I want** utilise the [`KEDA`](https://keda.sh/) service to provide [`ScaledObject`](https://keda.sh/docs/2.0/concepts/scaling-deployments/#scaledobject-spec) functionality on deployments
>
> **So that** I can deploy a horizontally scaled service

!!! note

    It is worth noting that this ticket is asking for a new service, rather than an upgrade to an existing service. 
    
    Adding services is the easiest change, removing them the next easiest and upgrading them is the hardest. This is because adding a service has no current users and a hard deprecation of a service is final - ideally with a lot of forewarning for platform users to have removed the dependency in their applications.

    Upgrading is the most difficult because applications have to be thoroughly tested against a new version of the service. Maintaining a production service through an upgrade cycle is always the most challenging part of the software development lifecycle.

## Planning

The first step to a platform change is to establish if the functionality requested can be achieved in the existing component stack. In this specific example `KEDA` is a wrapper around a built in kubernetes component ([HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)) so the first step would be to check if this functionality can service the needs of the application team. The best component to deploy is none at all.

In this fictional scenario the application team has confirmed they need one of the custom scaler policies provided by `KEDA` and the HPA only being able to scale on basic resource utilisation statistics is not sufficient.

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

### Provisioning a Platform Sandbox

The first action with this diagram the first task is creating a branch in this repository to do work in, branched from `main`.

In this branch you will want to clone the Development environment, as it is set to track against a git repository and branch. However as Development is tracking against `main` the first change you will need to make is to point the branch reference to track your new branch.

!!! tip

    It is good practice to use a ticket reference in your branch as a prefix followed by hyphenated summary of the branch function

```yaml title="clusters/development/platform.yaml" linenums="1"
--8<-- "clusters/development/platform.yaml:branch"
```

Next step is provisioning your infrastructure as code template to create a working cluster. You will want to ensure the default context is set correctly, as checked via the `kubectl config get-contexts` output or explicitly add `--context` flags for `flux` and `kubectl` commands later.

1. Deploy a new instance of the kubernetes infrastructure of code - incrementing the control plane version or any other baseline modules you have breaking changes in:

   - Kubernetes control plane version being incremented.
   - Core EKS addons versions.
  
1. Since the above GitRepository object has a `.spec.secretRef` for a private repository, you will need to provide a secret to connect to the repository with the same name in the `flux-system` namespace. [Details](https://fluxcd.io/flux/components/source/gitrepositories/#secret-reference) can be found in the FluxCD documentation.
1. Clone the development cluster to a sandbox:

    ```shell
    rsync -av --exclude='*/gotk-sync.yaml' "clusters/development/" "clusters/sandbox-a"
    ```

1. Run FluxCD bootstrap on the new cluster to overwrite the values in the `flux-system` directory in the cluster directory, this is required to connect the reconciliation loop between source and cluster.

At this point you have a point in time snapshot clone of the Development environment - by virtue of creating a branch in the git repository. Now you're free to make changes to the cluster.

### Making Changes in the Sandbox

To install a service like `KEDA` you will need to create a YAML manifest of the components needed to be deployed using FluxCD:

!!! info

    This is just an example for this documentation but most services prefer or mandate to run in their own namespace to make RBAC simpler to implement e.g cert-manager, kyverno.

```yaml title="platform/services/keda.yaml (example)" linenums="1"
--8<--- "docs/manifests/keda.yaml"
```

After committing this file into the relevant branch and directory (platform/services) and pushing, FluxCD will take these three objects and apply them to the cluster and own the reconciliation loop of the objects.

!!! tip

    The upgrade procedure for most charts would be a version bump in the `.spec.chart.spec.version` value and any changes mandated in the `.spec.values` map.

At this point it would be prudent to deploy an example to confirm the installation of the controller.

Firstly a scaler object, so KEDA knows which deployment to monitor and the appropriate scaling behaviour to apply using `kubectl`.

!!! note

    In the split responsibility model, it's not for you as a platform engineer to include a `ScaledObject` object with this change request, the goal is to evaluate if KEDA is working as advertised in our cluster environment and as such this allows application teams to craft their own for their own application needs.

```yaml title="scaler.yaml" linenums="1"
--8<--- "docs/manifests/scaler.yaml"
```

Secondly a job to put some load on the `podinfo` application that was installed in `app-a` namespace as inherited as part of the clone from Development. As this is a once and done job, there's no need to put it into the git repository and I would advise just using `kubectl` to apply and delete the resources as needed. 

Find a balance between rapidly deploying objects to your sandbox and waiting for a GitOps cycle to complete - by that measure just iterate on a local YAML file and then commit it when you're happy with the state and avoid using `kubectl` to create objects with options and arguments.

```yaml title="load-test.yaml" linenums="1"
--8<--- "docs/manifests/load-test.yaml"
```
If all goes well you will get a job running to completion with logs looking similar to the following snippet.

```shell
Running 3m test @ http://podinfo.app-a:9898
  4 threads and 12 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    31.64ms   45.23ms   1.29s    83.59%
    Req/Sec   301.74    191.35     1.32k    65.79%
  358194 requests in 5.00m, 186.86MB read
Requests/sec:   1193.52
Transfer/sec:    637.56KB
Stream closed EOF for default/load-tester-nb4xq (wrk)       
```

In addition to that, during the duration of the load test you should have noticed the `podinfo` deployment adjusting the replica count and by extension of this, scaling out horizontally.

```shell
$ kubectl top pods --selector=app.kubernetes.io/name=podinfo -n app-a
NAME                    CPU(cores)   MEMORY(bytes)   
podinfo-f7bb67f-gbmjw   3m           13Mi            
podinfo-f7bb67f-lmdxz   95m          29Mi            
podinfo-f7bb67f-td86k   3m           13Mi
```

So at this point we're happy with the deployment and the dummy scaling workload succeeded some light testing. Next step is applying these changes back to the development environment.

### Promoting Changes from Sandboxes to Development

