# FluxCD - Change Control and Kubernetes

## Documentation

The documentation in this repository is built via `mkdocs`. To start a local development server either use the command directly or call `task serve`.

```shell
docker run --rm -it -p 8000:8000 -v ${PWD}:/docs $(docker build -q . -f Dockerfile.local)
```
