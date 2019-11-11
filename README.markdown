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
- [Terraform][], to create the infrastructure underpinning k8s.
- [NixOS][], to configure the infrastructure underpinning k8s.

[GOV.UK]: https://www.gov.uk
[govuk-docker]: https://github.com/alphagov/govuk-docker
[Kubernetes]: https://kubernetes.io/
[Terraform]: https://www.terraform.io/
[NixOS]: https://nixos.org/


Set-up
------

```bash
# Generate config file based on the comments
cp config.template config
nano config

# Generate Terraform and NixOS configurations
./generate-config.sh

# Conjure infrastructure out of thin air
./provisioning/create.sh
```
