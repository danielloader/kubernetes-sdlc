# Failure States

So far we have only covered happy path deployments - changes made, changes successfully applied to the cluster.

What happens when the deployments fail? There are many reasons why a deployment may fail but a few examples stand out:

- Network connectivity - the target cluster can't connect to the source to get the helm chart or manifests.
- Permissions connectivity - functionally the same as above but due to credentials failing to authenticate.
- Configuration mismatch - Unforeseen cluster specific configuration, could happen at the merge to Development stage as other applications and platform teams are promoting their sandbox changes into Development.

The last example requires more analysis.

The Development cluster as covered previously is the first time your proposed changes interact with the changes from other teams, this environment is commonly referred to as an integration environment.

As such it is natural that this environment has the highest failure rate of change, potentially even higher than sandboxes environments.

_An increase in moving components nearly always leads to increased failure rate._

!!! note "Note on Shift Left Testing"

    This is by design and a reflection in the system to echo the sentiments in [shift-left testing](https://en.wikipedia.org/wiki/Shift-left_testing). The cost of change is lower if problems can be found earlier, changes made to mitigate those problems and retrying the change promotion process.

    Ultimately this is the justification for using sandboxes, so you can get a useful facsimile of a target environment and do your testing scenarios as early as possible in the software development lifecycle.

In a sandbox environment it is assumed as an active change environment you are actively engaged with the cluster during change. In a FluxCD driven environment that would be primarily interacting with the Source, Kustomize and Helm controller objects.

Much like other components in the kubernetes ecosystem, FluxCD reports a `READY` state when a component is healthy. Examples of some components reporting healthy status:

=== "Kustomizations"

    ```shell
    > kubectl get kustomizations --all-namespaces
    NAME                       AGE     READY   STATUS
    flux-system                5m56s   True    Applied revision: main@sha1:06a5a134147d7f9dfb1aeb561e313adf7b78520c
    platform-configs           5m36s   True    Applied revision: main@sha1:06a5a134147d7f9dfb1aeb561e313adf7b78520c
    platform-service-configs   5m36s   True    Applied revision: main@sha1:06a5a134147d7f9dfb1aeb561e313adf7b78520c
    platform-services          5m36s   True    Applied revision: main@sha1:06a5a134147d7f9dfb1aeb561e313adf7b78520c
    ```

=== "GitRepositories"

    ```shell
    > kubectl get gitrepositories --all-namespaces
    NAME          URL                                                   AGE     READY   STATUS
    flux-system   https://github.com/danielloader/kubernetes-sdlc.git   7m42s   True    stored artifact for revision 'main@sha1:06a5a134147d7f9dfb1aeb561e313adf7b78520c'
    platform      https://github.com/danielloader/kubernetes-sdlc.git   7m22s   True    stored artifact for revision 'main@sha1:06a5a134147d7f9dfb1aeb561e313adf7b78520c'
    ```

=== "HelmRepositories"

    ```shell
    > kubectl get helmrepositories --all-namespaces --context kind-development
    NAMESPACE        NAME             URL                                                 AGE     READY   STATUS
    flux-apps        podinfo          https://stefanprodan.github.io/podinfo              9m53s   True    stored artifact: revision 'sha256:09c71269cc5c6286dfd7012738a0eb406efceeac23cd0730bb7bffc814248e38'
    kyverno          kyverno          https://kyverno.github.io/kyverno/                  9m50s   True    stored artifact: revision 'sha256:02e6f2c19d3258697f586de5a937b09128a495ac37b1c684f1d7820ce299b860'
    metrics-server   metrics-server   https://kubernetes-sigs.github.io/metrics-server/   9m50s   True    stored artifact: revision 'sha256:e9f523294955f69fa52b26770770ce9772d0e6c211d282233c87b02476787e6c'
    ```

=== "HelmReleases"

    ```shell
    > kubectl get helmreleases --all-namespaces
    NAMESPACE        NAME             AGE     READY   STATUS
    flux-apps        podinfo          8m39s   True    Release reconciliation succeeded
    kyverno          kyverno          8m36s   True    Release reconciliation succeeded
    metrics-server   metrics-server   8m36s   True    Release reconciliation succeeded
    ```

