# High Level Goals

- [ ] Document high level concepts and shared best practices around this topic.
  - [x] GitOps - What is it?
  - [x] Pull vs Push GitOps methodologies.
  - [x] Kubernetes - What is it? What is it not? How does it fit into the GitOps ecosystem?
  - [-] If not kubernetes, then what?
- [ ] Kubernetes specific goals
  - [ ] Comparisons of tooling in this ecosystem.
  - [-] Git repository layouts and their trade-offs.
  - [ ] FluxCD workflows - what does it achieve, how and what are the tangible outcomes?
  - [ ] Increase the velocity of promoting changes between clusters.
  - [ ] Increase the confidence levels in proposed changes, thus reducing the cost of change.
  - [ ] Encourage using ephemeral clusters to experiment with newer versions of kubernetes, to be a canary deployment for upcoming changes.
  - [ ] Document using local kubernetes cluster examples with an emphasis on localised isolated component deployments.
- [ ] Application specific goals
  - [ ] Demonstrate the role quality assurance processes have in increasing confidence in the change management process.
  - [ ] Document an end to end software development lifecycle built around containers as a distribution mechanism.
  - [ ] Working example of an example project; taken from a local development environment through various kubernetes environment deployments until production.
  - [ ] Document any kubernetes abstractions to be aware of when building applications to better integrate with the platform.
  - [ ] Explore and document any tooling that aids fast feedback cycles for developers.
- [ ] Platform specific goals
  - [ ] Explore and document trade offs in handling external infrastructure deployments within a kubernetes context.
  - [ ] Monitoring and alerting strategies.
  - [ ] Document kubernetes operators - self-service opinionated resource bundles for developers.
  - [ ] Self service pipelines to reduce the toil when deploying temporary kubernetes clusters for ephemeral workloads.
  - [ ] Explore Weaveworks eksctl, kubernetes cluster Downward API/Metadata APIs and Weaveworks Terraform controller
    - [ ] Should the kubernetes cluster be the centre of the platform universe in a cloud environment?
    - [ ] If it is; how does it become contextually aware of its surroundings? VPC locality and the bearing that has on accessing other resources?
    - [ ] If it is not; how does one cleanly sever the dependency chain so that applications just fail to start if resources are not accessible?
- [ ] Summary and conclusions
  - [ ] Estimate costs to implement the whitepaper.
  - [ ] Estimate costs to not implement the whitepaper.


