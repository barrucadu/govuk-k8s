# These are filled in by the generated terraform.tfvars
variable "aws_region"           { type = string }
variable "aws_profile"          { type = string }
variable "ec2_ami"              { type = string }
variable "external_domain_name" { type = string }
variable "public_key_file"      { type = string }
variable "k8s_slaves"           { type = number }

locals {
  web_subdomains = ["live"]
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

resource "aws_subnet" "public" {
  vpc_id     = "${aws_vpc.cloud.id}"
  cidr_block = "10.0.0.0/24"

  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  vpc_id     = "${aws_vpc.cloud.id}"
  cidr_block = "10.0.1.0/24"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.cloud.id}"
}

resource "aws_eip" "nat" {
  vpc        = true
  depends_on = ["aws_internet_gateway.gw"]
}

resource "aws_nat_gateway" "gw" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${aws_subnet.public.id}"
  depends_on    = ["aws_internet_gateway.gw"]
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.cloud.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    name = "public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.cloud.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.gw.id}"
  }

  tags = {
    name = "private"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "private" {
  subnet_id      = "${aws_subnet.private.id}"
  route_table_id = "${aws_route_table.private.id}"
}

resource "aws_route53_zone" "external" {
  name = "${var.external_domain_name}"
}

resource "aws_route53_zone" "internal" {
  name = "govuk-k8s.test"

  vpc {
    vpc_id = "${aws_vpc.cloud.id}"
  }
}


/* ************************************************************************* */
/* jumpbox */

module "jumpbox" {
  source = "./node_group"

  name      = "jumpbox"
  subnet_id = "${aws_subnet.public.id}"
  key_name  = "${aws_key_pair.provisioning.key_name}"

  security_group_ids = [
    "${aws_security_group.external-ssh-ingress.id}",
    "${aws_security_group.standard.id}"
  ]

  route53_zone_name = "${aws_route53_zone.internal.name}"
  route53_zone_id   = "${aws_route53_zone.internal.zone_id}"
}

resource "aws_route53_record" "jumpbox-ipv4" {
  zone_id = "${aws_route53_zone.external.zone_id}"
  name    = "jumpbox.${aws_route53_zone.external.name}"
  type    = "A"
  ttl     = 300
  records = ["${module.jumpbox.public_ip}"]
}


/* ************************************************************************* */
/* web */

module "web" {
  source = "./node_group"

  name      = "web"
  subnet_id = "${aws_subnet.public.id}"
  key_name  = "${aws_key_pair.provisioning.key_name}"

  security_group_ids = [
    "${aws_security_group.external-web-ingress.id}",
    "${aws_security_group.standard.id}"
  ]

  route53_zone_name = "${aws_route53_zone.internal.name}"
  route53_zone_id   = "${aws_route53_zone.internal.zone_id}"
}

resource "aws_route53_record" "web-ipv4" {
  zone_id = "${aws_route53_zone.external.zone_id}"
  name    = "web.${aws_route53_zone.external.name}"
  type    = "A"
  ttl     = 300
  records = ["${module.web.public_ip}"]
}

resource "aws_route53_record" "web-ipv4-star" {
  zone_id = "${aws_route53_zone.external.zone_id}"
  name    = "*.web.${aws_route53_zone.external.name}"
  type    = "A"

  alias {
    zone_id = "${aws_route53_record.web-ipv4.zone_id}"
    name    = "${aws_route53_record.web-ipv4.name}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "web-ipv4-subdomain-star" {
  count   = length(local.web_subdomains)
  zone_id = "${aws_route53_zone.external.zone_id}"
  name    = "*.${local.web_subdomains[count.index]}.web.${aws_route53_zone.external.name}"
  type    = "A"

  alias {
    zone_id = "${aws_route53_record.web-ipv4.zone_id}"
    name    = "${aws_route53_record.web-ipv4.name}"
    evaluate_target_health = true
  }
}


/* ************************************************************************* */
/* ci */

module "ci" {
  source = "./node_group"

  name      = "ci"
  subnet_id = "${aws_subnet.public.id}"
  key_name  = "${aws_key_pair.provisioning.key_name}"

  security_group_ids = [
    "${aws_security_group.external-web-ingress.id}",
    "${aws_security_group.standard.id}"
  ]

  route53_zone_name = "${aws_route53_zone.internal.name}"
  route53_zone_id   = "${aws_route53_zone.internal.zone_id}"

  instance_root_size = 100
  instance_type      = "m5.xlarge"
}

resource "aws_route53_record" "ci-ipv4" {
  zone_id = "${aws_route53_zone.external.zone_id}"
  name    = "ci.${aws_route53_zone.external.name}"
  type    = "A"
  ttl     = 300
  records = ["${module.ci.public_ip}"]
}


/* ************************************************************************* */
/* registry */

module "registry" {
  source = "./node_group"

  name      = "registry"
  subnet_id = "${aws_subnet.private.id}"
  key_name  = "${aws_key_pair.provisioning.key_name}"

  security_group_ids = [
    "${aws_security_group.standard.id}"
  ]

  route53_zone_name = "${aws_route53_zone.internal.name}"
  route53_zone_id   = "${aws_route53_zone.internal.zone_id}"

  instance_root_size = 25
}


/* ************************************************************************* */
/* k8s-master */

module "k8s-master" {
  source = "./node_group"

  name      = "k8s-master"
  subnet_id = "${aws_subnet.private.id}"
  key_name  = "${aws_key_pair.provisioning.key_name}"

  security_group_ids = [
    "${aws_security_group.standard.id}"
  ]

  role_policy_arns = [
    "${aws_iam_policy.k8s-master-ebs-policy.arn}"
  ]

  route53_zone_name = "${aws_route53_zone.internal.name}"
  route53_zone_id   = "${aws_route53_zone.internal.zone_id}"

  extra_tags = {
    KubernetesCluster = "govuk-k8s"
  }
}

resource "aws_iam_policy" "k8s-master-ebs-policy" {
  name   = "k8s-master-ebs-policy"
  path   = "/"
  policy = "${data.aws_iam_policy_document.k8s-master-ebs-policy.json}"
}

data "aws_iam_policy_document" "k8s-master-ebs-policy" {
  statement {
    actions = [
      "ec2:DescribeInstances",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
      "ec2:DescribeVolumes",
      "ec2:CreateVolume",
      "ec2:DeleteVolume",
      "ec2:CreateTags",
      "ec2:DescribeSecurityGroups",
    ]

    resources = ["*"]
  }
}


/* ************************************************************************* */
/* k8s-slave */

module "k8s-slave" {
  source = "./node_group"

  name      = "k8s-slave"
  instances = "${var.k8s_slaves}"
  subnet_id = "${aws_subnet.private.id}"
  key_name  = "${aws_key_pair.provisioning.key_name}"

  security_group_ids = [
    "${aws_security_group.standard.id}"
  ]

  role_policy_arns = [
    "${aws_iam_policy.k8s-slave-ebs-policy.arn}"
  ]

  route53_zone_name = "${aws_route53_zone.internal.name}"
  route53_zone_id   = "${aws_route53_zone.internal.zone_id}"

  instance_type = "m5.xlarge"

  extra_tags = {
    KubernetesCluster = "govuk-k8s"
  }
}

resource "aws_iam_policy" "k8s-slave-ebs-policy" {
  name   = "k8s-slave-ebs-policy"
  path   = "/"
  policy = "${data.aws_iam_policy_document.k8s-slave-ebs-policy.json}"
}

data "aws_iam_policy_document" "k8s-slave-ebs-policy" {
  statement {
    actions = [
      "ec2:DescribeInstances",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
      "ec2:DescribeVolumes",
      "ec2:DescribeSecurityGroups",
    ]

    resources = ["*"]
  }
}


/* ************************************************************************* */
/* security */

resource "aws_security_group" "external-ssh-ingress" {
  name   = "sg_external-ssh-ingress"
  vpc_id = "${aws_vpc.cloud.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "external-web-ingress" {
  name   = "sg_external-web-ingress"
  vpc_id = "${aws_vpc.cloud.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "standard" {
  name   = "sg_standard"
  vpc_id = "${aws_vpc.cloud.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${aws_vpc.cloud.cidr_block}"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${aws_vpc.cloud.cidr_block}"]
  }
}


/* ************************************************************************* */
/* miscellaneous */

resource "aws_key_pair" "provisioning" {
  key_name   = "provisioning"
  public_key = "${file("${var.public_key_file}")}"
}


/* ************************************************************************* */
/* outputs */

output "vpc-id" {
  value = "${aws_vpc.cloud.id}"
}

output "vpc-public-cidr" {
  value = "${aws_subnet.public.cidr_block}"
}

output "vpc-public-id" {
  value = "${aws_subnet.public.id}"
}

output "vpc-private-cidr" {
  value = "${aws_subnet.private.cidr_block}"
}

output "vpc-private-id" {
  value = "${aws_subnet.private.id}"
}

output "public-ssh-ip" {
  value = "${module.jumpbox.public_ip}"
}

output "public-web-ip" {
  value = "${module.web.public_ip}"
}

output "k8s_slaves" {
  value = "${var.k8s_slaves}"
}

output "external-domain" {
  value = "${aws_route53_zone.external.name}"
}

output "name-servers" {
  value = "${aws_route53_zone.external.name_servers}"
}
