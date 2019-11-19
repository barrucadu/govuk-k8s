AWS provisioning
================

Pre-requisites:

- Your PATH needs to contain:
  - `aws-iam-authenticator`
  - `kubectl`
  - `terraform`
- Set up your `~/.aws/credentials` file, you'll need a profile called `govuk-k8s`

Scripts:

- `./create.sh` - run `deploy-*` scripts
- `./deploy-terraform.sh` - deploy terraform changes
- `./deploy-nixos.sh` - deploy NixOS changes
- `./deploy-k8s.sh` - configure master and join slaves to cluster
- `./shrink.sh` - tear down everything but the public DNS zone and egress IP ranges
- `./destroy.sh` - tear down the cluster

You should shrink or destroy your cluster at the end of every
tinkering session to avoid spending unnecessary money.


Architecture
------------

The terraform defines a VPC (virtual private cloud), an EKS cluster,
some EC2 instances, domain names, and security rules.

The default configuration is:

| Name          | Type       | Visibility         | Purpose                    |
| ------------- | ---------- | ------------------ | -------------------------- |
| `ci`          | `m5.large` | internal, external | concourse worker node      |
| `jumpbox`     | `t3.micro` | internal, external | SSH entry point to VPC     |
| `web`         | `t3.small` | internal, external | HTTP(S) entry point to VPC |
| `registry`    | `t3.small` | internal           | private docker registry    |

There are also some EC2 instances for EKS to use as worker nodes,
hidden behind an auto-scaling group.  These don't have names.  The
default configuration is to have 2 `m5.large` instances for this.

Each machine, other than the EKS workers, has an internal DNS record
of `${name}.govuk-k8s.test`.  [`.test` is a reserved TLD][] so this
will not clash with any real-world domains.

[`.test` is a reserved TLD]: https://tools.ietf.org/html/rfc2606

With these DNS records:

| Record             | Type | Zone     | Target         |
| ------------------ | ---- | -------- | -------------- |
| `ci`               | A    | external | `ci`           |
| `jumpbox`          | A    | external | `jumpbox`      |
| `*.govuk.web`      | A    | external | `web`          |
| `*.live.web`       | A    | external | `web`          |
| `ci`               | A    | internal | `ci`           |
| `jumpbox`          | A    | internal | `jumpbox`      |
| `registry`         | A    | internal | `registry`     |
| `web`              | A    | internal | `web`          |

Internal domain names for services deployed to the cluster are created
as needed.  These follow the pattern
`$app.$namespace.in-cluster.govuk-k8s.test`.

To make the external domains work across the wider internet, you need
to configure NS records wherever you host the DNS for that domain.
`create.sh` and `../util/infra-info.sh` scripts can tell you those.


IP Ranges
---------

There are a few different needs for IP ranges, so to keep everything
clear and separate, here they all are:

| CIDR          | Scope          | Availability zone | Purpose                               |
| ------------- | -------------- | ----------------- | ------------------------------------- |
| `10.0.0.0/16` | VPC            | -                 | addressable AWS entities              |
| `10.0.0.0/24` | Public subnet  | `eu-west-2a`      | things accessible to the internet     |
| `10.0.1.0/24` | Private subnet | `eu-west-2a`      | things not accessible to the internet |
| `10.0.2.0/24` | Public subnet  | `eu-west-2b`      | things accessible to the internet     |
| `10.0.3.0/24` | Private subnet | `eu-west-2b`      | things not accessible to the internet |
| `10.0.4.0/24` | Public subnet  | `eu-west-2c`      | things accessible to the internet     |
| `10.0.5.0/24` | Private subnet | `eu-west-2c`      | things not accessible to the internet |


£££
---

To save some money, run `shrink.sh` when the cluster isn't needed.
This script tears down everything except:

- The VPC
- The internet gateway
- The Elastic IP used for NAT
- The external DNS zone

This is the minimal set of resources needed so that NS records and
egress IP ranges don't change.

Bring the cluster back by running `create.sh`.
