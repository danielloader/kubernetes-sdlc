![planning rfc](https://img.shields.io/badge/status-draft%20rfc-informational)
![owner](https://img.shields.io/badge/owner-Daniel%20Loader-brightgreen)

[[_TOC_]]

> **NOTE**: _High level goals and progress can be tracked against the [goals](GOALS.md) page._

## Concepts

Before moving onto problem solving, it is a good idea to get all the readers of this document on to a shared level of understanding around the concepts being explored as to properly enable people to critique and contribute to this document. As such this section can be skipped over if you are comfortable with each heading, though skim reading is advised in case terms are being used incorrectly or with cross meanings.

### GitOps

GitOps in the simplest form is the concept of representing operations state in a git repository with the additional but essential concept that the git repository is the source of truth. 


The rationale from this is that infrastructure states become well known, sources of truth are centralised and multiple teams can interact with any given infrastructure configuration with some safety net around simultaneous changes.

To achieve this, some of the more classical software development life cycle workflows are adopted but only where it makes sense. Not all software development workflows map well to the declarative world of tangible infrastructure.

#### Pull vs Push?

In addition to broader concept of GitOps you have two competing methodologies for utilising git as the source of truth for deployments:

* A push workflow where in changes are made to a repository and these changes are _pushed_ to resulting clusters to enforce state changes. Any manual changes made in between deployments is effectively overwritten on the next pipeline run, but not before.
* A pull workflow where in these changes are stored in the repository but the responsibility on reading these changes and reconciling the state of the infrastructure to match the state of the repository is in the hands of the controllers in the infrastructure itself.

#### Push Based GitOps
![gitops push high level diagram](docs/gitops-push.drawio.svg)

In a push GitOps topology changes get to the cluster by way of a push mechanism - primarily in the form of pipelines. Changes in state that the pipelines are configured to listen for then trigger pipelines, this then takes whatever the state is at the time of the pipeline operation and dumps it onto the infrastructure that is loosely grouped into an environment.

This process only happens at the point of a change in the source code, if you do not change the repository for months then the last time the pipelines will run, by default is months ago. If you have infrastructure that is open to change via other methods, directly via a WebUI or CLI tool like AWS, then you can potentially expect _state drift_.

There are ways to mitigate this; running a pipeline on a schedule regularly to reinforce the state that is stored in git as the source of truth, disabling access to mutate infrastructure via other means, culture changes inside the company around the development lifecycle.

Due to these things someone decided this should be the default way to operate - and thus the pull based methodology was born.
#### Pull Based GitOps

![gitops pull high level diagram](docs/gitops-pull.drawio.svg)

The pull based GitOps flow builds on the push based, and adds in technology that has the job of _constantly_ reconciling state to a known source of truth - that is to say, if you fiddle with the state the controller of the state will revert your changes back to the state stored in the git repository very quickly, automatically and with no manual intervention.

If you want to change the state of this system your only option is to change the git repository state. [^pull-escape-hatch]

[^pull-escape-hatch]: You can just disable the controller enforcing the state in emergencies if you need to mutate production state, but if you are at that stage you are going to be triggering a chunky post-mortem meeting the next working day around why you had to. Use with care.

Which to use and when to swap between the two major methodologies up for debate - most companies will start with a pushed based methodology, simply because it emulates the flow of travel in existing CI/CD pipelines used for packaging and releasing code.

### Kubernetes

This section is not intended to explain what kubernetes is under the bonnet, even though you could concentrate the value proposition into two main points; an abstraction layer between application runtime and operating systems/hardware, a state reconciliation engine for your workloads.

This section instead focuses on the business value the adoption of kubernetes is advertised to bring, and some painful lessons where it adds more friction than it is worth if you do not adopt it wholesale. 

Runtime abstraction can be loosely redefined as portability - a concept that drove the initial adoption of C and Java decades ago. It has been a laudable goal since the second computer was ever made, how does one take the software engineering effort and reuse it on new hardware?

Kubernetes is the latest in this nearly century old abstraction on abstraction race to the bottom.

![kubernetes high level diagram](docs/kubernetes-layers.drawio.svg)

In this diagram, kubernetes exerts influence in the red boxes, resting on a linux distribution in purple, itself resting on any abstraction of linux installations; bare metal, virtual machines, cloud instances, which ultimately exist somewhere as physical tin.

The overarching selling point to the kubernetes dream is try to limit the cognitive load of the system:
* Developers look after the blue boxes.
* Platform team looks after the red area (and if you are lucky, a different platform team looks after the purple layer).
* Another team looks after the grey layer; be it managed infrastructure like AWS, or an on premises server team who rack servers on your behalf.