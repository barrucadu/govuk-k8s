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
instances, domain names, and security rules:

| Name          | Type        | Visibility         | Purpose                    |
| ------------- | ----------- | ------------------ | -------------------------- |
| `jumpbox`     | `t3.medium` | internal, external | SSH entry point to VPC     |
| `web`         | `t3.medium` | internal, external | HTTP(S) entry point to VPC |
| `k8s-master`  | `t3.medium` | internal           | orchestrates k8s cluster   |
| `k8s-slave-0` | `m5.xlarge` | internal           | runs k8s workloads         |
| `k8s-slave-1` | `m5.xlarge` | internal           | runs k8s workloads         |

Internal domains are subdomains of `govuk-k8s.test`: [`.test` is a
reserved TLD][] so this will not clash with any real-world domains.

[`.test` is a reserved TLD]: https://tools.ietf.org/html/rfc2606

You may want to customise the following terraform variables:

| Variable                       | Default                           | Meaning                                              |
| ------------------------------ | --------------------------------- | ---------------------------------------------------- |
| `aws_region`                   | `eu-west-2`                       | where the infrastructure is created                  |
| `aws_profile`                  | `govuk-k8s`                       | credentials profile to use                           |
| `ec2_ami`                      | `ami-02a2b5480a79084b7`           | AMI to use (region-specific)                         |
| `external_domain_name`         | `govuk-k8s.barrucadu.co.uk`       | publicly-visible domains will be a subdomain of this |
| `provisioning_public_key_file` | `/home/barrucadu/.ssh/id_rsa.pub` | SSH public key to use for provisioning               |
| `k8s_slaves`                   | `2`                               | number of k8s-slave instances to create              |
| `web_subdomains`               | `["live", "management"]`          | add DNS records for *.subdomain and * to the web box |

The `external_domain_name` is also specified in `nixos/common.nix`,
and must be kept in sync with the value in terraform.


DNS
---

The following DNS records are created:

| Record             | Type | Zone     | Target         |
| ------------------ | ---- | -------- | -------------- |
| `jumpbox`          | A    | external | `jumpbox`      |
| `web`              | A    | external | `web`          |
| `*.web`            | A    | external | `web`          |
| `*.live.web`       | A    | external | `web`          |
| `*.management.web` | A    | external | `web`          |
| `jumpbox`          | A    | internal | `jumpbox`      |
| `web`              | A    | internal | `web`          |
| `k8s-master`       | A    | internal | `k8s-master`   |
| `k8s-slave-$n`     | A    | internal | `k8s-slave-$n` |

To make the external domains work across the wider internet, you need
to configure NS records wherever you host the DNS for that domain.
`create.sh` and `terraform/info.sh` scripts can tell you those.


HTTPS
-----

The `web` instance can serve HTTPS, if your DNS records have
propagated: check that `web.${external_domain_name}` resolves first.
Then set `enableHTTPS` and, optionally, `forceHTTPS` in
`nixos/common.nix` and run `deploy-nixos.sh`.


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
