# FluxCD Test Repo


## Deployment

### Local

```
export GITLAB_TOKEN= # put your personal access token here with api, read_api and read_repository access
flux bootstrap gitlab --token-auth --owner=nominet/cyber/architecture-team --repository=fluxcd-testbed --branch=reorg --verbose --path=./clusters/local
```