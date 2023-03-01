# Send to Allure Docker Service action


Sends results to [fescobar/allure-docker-service](https://github.com/fescobar/allure-docker-service).

## Inputs

### `allure_results`

allure results directory to send.

Default - `allure-results`

______
### `project_id` 
project id in docker service

Default - `default`
______

### `auth`
turn auth on/off for sending

Default - `true`

______

### `generate`
generate report after sending results

Default - `false`

______

## Secrets

- `ALLURE_SERVER_URL` - **required** server URL. 
- `ALLURE_SERVER_USER` - **required** username. 
- `ALLURE_SERVER_PASSWORD` - **required** password
#### [How to set secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

## Example usage

```yml
jobs:
  allure-docker-send-example:
    runs-on: self-hosted

    name: Send to Allure Docker Service

    env:
      ALLURE_SERVER_URL: ${{ secrets.ALLURE_SERVER_URL }}
      ALLURE_SERVER_USER: ${{ secrets.ALLURE_SERVER_USER }}
      ALLURE_SERVER_PASSWORD: ${{ secrets.ALLURE_SERVER_PASSWORD }}

    steps:
      - uses: actions/checkout@v2

      - uses: ContaQuanto/send-to-allure-docker-service-action@main
        with:
          allure_results: allure-results
          project_id: ${{ steps.slugrepo.outputs.repo }}
          auth: true
          generate: true
```