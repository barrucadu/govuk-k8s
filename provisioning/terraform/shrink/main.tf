# These are filled in by the generated terraform.tfvars
variable "aws_region"           { type = string }
variable "aws_profile"          { type = string }
variable "ec2_ami"              { type = string }
variable "external_domain_name" { type = string }
variable "public_key_file"      { type = string }
variable "worker_count"         { type = number }

locals {
  cluster_name = "govuk-k8s"
}


resource "aws_vpc" "cloud" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.cloud.id}"
}

resource "aws_eip" "a" {
  vpc        = true
  depends_on = ["aws_internet_gateway.gw"]
}

resource "aws_eip" "b" {
  vpc        = true
  depends_on = ["aws_internet_gateway.gw"]
}

resource "aws_eip" "c" {
  vpc        = true
  depends_on = ["aws_internet_gateway.gw"]
}

resource "aws_route53_zone" "external" {
  name = "${var.external_domain_name}"
}
