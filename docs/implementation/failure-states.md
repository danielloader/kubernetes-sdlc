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

But lets say your access to the git repository fails? What does this look like to you - the engineer using the sandbox.

```shell
> kubectl get gitrepositories --all-namespaces
NAMESPACE     NAME          URL                                                   AGE    READY   STATUS
flux-system   flux-system   https://github.com/danielloader/kubernetes-sdlc.git   134m   True    stored artifact for revision 'main@sha1:06a5a134147d7f9dfb1aeb561e313adf7b78520c'
flux-system   platform      https://github.com/danielloader/kubernetes-sdlc.git   134m   False   failed to checkout and determine revision: unable to list remote for 'https://github.com/danielloader/kubernetes-sdlc.git': authentication required
```

Additional FluxCD documentation on statuses can be found [on their website](https://fluxcd.io/flux/components/helm/helmreleases/#status).

FluxCD HelmReleases can be [configured to automatically remediate](https://fluxcd.io/flux/components/helm/helmreleases/#configuring-failure-remediation) certain failure states:

- You can retry x times.
- You can rollback the release to the last known working configuration.

!!! warning

    By default if a HelmRelease fails, it just fails and leaves it in a failure state to allow you to investigate those failures. This likely isn't the behaviour you want downstream in the other environments.

Lots of situations can yield a false status on the `READY` value and what happens next would depend on your risk appetite on failure. In a sandbox this would be on you as the engineer making changes to notice when you're working with the cluster but what happens if this happens on a long lived environment where multiple teams are working on it?

## Notifications

Well FluxCD includes a [Notification Controller](https://fluxcd.io/flux/guides/notifications/) forward lifecycle events in the FluxCD ecosystem to a third party target.

Two primary workflows are important here:

- Reporting back to the GitRepository that a certain commit hash is successfully applied.
- Reporting to a chat/alerting platform that a release has had a successful or failure deployment.

!!! warning "Warning from FluxCD"

    > [It is important to keep this in mind when building any automation tools that deals with the status, and consider the fact that receiving a successful status once does not mean it will always be successful.](https://fluxcd.io/flux/guides/notifications/#status-changes)

    Given this, I personally don't see as much value in the commits showing successful states but your mileage may vary. Moreover if you store multiple clusters in the same repository as I have, if you have three or more clusters reconciling to the same commit if one cluster fails and then the others succeed the last recorded state will be a success. 

Both flows are documented in the above link to the FluxCD documentation so review those and apply them where it makes sense.

!!! note

    It probably doesn't make sense to include alerts on your sandbox environments, as the signal to noise ratio will be high and people will stop paying attention to chat channels where notifications are being sent to. Additionally it would make some sense to split the chat channels into "Development", "Staging" and "Production" channels so certain people can pay attention to certain environments.

## Summary

- In important environments set strict auto remediation configuration to retry upgrades and/or automatically rolling back.
- Sandboxes should be perfectly sufficient to be isolated and monitored by the person making the changes.
- Try not to cause a low signal to noise ratio in any notifications endpoint - noisy Slack channels get ignored.