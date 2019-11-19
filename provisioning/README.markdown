Provisioning
============

Pre-requisites:

- AWS mode:
  - Your PATH needs to contain:
    - `aws-iam-authenticator`
    - `kubectl`
    - `terraform`
  - Set up your `~/.aws/credentials` file, you'll need a profile called `govuk-k8s`

- Local mode:
  - Your PATH needs to contain:
    - `docker`
    - `docker-compose`
    - `kubectl`
    - `kind` (at least 0.6.0)

Scripts:

- `./create.sh` - set up the cluster
- `./destroy.sh` - tear down the cluster

The subdirectories have more specific READMEs and scripts.
