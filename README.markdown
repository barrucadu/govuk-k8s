GOV.UK on Kubernetes
====================

Kubernetes (or "k8s" if you hate typing) is the cool kid on the cloud
computing block, so I decided to learn some of it by getting
[GOV.UK][], a distributed system I know well, up and running in k8s.

Kubernetes is a container orchestration system but, in reality, GOV.UK
is not running in containers.  We're doing everything the old
fashioned way: stuff installed onto VMs.  Luckily we've produced a
dockerised local development environment, [govuk-docker][], which I
hope I'll be able to heavily borrow from.

Tools used:

- [Kubernetes][], for container orchestration.
- [Concourse][], for continuous integration.
- [Terraform][], to create the infrastructure underpinning k8s.
- [NixOS][], to configure the infrastructure underpinning k8s.

[GOV.UK]: https://www.gov.uk
[govuk-docker]: https://github.com/alphagov/govuk-docker
[Kubernetes]: https://kubernetes.io/
[Concourse]: https://concourse-ci.org/
[Terraform]: https://www.terraform.io/
[NixOS]: https://nixos.org/


Set-up
------

### 1. Deploy infrastructure

```bash
# Generate config file based on the comments
cp config.template config
nano config

# Generate Terraform and NixOS configurations
./generate-config.sh

# Conjure infrastructure out of thin air
./provisioning/create.sh
```

### 2. Add DNS records

The `./provisioning/create.sh` script gives you a list of nameservers
to point your external domain name to.  Add the NS records wherever
you manage your DNS.

If you missed the nameserver output, you can get them with
`./util/infra-info.sh`.

### 3. Deploy CI and build apps

After DNS has resolved and `ci.<external domain>` works you can deploy
the Concourse configuration and trigger a build of all the apps:

```bash
./ci/create.sh
```

### 4. Deploy live environment

Now deploy the "live" environment configuration:

```bash
./kubernetes/deploy.sh live
```

You don't need to wait for Concourse to finish building the apps to do
this, Kubernetes will retry downloading any images which aren't yet
ready.

When everything is up and running, you will be able to access the
cluster at `www-origin.live.web.<external domain>` and
`<app>.live.web.<external domain>`.

Troubleshooting
---------------

### An app isn't working

Some useful commands to check the status of the apps are:

```bash
# List all pods
./util/kubectl.sh --namespace=live get pods

# Give detailed information about a pod
./util/kubectl.sh --namespace=live describe pod <pod name>

# Retrieve the logs of a pod and follow updates
./util/kubectl.sh --namespace=live logs -f <pod name>
```

### I get 502 Bad Gateway errors

Some things to check are:

- Are the pods receiving the request but hitting an error?
- Do the caddy logs on the `web` machine show any problems?
- Can internal domain names, like `finder-frontend.live.in-cluster.govuk-k8s.test` be resolved from the `web` machine?
- Do the ALBs exist in the AWS Console?  Do they have healthy instances?
- Do the Route53 records exist in the AWS Console?  Do they point to the right ALBs?

Note that it can take a few minutes for the web server to first
resolve the new internal domains.
