#!/bin/sh

set -e

cd terraform

echo "replacing main.tf with shrink/main.tf..."
mv main.tf main.tf-backup
cp shrink/main.tf .
trap 'echo "restoring main.tf..."; mv main.tf-backup main.tf' EXIT

terraform apply "$@"
