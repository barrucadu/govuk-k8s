#!/usr/bin/env bash

set -e

HERE="$(git rev-parse --show-toplevel)/provisioning"
cd "$HERE/terraform"

echo "replacing main.tf with shrink/main.tf..."
mv main.tf main.tf-backup
cp shrink/main.tf .
trap 'echo "restoring main.tf..."; mv main.tf-backup main.tf' EXIT

terraform apply "$@"
