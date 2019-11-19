#!/usr/bin/env bash

packages=(aws-iam-authenticator docker-compose jq kubectl "python3.withPackages (ps: [ps.flask ps.pyyaml])" python3Packages.black shellcheck terraform)

if [[ "$#" == "0" ]]; then
  exec nix-shell -p "${packages[@]}"
else
  exec nix-shell -p "${packages[@]}" --command "$@"
fi
