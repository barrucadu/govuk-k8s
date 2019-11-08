Provisioning
============

Pre-requisites:

- Install `terraform`
- Set up your `~/.aws/credentials` file, you'll need a profile called `govuk-k8s`

Scripts:

- `./create.sh` - run terraform, ssh into machines, build NixOS config
- `./deploy-terraform.sh` - deploy terraform changes
- `./deploy-nixos.sh` - deploy NixOS changes
- `./destroy.sh` - tear down the cluster

You should destroy your cluster at the end of every tinkering session
to avoid spending unnecessary money.


Architecture
------------

The terraform defines a VPC (virtual private cloud) some EC2
instances, domain names, and security rules:

| Name          | Type        | Visibility         | Purpose                        |
| ------------- | ----------- | ------------------ | ------------------------------ |
| `jumpbox`     | `t3.medium` | internal, external | external entry point to VPC    |
| `k8s-master`  | `t3.medium` | internal           | orchestrates k8s cluster       |
| `k8s-slave-0` | `m5.xlarge` | internal           | runs k8s workloads             |
| `k8s-slave-1` | `m5.xlarge` | internal           | runs k8s workloads             |

The `jumpbox` is accessible to SSH externally, and can SSH into all
the internal machines.  The internal machines are not accessible
externally.

Internal domains are subdomains of `govuk-k8s.test`: [`.test` is a
reserved TLD][] so this will not clash with any real-world domains.

[`.test` is a reserved TLD]: https://tools.ietf.org/html/rfc2606

You may want to customise the following variables:

| Variable                       | Default                           | Meaning                                              |
| ------------------------------ | --------------------------------- | ---------------------------------------------------- |
| `aws_region`                   | `eu-west-2`                       | where the infrastructure is created                  |
| `aws_profile`                  | `govuk-k8s`                       | credentials profile to use                           |
| `ec2_ami`                      | `ami-02a2b5480a79084b7`           | AMI to use (region-specific)                         |
| `external_domain_name`         | `govuk-k8s.barrucadu.co.uk`       | publicly-visible domains will be a subdomain of this |
| `provisioning_public_key_file` | `/home/barrucadu/.ssh/id_rsa.pub` | SSH public key to use for provisioning               |
| `k8s_slaves`                   | `2`                               | number of k8s-slave instances to create              |
