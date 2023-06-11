# Kubernetes - Software Development Lifecycle

![latest](https://ghcr-badge.egpl.dev/danielloader/manifests/platform/latest_tag?trim=major&label=platform&ignore=sha256*)
![size](https://ghcr-badge.egpl.dev/danielloader/manifests/platform/size)
<!-- --8<-- [start:intro] -->

This project serves as a proof of concept implementation and associated documentation around utilising kubernetes to enable a modern software development lifecycle - not just for software development but platform engineering.

Topics:

- High level concepts about the components and moving parts in play.
- Composition over inheritance in context with infrastructure.
- External cloud resources and where they fit into the kubernetes ecosystem.
- End to End change promotion scenarios.
- A working example using local kubernetes environments.

<!-- --8<-- [end:intro] -->

Published documentation is served by [github pages](https://danielloader.github.io/kubernetes-sdlc/).

## Documentation

The documentation in this repository is built via `mkdocs`. To start a local development server either use the command directly or call `task serve`.

```shell
docker run --rm -it -p 8000:8000 -v ${PWD}:/docs $(docker build -q . -f Dockerfile.local)
```
