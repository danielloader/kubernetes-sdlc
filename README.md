# FluxCD Test Repo


## Deployment

### Local

```
export GITLAB_TOKEN= # put your personal access token here with api, read_api and read_repository access
flux bootstrap gitlab --token-auth --owner=***REMOVED*** --repository=fluxcd-testbed --branch=main --verbose --path=./clusters/local
```