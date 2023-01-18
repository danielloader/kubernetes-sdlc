# FluxCD Test Repo

This repository exists to test, experiment with and report on findings with using FluxCD and a pull based GitOps workflow.

## Deployment

### Setting up Docker Desktop

While not strictly related to this repository it's worth having a reference implementation and since most of you reading this will likely have Docker Desktop installed the writeup will use it as a reference implementation - though if you know what you're doing it should work equally well on Kind, K3d and Rancher Desktop.

#### Windows Steps

1. Have WSL2 installed and confirmed working, do first login etc.
1. Have Docker Desktop installed, and confirm the `docker ps` command is working correctly from a WSL shell session.
1. Enable the kubernetes service option in Docker Desktop settings.
    ![docker-desktop-windows](docs/windows-docker-desktop.png)

#### MacOS Steps

1. Have Docker Desktop installed, with a confirmation `docker ps` command is working correctly in the MacOS terminal session.
1. 

### Deploy Existing Cluster Template

To deploy an existing cluster template you need to add a GitRepository object that contains a reference to the upstream source, and an initial bootstrapping Kustomization object, which is the parent object for child Kustomizations, HelmCharts and other kubernetes objects.


1. Add the fluxcd controllers to the cluster:
    > **NOTE**: _If you do not specify a cluster context, it'll use the default - but it's best to be explicit. Using `docker-desktop` as the example._
    ```shell
    flux install --context=docker-desktop
    ```
1. Adding a git repository to the fluxcd controller:
    > **NOTE**: _This command will echo an SSH public key string to the terminal, it needs to be added to the repository [deploy keys](https://gitlab.com/nominet/cyber/architecture-team/fluxcd-testbed/-/settings/repository#js-deploy-keys-settings)._

    ```shell
    flux create source git flux-system --url=ssh://git@gitlab.com/nominet/cyber/architecture-team/fluxcd-testbed.git --branch main
    ```

1. Bootstrapping this cluster against a predefined template:
    ```
    flux create kustomization flux-system --source=GitRepository/flux-system --path="./clusters/local" --prune=true --interval=1m 
    ```
4. Check k9s/lens/kubectl for success:
    
    ![K9s showing succesful deployment](docs/k9s-reconcile-success.png)

### Bootstrap a new cluster with a blank controller template

To create a new cluster template, for example `clusters/abc` with a different combination of services from the components in this repository, you need to use the `flux bootstrap` command.

This also requires a personal access token from Gitlab so that it can assure the repository exists (it'll create it if it doesn't), and if it does, can write commits into the tree into the `clusters/` directory. Remember to set the branch you wish to push this new cluster template into.

```bash
export GITLAB_TOKEN= # put your personal access token here with api, read_api and read_repository access
flux bootstrap gitlab --token-auth --owner=nominet/cyber/architecture-team --repository=fluxcd-testbed --branch=main --path=./clusters/abc
```

For documentation how sub components work, follow the README.md chains down the directories.

## Runtime

### Pushing raw PCAP files into mocked S3 for processing



```
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
```