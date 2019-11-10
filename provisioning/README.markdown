Provisioning
============

Pre-requisites:

- Install `terraform`
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

The terraform defines a VPC (virtual private cloud) some EC2
instances, domain names, and security rules.

The default configuration is:

| Name          | Type        | Visibility         | Purpose                    |
| ------------- | ----------- | ------------------ | -------------------------- |
| `ci`          | `m5.xlarge` | internal, external | concourse worker node      |
| `jumpbox`     | `t3.medium` | internal, external | SSH entry point to VPC     |
| `web`         | `t3.medium` | internal, external | HTTP(S) entry point to VPC |
| `registry`    | `t3.medium` | internal           | private docker registry    |
| `k8s-master`  | `t3.medium` | internal           | orchestrates k8s cluster   |
| `k8s-slave-0` | `m5.xlarge` | internal           | runs k8s workloads         |
| `k8s-slave-1` | `m5.xlarge` | internal           | runs k8s workloads         |

Each machine gets an internal DNS record of `${name}.govuk-k8s.test`.
[`.test` is a reserved TLD][] so this will not clash with any
real-world domains.

[`.test` is a reserved TLD]: https://tools.ietf.org/html/rfc2606

With these DNS records:

| Record             | Type | Zone     | Target         |
| ------------------ | ---- | -------- | -------------- |
| `ci`               | A    | external | `ci`           |
| `jumpbox`          | A    | external | `jumpbox`      |
| `web`              | A    | external | `web`          |
| `*.web`            | A    | external | `web`          |
| `*.live.web`       | A    | external | `web`          |
| `ci`               | A    | internal | `ci`           |
| `jumpbox`          | A    | internal | `jumpbox`      |
| `registry`         | A    | internal | `registry`     |
| `web`              | A    | internal | `web`          |
| `k8s-master`       | A    | internal | `k8s-master`   |
| `k8s-slave-$n`     | A    | internal | `k8s-slave-$n` |

To make the external domains work across the wider internet, you need
to configure NS records wherever you host the DNS for that domain.
`create.sh` and `terraform/info.sh` scripts can tell you those.


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
