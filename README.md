# ![heading](docs/heading.drawio.svg)

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

In addition to this generalised abstraction it is worthwhile to acknowledge kubernetes itself is not a platform per se, it is a set of APIs or building blocks that you can craft a platform from. Out the box you do not get persistent storage; networking policies or load balancers - all essential components for the vast majority of workloads you would run on a cluster.

It is easier to think of kubernetes as a bucket of poorly sorted lego - all the bricks have a contract where in they promise to click together with another brick but the blocks themselves do not dictate the layout of the output. Kubernetes is much the same, the components are thoroughly tested to maintain compatibility guarantees but there is not one prescribed way to set up a cluster.

![kubernetes high level diagram](docs/kubernetes-layers.drawio.svg)

In this diagram, kubernetes exerts influence in the red boxes, resting on a linux distribution in purple, itself resting on any abstraction of linux installations; bare metal, virtual machines, cloud instances, which ultimately exist somewhere as physical tin.

The overarching selling point to the kubernetes dream is try to limit the cognitive load of the system:

* Developers look after the blue boxes.
* Platform team looks after the red area (and if you are lucky, a different platform team looks after the purple layer).
* Another team looks after the grey layer; be it managed infrastructure like AWS, or an on premises server team who rack servers on your behalf.

Kubernetes attempts to abstract away as much as possible about the underlying infrastructure; from which flavour of linux distribution it is running on top of, to which CPU microarchitecture the nodes are running. Previous pain points, such as creating an RPM package that ran on a specific flavour of CentOS/RHEL which in turn would slow down the eagerness of the infrastructure teams to patch operating systems under fear of software failures - does not go away entirely, but the abstraction lessens the coupling between the layers, helps create more aligned infrastructure between stages of deployment (dev, staging and production) and more flexibility to change components deeper down the stack relying on the abstractions to take the brunt of the change for you.

In addition to this abstraction and isolation principle, kubernetes at its core is a state reconciliation engine.

![state reconciliation cycle](docs/kubernetes-state-design.drawio.svg)

While it is not a particularly complex system to grasp but it is one infrastructure engineers have been battling since the first person decided to have multiple replicas of a server running in a group.

At the core of the kubernetes principle is the idea that you provide a desired state, and the system in the loop tries to reconcile that desired state against the current state in the system - correcting for drift.

If you want nine replicas of a container running at all time and some stop working, kubernetes will detect the failures and attempt to bring up replicas until the desired count is realigned with the state desired.

There are many examples of this reconciliation loop in the kubernetes ecosystem; you could argue all YAML given to the control plane represents a fixed state the system needs to align to.

This brings us neatly back to GitOps, where in a systems state is defined in a git repository - this pattern works well when the control plane you are deploying to can adjust the runtime state of a system and maintain it for you.

This repository will explore the FluxCD side of the FluxCD/ArgoCD divide - simply because there is a non functional requirement for this process to be kept resource light, and with a heavier emphasis on operational simplicity over developer simplicity. In the case of Nominet this is because third party teams, be it internally or externally via contractors, are the operators of the clusters. Anything to make their workload simpler has preference in the balance between developer and operator complexity.

Before jumping onto FluxCD, which makes up the bulk of the rest of this whitepaper, it is worth discussing alternative technologies and where they sit in the problem space. You can not really safely advocate for a technology unless you know its shortcomings, and a reasonable percentage of its shortcomings will come from alternative technologies doing something better, simpler or cheaper.

### What Kubernetes Isn't

You would be forgiven for thinking kubernetes is the silver bullet that all organisations can utilise to deliver more value to the customer; reduce costs in infrastructure, improve deployment cadence and solve world hunger.

Kubernetes in _isolation_ solves **nothing**.

While I appreciate this is an incendiary judgement; as far as I have seen thus far - kubernetes is a force multiplier, but if you start with a force of zero you are not going to get anything out the back of adopting it - and worse, you will likely incur a lot of _**downsides**_.

Consider the following:

* **Is your software development lifecycle built around containers (and more recently [WASM](https://developer.okta.com/blog/2022/01/28/webassembly-on-kubernetes-with-rust) runtimes)?**

    Failing to meet this requirement means you will not benefit at all by the adoption of a platform built around orchestrating containers. This may sound obvious but having your software development lifecycle built around containers is more than slapping a Dockerfile in the project root and calling it a day. Development ideally happens in containers, testing almost definitely should happen in containers, and ultimately deployment has to work with containers - and not just use them but understand their limitations, what they can enable and the value add they bring to the situation.

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

    Even without cluster federation, being able to have multiple clusters in different regions all using the same git repository as a source of truth makes it easier to maintain a geographically dispersed fleet of workloads.

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

    Getting it out the way first, you still have servers to run these workloads - the benefit is you do not need to care about them - so far in that you are powerless to fix them. As far as you are concerned both operationally and as a developer these machines might as well not exist and you only interact with the workloads via APIs.

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

1. There is **a reason** to have multiple clusters running concurrently, for blast radius on change control and isolation of production data.
1. There is **a reason** to run _sandbox_ clusters that can clone from any cluster; for cost savings and transient use cases.
1. There is **a reason** to have different application configurations in different environments; permits testing a single component in isolation with mocked services.
1. There is **not a reason** to run different configurations of infrastructure on each cluster; there should be a baseline assumption all clusters will have the same underlying core resources available in every environment for operational overhead reductions.
1. There is **a reason** to have additional platform and potentially optional components that aren't managed by application teams; Confluent platform, Elastic platform etc.

This final assumption is a key point, the platform is a product or service in itself - too many permutations of this (even greater than one) becomes unwieldy to maintain. Consider the kubernetes platform a rough equivalent to a linux distribution with its opinionated defaults and services.

### Git Repository Structure

> **SUMMARY:** There's no single solution for laying out git repositories, they all come with trade-offs. Pick the option that gives the most benefits at the current point in time, but be mindful changing retroactively is extremely painful in a production environment.
>
> With that in mind, I'd recommend the model described by FluxCD [here](https://fluxcd.io/flux/guides/repository-structure/#repo-per-team). With the platform team owning whole ownership over the clusters and each stream aligned team owning application repositories. It is a compromise balance between access control and separation of concerns.

There are no prescribed way to lay out a GitOps workflow for kubernetes; this is partially because every business has their own physical topology and the directory topology should represent this rather than be opposed to it. Additionally the concept of directories in the state has no bearing on the cluster state, any directory layout is purely to aid the human cognitive load - you can (and should not) represent an entire kubernetes cluster in a single monolithic YAML document.

With that in mind an attempt has been made to draw up a topology in this repository that represents a balance between flexibility and declarative rigidity.

[Don't Repeat Yourself](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself) (DRY) is a contentious subject in any system that represents state declaratively, be it Terraform or Kubernetes manifests. As such there is going to be a mix of duplication and inheritance in this project, representing an attempt to strike a balance. This will only be confirmed retroactively when you try to iron out pain points where in too much inheritance ties your hands on changes having too large of a blast radius, and too much duplication adding to the cognitive load and maintenance costs of running many environments.

![repository structure high level diagram](docs/repository-directory-structure.drawio.svg)

### State Reconciliation

So with FluxCD v2 selected for the project, here's a high level view of how FluxCD works:

![gitops pull workflow using FluxCD](docs/gitops-pull.drawio.svg)

The feedback loop described by the diagram above works as follows:

1. You make a change to a YAML file(s) and commit your changes and push them to a git repository.
1. The fluxCD source controller periodically pulls the repository from git.
1. The fluxCD kustomize and helm controllers run dry run speculative applies looking for changes if the source commit hash changes.
1. Any changes detected get reconciled with any sub-object in the cluster that the root controller controls.
1. These reconciled states are now visible to the developer in their local IDE or kubernetes resource viewer _(k9s, lens etc)_.

The rationale for adopting this workflow can be broadly split up into the following goals:

* **Repeatability** - if you want multiple clusters to be in state sync they can all subscribe for changes from the same cluster. You can utilise a symlink in the `./clusters` directory to make the clusters all adhere to one state.
* **Promotion of changes** - each cluster has a state, enshrined in git; if you want to promote a change it is a case of copying a file from one directory to another and committing the changes.
* **Audit of changes** - since you're using merge requests there is an audit log in the git repository of changes made, when and by whom.
* **Disaster recovery** - since your state is in code, failing over or rebuilding any environment is easier. [^data-footnote]

[^data-footnote]: This process copies the state of a cluster but not the persistent data - underlying persistent data stored in provisioned volumes needs to be treated the same as persistent data on any server - a backup process and restore process needs to be evaluated and tested outside of the infrastructure deployment and cluster deployment lifecycles.

The tangible outcome here for teams is having a source of truth to point to and being reasonably confident that is the current state in the cluster with notifications of failure to reconcile states being other half of the process. If you push a broken chart and it fails to apply you need to know that it's failed to apply to know the state in the git repo is not the current state in the cluster.

With this brings an improvement to the confidence levels on a change, if you know the clusters are at a steady known state and you make a change to one of them the confidence making the same changes to another is increased. This isn't because the changes became less risky, this is because the changes became more visible and repeatable - trying to remove manual steps and the human element to changes. Even if you make a bad change the fact it's tracked and visible to all allows easier attribution of cause to problems, easier control to revert to a working state. Increasing confidence levels and reducing risk in changes reduces the cost of change, and reducing the cost of change is the top priority in the vast majority of architectural designs - if only because business needs are constantly changing and the inability to change to meet them is loosely branded as technical debt.

That in itself allows you to "move fast and break things" and embrace an _agile_ culture around your deliverables. Fear of breaking fragile infrastructure has hamstrung deployment cadence for as long as infrastructure has been needed.

### Cluster Configuration Change Promotion (Platform)

We have discussed how to set out a state, but we have not looked at how to make changes to this state safely and promote them between non production clusters where breaking changes are permissible and production clusters where such changes are not.

Developers follow a different change process which will be detailed later, this section is aimed at engineers who maintain the platform components deployed onto every cluster.

There are multiple patterns documented to work with this challenge, all of them have sliding scales of complexity, speed and security. Some of these trade-offs have been discussed below:

#### Monorepository Pattern

![mono-repo-promotion](docs/gitops-mono-repo.drawio.svg)

In this situation there are multiple directories in the `./clusters` directory in a monorepo, each being a source of truth to a connected fluxCD controller instance - for brevity only the development environment is detailed, though all environments follow the same pattern.

As this design currently stands, it is a single branch model - you write changes to main, those changes are represented on the resulting clusters in near realtime.

Git does not offer a concept of directory based ACL, if someone can write to a repository they could write just as easily to a staging cluster as production.

This might make production a relatively unsafe. See [Multiple Repository Pattern](#multirepository-pattern) for the trade offs of the opposing design.

In the monorepo pattern changes are promoted as such:

There are two work flows:

* A new change, that is not currently reflected on any of the existing long lived environments:

  1. Raise a ticket for the work.
  1. Create a branch.
  1. Create and bootstrap a sandbox cluster against the new branch.
    You would be attaching an ephemeral cluster to a directory of the environment you are proposing changes for. E.g. `./clusters/eu-west-2/development` in branch `NOM-12345` would be reconciled with `sandbox-cluster-23` without actual long lived environments such as development being altered - it continues to reconcile from the main branch during this process.
  1. Do some development work on the cluster.
  1. On completion, raise a merge request to the main branch.
  1. On merge those changes are propagated to the target cluster.
  1. Destroy the sandbox cluster.

* Promoting a change from a long lived environment up the stack:

  1. Raise a ticket and subsequent branch off main.
  1. Delete the environment directory locally
  1. Copy the old one in its place e.g. `./clusters/eu-west-1/staging/` gets copied to `./clusters/eu-west-1/production`.
  1. Commit those changes and push them.
  1. Raise a merge request and get it merged.
  1. Changes propagate to the target cluster.
  1. **_OPTIONAL_** - Roll back by reverting the merge request - and the previous state should be reconciled and deployed.

#### Multirepository Pattern

You can also opt for a multi-repository approach; using the Git provider ACLs to lock down certain repositories to certain users, and prevent direct pushes to the main branch.

Such a model might look more like this:

![multi-repo](docs/gitops-multi-repo.drawio.svg)

While you have traded security and access control on production for speed of change - there is an additional caveat when using a multi-repository approach to GitOps - it massively complicates shared reusable code patterns.

Propagating state between the sandboxes which are their own repositories, to the bottom end of the long lived environments (development) requires a cross repository copy/paste and merge request action. Development to staging is simpler, single repository at this point, where in a change is a simple folder replacement and merge. Much like sandbox to development, staging to production needs to cross another git repository boundary, where in the production repository has very strong access filters and merge request requirements to be met to permit a merge.

These models incur manpower costs, engineer time, but facilitate an arguably more secure model to represent the state of your infrastructure.

The trade-offs are open to debate because like all security postures, they are simply an evaluation of risk vs reward.

### Sandbox Environments

> **SUMMARY:** Sandboxes encourage the following:
>
> * Cloning the state of an existing cluster.
> * Doing provisional upgrades to the control plane and the core platform services.
> * Allow you to run single user performance tests against known states of clusters.
> * Give application teams an opinionated starting point for doing proof of concept work in a throw away repeatable manner that maps easily to downstream environments.

We have touched on these repeatedly before, but it is worth explaining why you would go the efforts of engineering to allow these to exist - after all lots of companies do not use them, nor ever find a reason to use them - so why would we?

Regardless of a monorepo, or multirepo topology - you still want environments to propose working changes on - the alternative would be forced to push fresh untested changes into the bottom of the long lived environment stack (in our model, Development).

This methodology where the development environment is a constantly shifting foundation of potentially broken infrastructure is an **anti pattern**.

It prevents development being used for its primary objective - integration testing. Development is likely to be the first changes made by multiple teams, in their own isolated sprints and release schedules will interact with each other. With this in mind and as mentioned before about minimising moving parts in any given change - infrastructure should be the stable aspect in this situation, as to allow developers to find bugs and functional issues in their code without pointing their fingers at the environmental layer underneath.

In addition to facilitating an integration environment, you will likely want to be able to do performance tests.

It is important you conduct this test in such a way that yields full confidence of change to a production platform, and thus you can not escape the reality that you need to run performance tests in an environment as identical in topology and compute resource allocation as production - and that is expensive.

To alleviate such a situation staging and other pre-production environments must be scaled down; be it in absolute compute resources such as smaller CPU/memory/disk allocations, or topological differences such as a single node where you would normally have a three node high availability cluster. Staging and other pre-production environments are in themselves considered a long running environment - ideally production-like in their operation.

Alerting and monitoring should be applied to these environments, but with out of hours alerting disabled - this is important as some infrastructure changes will be oriented around monitoring and you do not want to find out something did not work as expected the following morning when alerts did not fire in production.

Given all the above you still need to perform occasional performance tests - this is just the nature of distributed systems architecture. This is where the concept of a sandbox cluster comes into its own. Utilising the GitOps declarative model you can clone an existing production cluster topology, into a _short lived environment_ where in you can perform a battery of tests against it at the full scale production is running at.

The emphasis here is squarely on a short lived environment, though this could be measured in days or even a sprint due to the one hour overhead of deploying a new cluster. It should be possible from any given state to clone the cluster configuration (without persistent data - this is outside the scope of GitOps) and transplant it into a clone of the infrastructure, in this case a kubernetes cluster.

To summarise; sandbox environments enable you to leave long running clusters isolated so they can be used for their intended purpose and make infrastructure and/or cluster configuration changes in sandbox environments.
They also allow you to clone an expensive environment for a few hours of performance testing to increase confidence levels prior to the changes reaching production, or cloning production to try to replicate a production fault in the infrastructure (multi availability zone scheduling issues for example).

### Gitops from a Platform Team Perspective

At a high level the operational workflow of a platform team is different to a development team, as the platform conceptually is a single deployment - all the tools that make up the opinionated state of a platform deployment; storage controllers, load balancer controllers, policy enforcement controllers, etc will all end up on every cluster by definition.

This also complicates matters, when it comes to promoting breaking changes or deprecating components as downstream consumers of your services need to be involved in such decisions and actions scheduled for those teams to adjust their deployments accordingly.

![platform-as-a-service](docs/platform-as-a-service.drawio.svg)

> **NOTE:** _While the application layer is out of scope, if you are making changes that you suspect will affect a development team you should deploy their application stacks onto your sandbox cluster to confirm a healthy state is achieved, and if not - tickets scheduled with the team warning them of upcoming changes that will incur work to be done._

If you take this model, with everything resting on the kubernetes control plane (everything below this is out of scope for the platform team) then the most common breaking change pattern will be as follows:

1. Upstream kubernetes upgrades are mandated with a breaking change, often promotion of beta APIs to stable.
1. Upstream helm charts that rely on those core APIs will also change and often take the opportunity to include breaking changes when their underlying APIs change.
1. Applications deployed on the cluster will also need to take into account these changing APIs; e.g. kyverno policies, ALB service annotations, storage class changes.

As you can see the changes at the bottom of the platform are often felt entirely through the stack, as is the nature of foundational changes. Often third parties will minimise the pain felt by such changes by abstracting the changes in the intermediate layers thereby leaving the application layer none the wiser about the changes below, but this is far from certain and with the operator/controller pattern being in its infancy in the kubernetes ecosystem there are often more breaking changes in the intermediate layers between the cluster control plane and the applications than the control plane itself.

Hopefully this will settle in due time as maturity takes hold in the design and deployment cycles of the operators that applications leverage.

With the above in mind, it is apparent that the platform team will be likely at the forefront of the breaking changes and change cycles in a clusters lifecycle. You may even get to a point where application stacks on top of the cluster are quite stable, with very infrequent release schedules for their own internally derived roadmap. This in reality does not notably reduce the amount of releases a team must make, if only because they will have change thrust upon them from below - directly via kubernetes upgrades and indirectly via shared resources the applications require to run.

#### Exploratory Change Process

Aside from the minor and patch version bumping of helm charts in the service tier, the most common and disruptive task in the platform team would be upgrading the kubernetes control plane itself - at the time of writing the release cadence recently dropped from four releases a year to three, but that still means dealing with this every four months.

The kubernetes control plane has a rolling window of supporting APIs, which in theory aids the migration and upgrade of clusters. Warnings on deprecation of APIs and object types are made well in advance with some lead times in the years. This leniency in fixing dependencies downstream of the control plane is only useful if you are able to keep on top of the deprecation warnings themselves.

There are tools out there to pre-warn you of upcoming hard deprecations, and when you can expect your cluster state to fail if you upgrade the control plane without changes:

1. [pluto](https://github.com/FairwindsOps/pluto) - _A cli tool to help discover deprecated apiVersions in Kubernetes_
1. [kubent](https://github.com/doitintl/kube-no-trouble) - _Easily check your clusters for use of deprecated APIs_

Both tools offer an overlapping venn diagram of features so evaluate both at the time of reading.

So now you have a grasp on some up coming changes, what's next? Well you need to create a cluster to try to mitigate these changes, usually with a newer control plane as to experiment with the breaking changes.

Before making changes to a cluster it is worth talking about the differences between an OCI artifact and a git repository souce; the former providers stability and strong versioning guarantees and the latter allows you to free form track a state in a git repository - be it the main branch or any other.

Long lived stable clusters **must** track against OCI artifacts:

Let's take this example below of `./clusters/production/flux-system/platform.yaml` and examine the behaviour the resulting configuration would have in the host cluster.

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: OCIRepository
metadata:
  name: platform
  namespace: flux-system
spec:
  secretRef:
    name: gitlab-registry
  interval: 1m0s
  url: oci://registry.gitlab.com/***REMOVED***/fluxcd-demo
  ref:
    semver: 0.0.x 
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: platform-services
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./platform/services
  prune: true
  sourceRef:
    kind: OCIRepository
    name: platform
```

In this configuration the `./clusters/production/flux-system/platform.yaml` file is tracking OCI artifacts produced in a pipeline - they're versioned by tag. Additionally there is [semver](https://semver.org/) tracking, where in you can follow major, minor and patch versions and the latest of which is re-evaluated at the interval period.

If you push a `0.0.3` tagged OCI artifact, and `0.0.2` is currently running in the cluster, then the rules above would download the 0.0.3 artifact and trigger reconciliation on the downstream dependencies that use this OCIRepository source.

The constraints on this behaviour are defined in the `.spec.ref.semver` value, and they're evaluated against [this](https://github.com/Masterminds/semver#checking-version-constraints) ruleset.

Recommendations to lean into semver in a useful way for versioning and distribution of your platform stack:

* **Production tracks patch versions only**, e.g. `1.2.x`

    Useful for minor changes automatically being propagated out to production.
* **Staging tracks minor versions only**, e.g. `1.x.x`

    Not expecting breaking changes but functionality changes that need evaluating prior to production.
* **Development tracks the same as staging**, e.g. `1.x.x`

    Additionally you could track major changes depending on maturity of the platform stack and appetite for risk e.g. `x.x.x`.

Production can of course just a static tag either by specifying the full semver alias in the `.spec.ref.semver` value, or by using an OCI release tag using the `.spec.ref.tag` value.

Sandboxes depending on their intended use cases will track differently:

* **Performance test against a long lived named environment**

    You would track the same semver or tag version as the source environment/cluster when cloning an environment, e.g. no change to the repository object.
* **Platform team doing routine maintenance on downstream helm charts**

    You would likely want to track against the latest semver version and tag your change in the platform repository to trigger a new package being deployed and tested.
* **Platform team doing a control plane upgrade**

    In this scenario with all else being equal you would just clone development and run the control plane upgrade, confirm it is working with the same platform components as development and then mainline the changes back to the development cluster.
* **Platform team deprecating/adding major service components**

    Given this is the most invasive of the changes a platform team is likely to make it makes sense to stop tracking OCIRepository and instead tracking against a GitRepository

    ```yaml
    ---
    apiVersion: source.toolkit.fluxcd.io/v1
    kind: GitRepository
    metadata:
    name: platform
    namespace: flux-system
    spec:
    interval: 1m0s
    ref:
        branch: main
    secretRef:
        name: flux-system
    url: https://gitlab.com/***REMOVED***/fluxcd-demo.git
    ```

    Additionally to adding this GitRepository object, you would need to change the references in your Kustomization objects:

    ```yaml
    apiVersion: kustomize.toolkit.fluxcd.io/v1
    kind: Kustomization
    metadata:
    name: platform-services
    namespace: flux-system
    spec:
    interval: 10m0s
    path: ./platform/services
    prune: true
    sourceRef:
        {- kind: OCIRepository -}
        {+ kind: GitRepository -}
        name: platform
    ```

---

1. Deploy a new instance of the kubernetes infrastructure of code - incrementing the control plane version or any other baseline modules you have breaking changes in. e.g. kubernetes being bumped from 1.26 to 1.27.
1. Provide some OCI secrets to access helm charts and other manifests from a OCI registry: [^registry-creds]

    [^registry-creds]:  You may want to include this in the terraform state using a gitlab provider to provision some credentials in the cluster creation state but it isn't essential to do so.

    ```shell
    kubectl create secret docker-registry gitlab-registry --docker-server=registry.gitlab.com --docker-username=<GITLAB_USERNAME> --docker-password=<PERSONAL_ACCESS_TOKEN> -n flux-system
    ```

1. Copy the cluster you wish to clone from in the `./clusters/` directory, to a new cluster.

    ```shell
    rsync -av --exclude='*/gotk-sync.yaml' "./clusters/staging/" "./clusters/sandbox-a"
    ```

1. Run FluxCD bootstrap on the new cluster to overwrite the values in the `flux-system` directory in the cluster directory, this is required to connect the reconciliation loop between source and cluster.

    ```shell
    export GITLAB_TOKEN=<a personal access token with api and write_repo scopes>
    flux bootstrap gitlab --token-auth --owner "***REMOVED***" --repository "fluxcd-demo" --path "./clusters/cluster-a"
    ```

1. Make your changes to the platform helm charts and values.
1. Run any validation and testing scripts you have accumulated over time, or manually test the cluster to be confident the changes haven't impacted the services.
1. Copy the directory back to the source, omitting the `flux-system/gotk-sync.yaml` file.

    ```shell
    rsync -av --exclude='*/gotk-sync.yaml' "./clusters/sandbox-a/" "./clusters/staging"
    ```

    > **WARNING:** _It is **essential** you do not copy the `gotk-sync.yaml` directory back to the source or the root level `flux-system` kustomization will be sourcing files from the wrong directory.

1. Monitor the change reconciliation and deployment on the parent cluster.
1. If it goes well, delete the sandbox cluster directory, if not, revert the commit and revert the parent cluster state.
    > **NOTE:** _At this point your changes to the cluster are internal, the version of kubernetes itself has not been changed thus far._
1. Re-run the IAC that controls the parent cluster to bump the kubernetes cluster version. Everything should upgrade and settle down afterwards.
1. Destroy the sandbox kubernetes cluster stack. See [deleting a cluster](#deleting-a-cluster) for details.

The same loosely defined methodology would apply to migrating changes up the long lived cluster stack - from development, to staging to production.

The notable difference is you aren't bringing your own infrastructure stacks to the party and you're essentially just copying the state FluxCD reconciles against up the directory tree.

1. Once you're happy with development cluster state, both in the on cluster workloads defined by FluxCD and the kubernetes control plane versions it is time to promote the state up the chain.
1. Copy the `./clusters/development` directory to `./clusters/staging` again omitting the `flux-system/gotk-sync.yaml` file.

    ```shell
    rsync -av --exclude='*/gotk-sync.yaml' "./clusters/development/" "./clusters/staging"`
    ```

1. Save, commit and push the changes to the git repository.
1. Let the cluster reconcile a new state. If any issues arise it is best to tackle them now prior to any infrastructure as code changes. If you need to revert, now is the time to revert the git commit that copied the directory state across.
1. Assuming the above steps are successful, run the upgrade in the infrastructure as code stack to bring the cluster control plane up to parity with the source cluster.
1. Congratulations you've upgraded your long lived environment and propagated the changes to the next one.

This process would follow the same path for changes being promoted from staging to production.

### Gitops from a Development Team Perspective

Congratulations, as a development team your only concern is around the application layer - and while that is not devoid of danger, it is however a lot fewer moving parts to worry about and the ones you do have to are somewhat in your gift to control and change.

**_NOTES FOR MONDAY_**

* [ ] Cover helm release semver ranges; patch for production, minor for staging and major for development.
* [ ] Cover image deployments.
* [ ] Cover best practices and talk about 12 factor apps.
* [ ] Emphasise loose decoupling of services, make assumptions the platform is providing things rather than provide them yourself. e.g. Confluent for Kubernetes operators.
* [ ] Try to make your application namespace agnostic, and deploy _all_ the components in the same namespace for portability.
* [ ] Trade-offs between helm charts and raw manifests installed via kustomize.
* [ ] Emphasise the differences between an application and components of the application. Explain trade-offs between stand alone "external" components vs application components.
* [ ] Mocks are really important and key to isolation of deployment, sometimes you just want to deploy and test a single helm chart in isolation.

### Deleting a Cluster

Since FluxCD is a reconciliation loop to retain state, you have two options to remove a cluster:

* Delete the state bit by bit in the git repository and let FluxCD uninstall everything in the order you want it to go (service configurations before services which provide custom resource definitions and [finaliser](https://kubernetes.io/docs/concepts/overview/working-with-objects/finalizers/) functions).
* Suspend the reconciliation at the source and delete the objects in the cluster.

The latter makes more sense when you are operating in a "main" only branch repository, as to make reverting commits easier.

1. Suspend the root FluxCD entrypoint to prevent self healing of children objects - `flux suspend ks flux-system`
1. Delete the application HelmReleases/Kustomization objects - this is to trigger the finalisers to clear down external resources; EBS volumes, ALB etc.
1. Return the cluster to its freshly bootstrapped state sans any external state. You should be left with a single `flux-system` kustomization and no HelmRelease objects.
1. Destroy the kubernetes cluster using the infrastructure as code that deployed it initially.

> **NOTE:** _As a nice to have it would be worth scripting the clean down procedure, but it is considerably easier than the existing deletion scripts - list all the kustomizations and helm charts with an annotation or label matching a value indicating they mutate state and then subsequently deleting them via kubectl._
>
> _It makes a lot of sense to start using annotations liberally on this, so you can differentiate between a helm chart of kustomization that provides a custom resource definition and subsequently a controller, and charts which use those. You **must** remove the custom objects before the controllers, or finalisers cannot be triggered and thus you will end up with dangling resources - some of which will cause your IAC to fail when trying to remove a VPC as those resources are likely still bound inside the VPC (Application load balancers etc)._

## Working Examples

This repository contains working examples in addition to the whitepaper you are currently reading.

### Deployment

To demo multi cluster workflows locally the best option you have is to use [kind](https://kind.sigs.k8s.io/) clusters.

The only prerequisite is having access to a docker runtime and at least 8GB of memory assigned to the docker environment.

1. Create the kind clusters:

    ```shell
    kind create cluster --config create/staging.yaml
    kind create cluster --config create/production.yaml
    ```

1. Bootstrap the clusters with FluxCD:

    ```shell
    export GITLAB_TOKEN=<your personal access token with api and write_repo scoped roles>
    flux bootstrap gitlab --context kind-staging --token-auth --owner ***REMOVED*** --repository fluxcd-demo --path ./clusters/staging 
    flux bootstrap gitlab --context kind-production --token-auth --owner ***REMOVED*** --repository fluxcd-demo --path ./clusters/production 
    ```

1. Add Gitlab Container Registry secret to the flux-system namespace:

    ```shell
    kubectl create secret docker-registry gitlab-registry --docker-server=registry.gitlab.com --docker-username=<GITLAB_USERNAME> --docker-password=<PERSONAL_ACCESS_TOKEN> -n flux-system
    ```

1. Now your clusters will be following the state of this repository, as dictated by the `clusters/` directory.

### Clean up

Since these clusters are local, with no external state being deployed you can safely delete the kind clusters without removing anything flux has provisioned:

```shell
kind delete cluster --name staging
kind delete cluster --name production
```
