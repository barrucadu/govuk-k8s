#!/usr/bin/env bash

TOP="$(git rev-parse --show-toplevel)"
SCRIPT="${TOP}/provisioning/${MODE}/create.sh"

source "${TOP}/config"

if [[ ! -x "$SCRIPT" ]]; then
    echo "bad mode"
    exit 1
fi

"$SCRIPT"
