#!/usr/bin/env bash

set -e

TOP="$(git rev-parse --show-toplevel)"
source "${TOP}/config"

if [[ "$MODE" != "aws" ]]; then
    echo "MODE != aws"
    exit 1
fi

HERE="${TOP}/provisioning/aws"
cd "$HERE/terraform"

echo "replacing main.tf with shrink/main.tf..."
mv main.tf main.tf-backup
cp shrink/main.tf .
trap 'echo "restoring main.tf..."; mv main.tf-backup main.tf' EXIT

terraform apply "$@"
