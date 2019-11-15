#!/usr/bin/env bash

set -e

HERE="$(git rev-parse --show-toplevel)/provisioning"
cd "$HERE/terraform"

terraform init
terraform apply "$@"
