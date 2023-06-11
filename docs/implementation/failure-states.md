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