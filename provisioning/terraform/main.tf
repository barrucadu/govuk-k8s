# These are filled in by the generated terraform.tfvars
variable "aws_region"           { type = string }
variable "aws_profile"          { type = string }
variable "ec2_ami"              { type = string }
variable "external_domain_name" { type = string }
variable "public_key_file"      { type = string }
variable "worker_count"         { type = number }

locals {
  cluster_name   = "govuk-k8s"
  web_subdomains = ["live"]

  instance_type_jumpbox  = "t3.micro"
  instance_type_web      = "t3.small"
  instance_type_registry = "t3.small"
  instance_type_ci       = "m5.large"
  instance_type_worker   = "m5.large"
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

module "subnet_a" {
  source = "./public_private_subnet"

  vpc_id = "${aws_vpc.cloud.id}"
  eip_id = "${aws_eip.a.id}"
  gw_id  = "${aws_internet_gateway.gw.id}"

  public_cidr_block  = "10.0.0.0/24"
  private_cidr_block = "10.0.1.0/24"
  availability_zone  = "eu-west-2a"

  private_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

module "subnet_b" {
  source = "./public_private_subnet"

  vpc_id = "${aws_vpc.cloud.id}"
  eip_id = "${aws_eip.b.id}"
  gw_id  = "${aws_internet_gateway.gw.id}"

  public_cidr_block  = "10.0.2.0/24"
  private_cidr_block = "10.0.3.0/24"
  availability_zone  = "eu-west-2b"

  private_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

module "subnet_c" {
  source = "./public_private_subnet"

  vpc_id = "${aws_vpc.cloud.id}"
  eip_id = "${aws_eip.c.id}"
  gw_id  = "${aws_internet_gateway.gw.id}"

  public_cidr_block  = "10.0.4.0/24"
  private_cidr_block = "10.0.5.0/24"
  availability_zone  = "eu-west-2c"

  private_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
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
  source = "./node"

  name      = "jumpbox"
  subnet_id = "${module.subnet_a.public_id}"
  key_name  = "${aws_key_pair.provisioning.key_name}"

  security_group_ids = [
    "${aws_security_group.external-ssh-ingress.id}",
    "${aws_security_group.standard.id}"
  ]

  route53_zone_name = "${aws_route53_zone.internal.name}"
  route53_zone_id   = "${aws_route53_zone.internal.zone_id}"

  instance_type = "${local.instance_type_jumpbox}"
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
  source = "./node"

  name      = "web"
  subnet_id = "${module.subnet_a.public_id}"
  key_name  = "${aws_key_pair.provisioning.key_name}"

  security_group_ids = [
    "${aws_security_group.external-web-ingress.id}",
    "${aws_security_group.standard.id}"
  ]

  route53_zone_name = "${aws_route53_zone.internal.name}"
  route53_zone_id   = "${aws_route53_zone.internal.zone_id}"

  instance_type = "${local.instance_type_web}"
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
  source = "./node"

  name      = "ci"
  subnet_id = "${module.subnet_a.public_id}"
  key_name  = "${aws_key_pair.provisioning.key_name}"

  security_group_ids = [
    "${aws_security_group.external-web-ingress.id}",
    "${aws_security_group.standard.id}"
  ]

  route53_zone_name = "${aws_route53_zone.internal.name}"
  route53_zone_id   = "${aws_route53_zone.internal.zone_id}"

  instance_root_size = 100
  instance_type      = "${local.instance_type_ci}"
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
  source = "./node"

  name      = "registry"
  subnet_id = "${module.subnet_a.private_id}"
  key_name  = "${aws_key_pair.provisioning.key_name}"

  security_group_ids = [
    "${aws_security_group.standard.id}"
  ]

  route53_zone_name = "${aws_route53_zone.internal.name}"
  route53_zone_id   = "${aws_route53_zone.internal.zone_id}"

  instance_root_size = 25
  instance_type      = "${local.instance_type_registry}"
}


/* ************************************************************************* */
/* kubernetes */

module "kubernetes" {
  source = "./kubernetes"

  cluster_name = "${local.cluster_name}"
  vpc_id       = "${aws_vpc.cloud.id}"
  vpc_cidr     = "${aws_vpc.cloud.cidr_block}"
  subnet_ids   = [
    "${module.subnet_a.private_id}",
    "${module.subnet_b.private_id}",
    "${module.subnet_c.private_id}",
  ]

  worker_instance_count = "${var.worker_count}"
  worker_instance_type  = "${local.instance_type_worker}"
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

output "public-ssh-ip" {
  value = "${module.jumpbox.public_ip}"
}

output "public-web-ip" {
  value = "${module.web.public_ip}"
}

output "external-domain" {
  value = "${aws_route53_zone.external.name}"
}

output "name-servers" {
  value = "${aws_route53_zone.external.name_servers}"
}

output "kubeconfig" {
  value = "${module.kubernetes.kubeconfig}"
}

output "config_map_aws_auth" {
  value = "${module.kubernetes.config_map_aws_auth}"
}
