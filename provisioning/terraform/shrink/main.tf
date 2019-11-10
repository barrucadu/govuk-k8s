variable "aws_region" {
  type = string
}

variable "aws_profile" {
  type = string
}

variable "external_domain_name" {
  type = string
}


/* ************************************************************************* */
/* provider */

provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}


/* ************************************************************************* */
/* networking */

resource "aws_vpc" "cloud" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.cloud.id}"
}

resource "aws_eip" "nat" {
  vpc        = true
  depends_on = ["aws_internet_gateway.gw"]
}

resource "aws_route53_zone" "external" {
  name = "${var.external_domain_name}"
}
