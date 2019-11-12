#!/usr/bin/env bash

set -e

HERE="$(git rev-parse --show-toplevel)/ci"
cd "$HERE"

./concourse/login.sh

export FLY_LOGGED_IN=1
./deploy-ci.sh
./build-all-apps.sh
