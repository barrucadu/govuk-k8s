#!/bin/sh

set -e

./deploy-terraform.sh
./deploy-nixos.sh

cd terraform
./info.sh
