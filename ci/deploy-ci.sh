#!/usr/bin/env bash

set -e

HERE="$(git rev-parse --show-toplevel)/ci"
cd "$HERE"

if [[ -z "$FLY_LOGGED_IN" ]]; then
    ./concourse/login.sh
fi

./pipelines/generate-ci-yaml.py > pipelines/ci.yaml

yes | fly set-pipeline -t govuk-k8s -p ci -c pipelines/ci.yaml

fly unpause-pipeline -t govuk-k8s -p ci
