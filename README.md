![heading](docs/heading.drawio.svg)

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

This section is not intended to explain what kubernetes is under the bonnet, this is more aimed as a high level overview. You could concentrate the value proposition into two main points:
* An abstraction layer between application runtime and operating systems/hardware.
* A state reconciliation engine for your workloads.

This section instead focuses on the business value the adoption of kubernetes is advertised to bring, and some painful lessons where it adds more friction than it is worth if you do not adopt it wholesale. 

Runtime abstraction can be loosely redefined as portability - a concept that drove the initial adoption of C and Java decades ago. It has been a laudable goal since the second computer was ever made, how does one take the software engineering effort and reuse it on new hardware?

Kubernetes is just the latest in this nearly century old abstraction on abstraction race to the bottom. 

![kubernetes high level diagram](docs/kubernetes-layers.drawio.svg)

In this diagram, kubernetes exerts influence in the red boxes, resting on a linux distribution in purple, itself resting on any abstraction of linux installations; bare metal, virtual machines, cloud instances, which ultimately exist somewhere as physical tin.

The overarching selling point to the kubernetes dream is try to limit the cognitive load of the system:
* Developers look after the blue boxes.
* Platform team looks after the red area (and if you are lucky, a different platform team looks after the purple layer).
* Another team looks after the grey layer; be it managed infrastructure like AWS, or an on premises server team who rack servers on your behalf.

Kubernetes attempts to abstract away as much as possible about the underlying infrastructure; from which flavour of linux distribution it is running on top of, to which CPU microarchitecture the nodes are running. Previous pain points, such as creating an RPM package that ran on a specific flavour of CentOS/RHEL which in turn would slow down the eagerness of the infrastructure teams to patch operating systems under fear of software failures - does not go away entirely, but the abstraction lessens the coupling between the layers, helps create more aligned infrastructure between stages of deployment (dev, staging and production) and more flexibility to change components deeper down the stack relying on the abstractions to take the brunt of the change for you.

In addition to this abstraction and isolation principle, kubernetes at its core is a state reconciliation engine.

![state reconciliation cycle](docs/kubernetes-state-design.drawio.svg)

It is not a particularly complex system to understand but it is one infrastructure engineers have been battling since the first person decided to have multiple clones of the same server running in a fleet.

At the core of the principle is the idea that you provide a desired state, and the system in the loop tries to reconcile that desired state against the current state in the system - correcting for drift. 

If you want nine replicas of a container running at all time and some stop working, kubernetes will detect the failures and attempt to bring up replicas until the desired count is realigned with the state desired.

There are many examples of this reconciliation loop in the kubernetes ecosystem; you could argue all YAML given to the control plane represents a fixed state the system needs to align to.

This brings us neatly back to GitOps, where in a systems state is defined in a git repository - this pattern works well when the control plane you are deploying to can adjust the runtime state of a system and maintain it for you. 

There are two competing market leaders at the time of writing for bridging the state between a git repository and a kubernetes cluster; ArgoCD and FluxCD. While ArgoCD is the market leader at this current time the philosophy of the project is more aligned to a developer centric workload system, with FluxCD being slightly more operationally focused. Both systems overlap massively, both try to achieve the same overarching goal of taking a git as a source of truth approach and applying it to the cluster they maintain. ArgoCD is quite a heavy monolithic application, where as FluxCD since the version 2 rewrite has taken a much lighter, edge cluster friendly approach to modularising the functionality it enables.

Given this; this document will explore the FluxCD side of this divide - simply because there is a non functional requirement for this process to be kept resource light, and with a heavier emphasis on operational simplicity over developer simplicity. In the case of Nominet this is because third party teams, be it internally or externally via contractors, are the operators of the clusters. Anything to make their workload simpler has preference in the balance between developer and operator complexity.

Before jumping onto FluxCD, which makes up the bulk of the rest of this whitepaper, it is worth discussing alternative technologies and where they sit in the problem space. You can not really safely advocate for a technology unless you know its shortcomings, and a reasonable percentage of its shortcomings will come from alternative technologies doing something better, simpler or cheaper.

### What Kubernetes Isn't

You would be forgiven for thinking kubernetes is the silver bullet that all organisations can utilise to deliver more value to the customer; reduce costs in infrastructure, improve deployment cadence and solve world hunger. 

Kubernetes in _isolation_ solves **nothing**. 

While I appreciate this is an incendiary comment; as far as I have seen thus far - kubernetes is a force multiplier, but if you start with a force of zero, or as good as zero, you are not going to get anything out the back of adopting it - and worse, you will likely incur a lot of _**downsides**_.

Consider the following:

* **Is your software development lifecycle built around containers (and more recently [WASM](https://developer.okta.com/blog/2022/01/28/webassembly-on-kubernetes-with-rust) runtimes)?**
    
    Failing to meet this requirement means you will not benefit at all by the adoption of a platform built around orchestrating containers. This may sound obvious but having your SDLC built around containers is more than slapping a Dockerfile in the project root and calling it a day. Development ideally happens in containers, testing almost definitely should happen in containers, and ultimately deployment has to work with containers - and not just use them but understand their limitations, what they can enable and the value add they bring to the situation.

* **Is your operations team familiar with operating kubernetes clusters?**
    
    This one is a catch 22 situation. However you can run kubernetes in non production workloads to bootstrap the experience needed and the confidence built around the ecosystem to run it in production. This takes the shape of more than just reading pod logs with `kubectl` when a pod keeps `CrashLoopBackOff` looping. Understanding how the various parts of the ecosystem relate to each other, and an understanding of the data flow are important to being able to fix things that are not right. While kubernetes itself is a state reconciliation engine, at the end of the day a platform teams (and or developers on call) job is to the be the state enforcement loop around the existing one - should all the automation fail, your job is to reset the system into a state where the usual reconciliation can continue. 

* **Do you need to change the size of your workload regularly?**

    Kubernetes is reasonably good at adjusting your workloads to the requirements on the system, but only if you put the effort in. There are various middleware solutions that work in conjunction to try to enable this ideal outcome, though essentially they all operate with the same feedback loop:

    * You monitor a metric.
    * The metric changes.
    * The changed metric dictates a change in the replica count in a deployment.
    * You go back to monitoring a metric. 

    There are a lot of moving parts in your average kubernetes cluster and that incurs an operational cost - if you do not need complex operational outcomes, do not use a complex operational cluster system.

* **Do you need to coordinate a workload across multiple geographical regions?**

    It is not impossible to do this with other systems, but the capacity for kubernetes to federate with other clusters to produce a single interaction point across disparate geographical regions can be invaluable. 

* **Do you need to produce a product that is at worst "cloud agnostic" and at best "platform agnostic"?**

    If you are gunning to produce a product or service that can deploy to all the various cloud providers, it can be easier if you have a common abstraction between those environments. This is doubly true if you are trying to abstract away enough that a developer should not need to know the difference between an on premises deployment utilising VMWare Tanzu or a cloud deployment running on GCP GKE. 

This is just the tip of the iceberg when debating the adoption of kubernetes in your organisation or team, there are as many reasons for and against this course of action as there are permutations of kubernetes cluster you can deploy. Though keep in mind none of these are hard and fast rules, sometimes it can make sense when these are not met - classic example would be you have an existing pool of engineers both developers and operationally who have prior experience in this space then it can make sense to adopt it regardless of the purpose.

Even if you answer all these questions in the direction that would naturally lean towards adopting a kubernetes technology stack in your organisation, it is not the only game in town for this workload management - older and simpler might tick the box for you.

* **RedHat Ansible**

    [Ansible](https://www.redhat.com/en/technologies/management/ansible/what-is-ansible) has been around for a long time and it seems to have won the adoption race between its contemporary rivals of the era; chef and puppet.

    The original, and most adopted design pattern for ansible shuns a state reconciliation loop - instead adopting a "reconcile on push" model (also referred to as _agentless_). This is akin to the GitOps push model discussed earlier in this whitepaper. Ansible in this pattern has no capacity to detect drift in a configuration from the source of truth (the git repository) and instead relies on trying to correct the drift correction at the point the pipeline is triggered to deploy an updated ansible playbook.

    Ansible operates at a lower level of abstraction than kubernetes, and you can deploy a kubernetes cluster itself with ansible - but the lack of constant state reconciliation makes this technology best suited to first run server bootstrapping, infrequently changed deployments and services, and the tooling is focused around configuring operating systems rather than running workloads.

    It is a common pattern to deploy workloads with ansible, but the runtime of the service itself is managed with Systemd or similar - a fire and forget deployment where native linux tooling is engaged with to try to ensure a service keeps running, and what to do when it fails.

    Even with the above, ansible has been bent to work in a pull GitOps approach more recently, with [ansible-pull](https://docs.ansible.com/ansible/latest/cli/ansible-pull.html) - where in ansible runs on a cronjob and pulls the git repository and applies it locally.

* **SaltStack**

    [SaltStack](https://saltproject.io/a-fresh-look-at-saltstack/) essentially tries to solve the same problem that kubernetes does - in respect to reacting to events to change deployments, state drift remediation, and constant feedback loops where the salt minions poll the salt masters for state to resolve.

    What it does not however attempt to do, is abstract out the deployment from the operating system - you are still very much at the whims of the host OS to make your application run.

    From that perspective it solves 75% of the problem but is remarkably simpler to operate. This leads to an interesting situation to resolve - if you do not need the abstractions, is it possible to get away with a simpler stack?

    If the answer is yes, you should. Simpler is better, nearly always. 

    You can somewhat operate in the grey area between Salt and Kubernetes by using `docker compose` or similar technology to run your workloads in containers, but it can end up more complicated than the benefits will offset. Docker compose is not really designed to orchestrate complicated workloads, and can only operate on a host by host basis. 
    
    If your workloads are stateless none of this is a problem, however if they are stateful you can end up reimplementing a lot of kubernetes out of the box functionality yourself with Salt and Docker runtimes.

* **Hashicorp Nomad**

    [Hashicorp Nomad](https://developer.hashicorp.com/nomad/docs/nomad-vs-kubernetes) exists as a simpler alternative to Kubernetes. 

    It is not exclusively focused on containerised workloads; can support virtualised, containerised and stand alone applications - this allows you to skip a requirement from the above considerations block.

    Nomad strives to offer less, but do it better - and in some workloads this is an ideal compromise, the difficulty comes from the fact it is a niche and not well adopted solution to the problem which can make hiring for it more difficult and time consuming. 
    
    Though anyone familiar with kubernetes should have enough baseline knowledge to work with Nomad if push comes to shove.

* **Hashicorp Packer**

    [Hashicorp Packer](https://www.packer.io/use-cases/automated-machine-images) is an interesting solution to the "I have something I want to run, how can I package it to run?". Essentially it is a scriptable build pipeline for creating virtual machine images; including cloud deployments like EC2 AMIs. It does not orchestrate, it does not deploy, it does not update your machine nor does it offer any state reconciliation - so why is it on the list?

    It has been a model for a long time to create fixed function virtual machine images and deploy them to a cluster that runs VMs - and this pattern is loosely called a software appliance. All your state, all your update management, all your telemetry is configured at boot time on first deployment. The operating system itself is configured to try and maintain itself - automatic package upgrades, using docker or similar on the base OS to run applications, systemd to monitor and restart services in production. 

    It is an old model, but for some deployments this can make a lot of sense - it is the ultimate abstraction on hardware - you provide a virtualised hardware platform and run the images directly on it. As long as you can provide the CPU core count, memory and storage requirements for the appliance to run you should have a solid production deployment.

    This model falls apart when you have horizontally scaled workloads that change frequently, or require coordination between dozens of types of applications loosely coupled to each other over the network - it suits monolithic applications. 

* **Cloud Provider Driven Serverless Computing**

    Getting it out the way first, you still have servers to run these workloads - the benefit is you do not need to care about them. As far as you are concerned both operationally and as a developer these machines might as well not exist and you only interact with the workloads via APIs.

    Another compelling use case to avoid the complexity of kubernetes completely is to deploy a workload using entirely managed services.

    If you are not tied to needing to support multiple clouds, or on premises deployments, the cost benefit analysis for serverless workloads is often a case of scale and scale alone.

    Running serverless functions 24 hours a day, 7 days a week, will almost always be more expensive than running containers doing the same job. The trade-off is the operational complexity is reduced in exchange for money.

    Serverless applications become their own tangled mess of interconnected parts in similar way kubernetes ones do, but there is a wealth of tooling out there to try and tame this problem. 

    Downsides of this methodology include but not limited to:

    * Costs can spiral quickly making budgeting more complex for finance teams.
    * You are operationally blind a lot of the time when things do not work as prescribed.
    * Your data flow model is the core of your product, the rest of it is tertiary - you need this mindset and maturity to make a serverless model work or you will end up with a spaghetti themed deployment.
    * Locally mocking out serverless/managed services can be more complicated than running a slimmed down production-alike kubernetes deployment on a local machine, thereby increasing developer feedback loops on changes.

    Upsides include:

    * Someone else cares if the service is running on a infrastructure level.
    * Someone else cares about provisioning more physical hardware when your workload increases.
    * Billing can be easier to isolate with tagging than in monolithic kubernetes clusters where mixed workloads run along side each other on shared infrastructure.
    * It will almost always be easier to hire for in the current market trajectory - AWS Lambda will be a similar experience for any developer who has worked with it prior.

There are a lot of tools written in this space, a lot of different methodologies, and a lot of disagreement on the trade-off between increasing developer productivity and rapid change feedback loops vs operational complexity and deployment pain.

There is no right answer and on the off chance you ever think you have one; your business needs will change, the underlying technology will change or your staff skills pool will adjust due to attrition leaving your previously correct answer in the wrong camp.

## Goals

Now the concepts are out of the way the rest of this document will be focused on solving a theoretical problem with a bunch of assumed theoretical functional and non-functional requirements.

To help the reader understand what we are trying to build I have assembled these into this section.

1. There is **a reason** to have the concept of _type_ of a cluster; allows for bespoke scaling, high availability and other _cost_ incurring differences.
1. There is **a reason** to run multiple clusters that inherit from that _type_ of cluster; it is likely you'll want more than any given template running at once.
1. There is **a reason** to run _ephemeral_ clusters that can inherit from any _type_ of cluster; for cost savings and transient use cases.
1. There is **a reason** to have different application configurations in different environments; permits testing a single component in isolation with mocked services.
1. There is **not a reason** to run different configurations of infrastructure on each cluster; there should be a baseline assumption all clusters will have the same underlying core resources available in every environment for operational overhead reductions.

###  Git Repository Structure

There are no prescribed way to lay out a GitOps workflow for kubernetes; this is partially because every business has their own physical topology and the directory topology should represent this rather than be opposed to it. Additionally the concept of directories in the state has no bearing on the cluster state, any directory layout is purely to aid the human cognitive load - you can (and should not) represent an entire kubernetes cluster in a single monolithic YAML document.

With that in mind an attempt has been made to draw up a topology in this repository that represents a balance between flexibility and declarative rigidity.

Don't Repeat Yourself (DRY) is a contentious subject in any system that represents state declaratively, be it Terraform or Kubernetes manifests. As such there is going to be a mix of duplication and inheritance in this project, representing an attempt to strike a balance. This will only be confirmed retroactively when you try to iron out pain points where in too much inheritance ties your hands on changes having too large of a blast radius, and too much duplication adding to the cognitive load and maintenance costs of running many environments.

![repository structure high level diagram](docs/repository-directory-structure.drawio.svg)

### State Reconciliation

So with FluxCD v2 selected for the whitepaper, here's a high level view of how FluxCD works

![gitops pull workflow using fluxcd](docs/gitops-pull.drawio.svg)

The feedback loop described by the diagram above works as follows:

1. You make a change to a YAML file(s) and commit your changes and push them to a git repository.
2. The fluxCD controller periodically pulls the repository from git, and looks for changes.
3. Any changes detected get reconciled with any sub object in the cluster that the root controller controls.
4. These reconciled states are now visible to the developer in their local IDE or kubernetes resource viewer _(k9s, lens etc)_.

The rationale for adopting this workflow can be broadly split up into the following goals:

* **Repeatability** - if you want multiple clusters to be in state sync they can all subscribe for changes from the same cluster template.
* **Promotion of changes** - each cluster has a state, enshrined in git; if you want to promote a change it's a case of copying a file from one directory to another and committing the changes.
* **Audit of changes** - since you're using merge requests there's an audit log in the git repository of changes made, when and by whom.
* **Disaster recovery** - since your state is in code, failing over or rebuilding any environment is easy.[^data-footnote]

[^data-footnote]: This process copies the state of a cluster but not the data - underlying persistent data stored in provisioned volumes needs to be treated the same as persistent data on any server - a backup process and restore process needs to be evaluated and tested outside of the infrastructure deployment and cluster deployment lifecycles.

### Cluster Configuration Change Promotion

We have discussed how to set out a state, but we have not looked at how to make changes to this state safely and promote them between non production clusters where breaking changes are permissible and production clusters where such changes are not.

There are multiple patterns documented to work with this challenge, all of them have sliding scales of complexity, speed and security. Some of these trade-offs have been discuessed below:

#### Mono Repository Pattern

![mono-repo-promotion](docs/gitops-mono-repo.drawio.svg)

In this situation there are multiple directories in the `./clusters` directory in a monorepo, each being a source of truth to a connected fluxCD controller instance - for brevity only the development environment is detailed, though all environments follow the same pattern. 

It is this following the same pattern that enables change promotion to not only be possible, but in theory yielding a predictable outcome when changes are promoted (or reverted).

As this design currently stands, it is a single branch model - you write changes to main, those changes are represented on the resulting clusters in near realtime. As you can imagine this might make production a relatively unsafe. See [Multiple Repository Pattern](#multiple-repository-pattern) for the trade offs of the opposing design.

In the monorepo pattern changes are promoted as such:

There are two work flows:

* A new change, that is not currently reflected on any of the existing long lived environments:
   
   1. Raise a ticket for the work.
   1. Bootstrap an ephemeral cluster to a new branch referencing the ticket to experiment with the changes.  
      You would be attaching an ephemeral cluster to a directory of the environment you are proposing changes for. E.g. `./clusters/development` in branch `NOM-12345` would be reconciled with `ephemeral-cluster-23` without the actual long lived environment of development being altered - it is reconciling changes from the main branch during this process.
   1. Do some development work on the cluster.
   1. On completion, raise a merge request to the main branch.
   1. On merge those changes are propagated to the cluster.

* Promoting a change from a long lived environment up the stack:

   1. Raise a ticket and subsequent git branch off main.
   1. Delete the environment directory locally
   1. Copy the old one in its place e.g. `./clusters/staging/` gets copied to `./clusters/production`.
   1. Commit those changes and push them.
   1. Raise a merge request and get it merged.
   1. Changes propagate to the target cluster.
   1. **_OPTIONAL_** - Roll back by reverting the merge request - and the previous state should be reconciled and deployed.
   
#### Multiple Repository Pattern

You can also opt for a multi-repository approach; using the Git provider ACLs to lock down certain repositories to certain users, and prevent direct pushes to the main branch. 

Such a model might look more like this:

![multi-repo](docs/gitops-multi-repo.drawio.svg)

While you have traded security and access control on production for speed of change - there is an additional caveat when using a multi-repository approach to GitOps - it massively complicates shared reusable code patterns.

Propagating state between the ephemerals which are their own repositories that developers use, to the bottom end of the long lived environments (development) requires a cross repository copy/paste and merge request action. Development to staging is simpler, single repository at this point, where in a change is a simple folder replacement and merge. Much like ephemeral to development, staging to production needs to cross another git repository boundary, where in the production repository has very strong access filters and merge request requirements to be met to permit a merge.

These models incur manpower costs, engineer time, but facilitate an arguably more secure model to represent the state of your infrastructure. 

The trade-offs are open to debate because like all security postures, they are simply an evaluation of risk vs reward.

#### Ephemeral Environments

We have touched on these repeatedly before, but it is worth explaining why you would go the extremes of engineering to allow these to exist - after all lots of companies do not use them, nor ever find a reason to use them - so why would we?

Regardless of a monorepo, or multi repo topology - you still want scratch environments to propose working changes on - if not, you would be forced to push fresh untested changes into the bottom of the long lived environment stack (in our model, Development).

This situation where the development environment is a shifting sands of potential broken infrastructure is an anti pattern, it prevents development being used for its primary objective - integration testing. Development is likely to be the first environment changes made by multiple teams, in their own isolated sprints and release schedules will interact with each other. With this in mind and as mentioned before about minimising moving parts in any given change - infrastructure should be the stable aspect in this situation, as to allow developers to find bugs and functional issues in their code without pointing their fingers at the environmental layer underneath.

In addition to facilitating an integration environment, you will want to be able to do performance tests. 

It is important you conduct this test in such a way that yields full confidence of change to a production platform, and thus you can not escape the reality that you need to run performance tests in an environment as identical in topology and compute resource allocation as production - and that is expensive.

To alleviate such a situation staging and other pre-production environments must be scaled down; be it in absolute compute resources such as smaller CPU/Memory/Disk allocations, or topological differences such as a single node where you would normally have a three node high availability cluster. Staging and other pre-production environments are in themselves considered a long running environment - ideally production like in their operation. 

Alerting and monitoring should be applied to these environments, but with out of hours alerting disabled - this is important as some infrastructure changes will be oriented around monitoring and you do not want to find out something did not work as expected the following morning when alerts did not fire in production.

Given all the above you still need to perform performance tests - this is just the nature of distributed systems architecture. This is where the concept of an ephemeral cluster comes into its own. Utilising the GitOps declarative model you can clone an existing production cluster topology, into a _short lived environment_ where in you can perform a battery of tests against it at the full scale production is running at. 

The emphasis here is squarely on a short lived environment. It should be possible from any given state to clone the cluster configuration (without persistent data - this is outside the scope of GitOps) and transplant it into similar infrastructure, in this case a Kubernetes cluster.

To summarise; ephemeral environments enable you to leave long running clusters alone so they can be used for their intended developer purpose and make infrastructure or cluster configuration changes in throwaway scratch environments and also allow you to clone an expensive environment for a few hours of performance testing to increase confidence levels prior to the changes reaching production.

To create an ephemeral cluster in this workflow:

1. Cloning this repository.
1. Create a branch off main.
1. Create a kubernetes cluster that you have access to via kubectl.
1. Run `flux bootstrap` on this branch, in the directory representing the cluster state you want to clone. e.g. bootstrap `./clusters/development` in the `TEST-1234` ticket branch. This will override the existing `flux-system` configuration and tie this branch and configuration to a new cluster.
1. Ephemeral cluster reconciles and deploys the same resources as the existing cluster in a few minutes.

To delete the cluster:

1. Run `flux uninstall` on the cluster, so all the flux created resources are destroyed.
1. Delete the kubernetes cluster.
1. Delete the temporary git remote branch.

This workflow is largely designed for testing tasks; such as performance testing, integration testing of new components prior to getting deployed to development. Though it can be used to prototype reconfiguration of any long lived environment. 

The most common task to achieve in this workflow would be the upgrading of the underlying kubernetes cluster itself - doing so on development directly would leave the cluster in a broken state for stream aligned teams to continue their work, but platform teams still need to do the work - the solution is using the ephemeral clusters.

In this workflow:

1. Clone the state of the existing development cluster onto a newer installation of the kubernetes control plane.
1. Do the fixes, document what has changed that might be pertinent to developers such as API deprecations.
1. Raise merge request between the `PLATFORM-1234` branch to `main` for development, sans the modified `kube-system` directory (specific to each physical deployment).
1. Once merged the development cluster should reconcile the state from the changes. 

This workflow is only possible because of the API deprecation policy kubernetes uses, with long soft deprecation cycles with overlaps of multiple versions of the APIs used for many kubernetes versions. This allows you to start working on supporting API changes one or two kubernetes versions ahead of the currently deployed version.

## Working Examples

This repository contains working examples in addition to the whitepaper you are currently reading. 
### Deployment

While not strictly related to this repository it's worth having a reference implementation and since most of you reading this will likely have Docker Desktop installed, the write-up will use it as a reference implementation - though if you know what you're doing it should work equally well on Kind, K3d and Rancher Desktop.

Here is a list of documented environments and how to set up a cluster:

* [Docker Desktop](create/docker-desktop/README.md) - _Preferred option for local hosting._
* [EKS](create/eks/README.md) - _Preferred option for cloud hosting._
* [Kind](create/kind/README.md)

Additional environments are documented in the [`/create`](/create) directory, and feel free to add more if you can.