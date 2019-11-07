#!/bin/sh

set -e

cd terraform
terraform destroy "$@"
