# Destroying Local Environments

!!! tip

    Alternatively if you have [taskfile](https://taskfile.dev/) installed - `task delete`.

Since these clusters are local, with no external state being deployed you can safely delete the kind clusters without removing anything flux has provisioned:

```shell
kind delete cluster --name staging
kind delete cluster --name production
kind delete cluster --name development
```
