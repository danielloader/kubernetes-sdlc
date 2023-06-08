# Creation of Local Environments

!!! tip
  Alternatively if you have [taskfile](https://taskfile.dev/) installed - `task create`.

1. Create the clusters:

  ```shell
  kind create cluster --config create/$ENV_NAME.yaml
  ```

1. Bootstrap the clusters with FluxCD whilst being mindful of the owner (group path) and repository name:

  ```shell
  export GITLAB_TOKEN=<your personal access token with api, write_repo, read_registry scoped roles>
  flux bootstrap gitlab --token-auth --owner ***REMOVED*** --repository fluxcd-demo --path ./clusters/$ENV_NAME --context kind-$ENV_NAME
  ```

1. Add the Container Registry secret to the `flux-system` namespace so that the platform components can be pulled:

  OCIRepository Platform Artifacts (Production/Staging):

  ```shell
  export GITLAB_USERNAME=<gitlab login email>
  kubectl create secret docker-registry platform-repository --docker-server=registry.gitlab.com --docker-username="$GITLAB_USERNAME" --docker-password="$GITLAB_TOKEN" --namespace flux-system --context kind-$ENV_NAME
  ```

  GitRepository Platform Branch (Deployment/Sandboxes):

  ```shell
  kubectl create secret generic platform-repository -n flux-system --from-literal=username=git --from-literal=password="$GITLAB_TOKEN" --context kind-development
  ```

Now your clusters will be following the state of this repository, as dictated by the `clusters/` directory, and you can check using kubectl to get the status of the kustomization objects:

OCIRepository platform type cluster (note the semver package tack tracked as a current revision):

```shell
> kubectl get kustomizations -n flux-system --context kind-production
NAME                       AGE   READY   STATUS
flux-system                45m   True    Applied revision: main@sha1:32f862f2e10fbaf1f10ff915a6b5b3954ca17037
platform-configs           45m   True    Applied revision: 0.0.6@sha256:a02c5784eafe0f93f92378c806ef94bc5dc7b0e653b65039f1c17178e06ab32a
platform-service-configs   45m   True    Applied revision: 0.0.6@sha256:a02c5784eafe0f93f92378c806ef94bc5dc7b0e653b65039f1c17178e06ab32a
platform-services          45m   True    Applied revision: 0.0.6@sha256:a02c5784eafe0f93f92378c806ef94bc5dc7b0e653b65039f1c17178e06ab32a
```

GitRepository platform type cluster (revision is a git full SHA1 hash of a commit):

```shell
> kubectl get kustomizations -n flux-system --context kind-development
NAME                       AGE   READY   STATUS
flux-system                47m   True    Applied revision: main@sha1:32f862f2e10fbaf1f10ff915a6b5b3954ca17037
platform-configs           47m   True    Applied revision: main@sha1:32f862f2e10fbaf1f10ff915a6b5b3954ca17037
platform-service-configs   47m   True    Applied revision: main@sha1:32f862f2e10fbaf1f10ff915a6b5b3954ca17037
platform-services          47m   True    Applied revision: main@sha1:32f862f2e10fbaf1f10ff915a6b5b3954ca17037
```
