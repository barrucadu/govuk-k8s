#!/usr/bin/env bash

if [[ ! -e config ]]; then
    echo "$(pwd)/config file does not exist"
    echo
    echo "copy config.template and edit it according to the comments"
    exit 1
fi

set -e

source ./config

err=false
# presence checking
if [[ -z "$KUBECONFIG" ]]; then
    echo "KUBECONFIG is not set"
    err=true
fi
if [[ -z "$AWS_REGION" ]]; then
    echo "AWS_REGION is not set"
    err=true
fi
if [[ -z "$AWS_PROFILE" ]]; then
    echo "AWS_PROFILE is not set"
    err=true
fi
if [[ -z "$EC2_AMI" ]]; then
    echo "EC2_AMI is not set"
    err=true
fi
if [[ -z "$EXTERNAL_DOMAIN_NAME" ]]; then
    echo "EXTERNAL_DOMAIN_NAME is not set"
    err=true
fi
if [[ -z "$PUBLIC_KEY_FILE" ]]; then
    echo "PUBLIC_KEY_FILE is not set"
    err=true
fi
if [[ -z "$WORKER_COUNT" ]]; then
    echo "WORKER_COUNT is not set"
    err=true
fi
if [[ -z "$ENABLE_HTTPS" ]]; then
    echo "ENABLE_HTTPS is not set"
    err=true
fi
if [[ -z "$FORCE_HTTPS" ]]; then
    echo "FORCE_HTTPS is not set"
    err=true
fi
if [[ "$ENABLE_HTTPS" = "true" ]] && [[ -z "$HTTPS_EMAIL" ]]; then
    echo "HTTPS_EMAIL is not set"
    err=true
fi
if [[ -z "$GITHUB_USER" ]]; then
    echo "GITHUB_USER is not set"
    err=true
fi
if [[ -z "$GITHUB_CLIENT_ID" ]]; then
    echo "GITHUB_CLIENT_ID is not set"
    err=true
fi
if [[ -z "$GITHUB_CLIENT_SECRET" ]]; then
    echo "GITHUB_CLIENT_SECRET is not set"
    err=true
fi

# more validation
if [[ ! -f "$PUBLIC_KEY_FILE" ]]; then
    echo "PUBLIC_KEY_FILE ($PUBLIC_KEY_FILE) does not exist"
    err=true
fi
if [[ "$ENABLE_HTTPS" != "true" ]] && [[ "$ENABLE_HTTPS" != "false" ]]; then
    echo "ENABLE_HTTPS ($ENABLE_HTTPS) is neither 'true' nor 'false'"
    err=true
fi
if [[ "$FORCE_HTTPS" != "true" ]] && [[ "$FORCE_HTTPS" != "false" ]]; then
    echo "FORCE_HTTPS ($FORCE_HTTPS) is neither 'true' nor 'false'"
    err=true
fi

if $err; then
    exit 1
fi

# Generate config files
terraform_config_file="provisioning/terraform/terraform.tfvars"
cat <<EOF > "$terraform_config_file"
aws_region           = "${AWS_REGION}"
aws_profile          = "${AWS_PROFILE}"
ec2_ami              = "${EC2_AMI}"
external_domain_name = "${EXTERNAL_DOMAIN_NAME}"
public_key_file      = "${PUBLIC_KEY_FILE}"
worker_count         = ${WORKER_COUNT}
EOF
echo "generated $terraform_config_file"

nixos_config_file="provisioning/nixos/vars.nix"
cat <<EOF > "$nixos_config_file"
{
  govuk-k8s.externalDomainName          = "${EXTERNAL_DOMAIN_NAME}";
  govuk-k8s.enableHTTPS                 = ${ENABLE_HTTPS};
  govuk-k8s.forceHTTPS                  = ${FORCE_HTTPS};
  govuk-k8s.httpsEmail                  = "${HTTPS_EMAIL}";
  govuk-k8s.concourseGithubUser         = "${GITHUB_USER}";
  govuk-k8s.concourseGithubClientId     = "${GITHUB_CLIENT_ID}";
  govuk-k8s.concourseGithubClientSecret = "${GITHUB_CLIENT_SECRET}";
}
EOF
echo "generated $nixos_config_file"
