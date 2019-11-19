#!/usr/bin/env bash

set -e

TOP="$(git rev-parse --show-toplevel)"
source "${TOP}/config"

HERE="${TOP}/ci/concourse"
cd "$HERE"

external_domain_name="${EXTERNAL_DOMAIN_NAME:-govuk-k8s.test}"

URL="http://ci.${external_domain_name}"
if [[ "$ENABLE_HTTPS" == "true" ]]; then
    URL="https://ci.${external_domain_name}"
fi

if [[ "$MODE" == "local" ]]; then
  URL="${URL}:8080"
fi

fly login -t govuk-k8s -c "$URL"
