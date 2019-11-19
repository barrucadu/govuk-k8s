Local provisioning
==================

Pre-requisites:

- Your PATH needs to contain:
  - `docker`
  - `docker-compose`
  - `kubectl`
  - `kind` (at least 0.6.0)

Scripts:

- `./create.sh` - set up the cluster
- `./destroy.sh` - tear down the cluster
- `./etc-hosts-entries.sh` - list necessary `/etc/hosts` entries


How it works
------------

These scripts use [`kind`][] (Kubernetes in Docker) to run a local
cluster and `docker-compose` to run the Concourse instance and Docker
registry.

Everything uses internal (`*.govuk-k8s.test`) hostnames.  The
`create.sh` script gives you a list of entries to add to your
`/etc/hosts` file.  You can see this list again by running
`./etc-hosts-entries.sh`.

TODO:

- Proxy

[kind]: https://kind.sigs.k8s.io/
