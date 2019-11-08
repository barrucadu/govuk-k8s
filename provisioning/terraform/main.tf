variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "aws_profile" {
  type    = string
  default = "govuk-k8s"
}

variable "ec2_ami" {
  type    = string
  default = "ami-02a2b5480a79084b7"
}

variable "external_domain_name" {
  type    = string
  default = "govuk-k8s.barrucadu.co.uk"
}

variable "provisioning_public_key_file" {
  type    = string
  default = "/home/barrucadu/.ssh/id_rsa.pub"
}

variable "k8s_slaves" {
  type    = number
  default = 2
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

  assign_generated_ipv6_cidr_block = true

  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public" {
  vpc_id     = "${aws_vpc.cloud.id}"
  cidr_block = "10.0.255.0/24"

  ipv6_cidr_block = cidrsubnet(aws_vpc.cloud.ipv6_cidr_block, 8, 255)

  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = true
}

resource "aws_subnet" "private" {
  vpc_id     = "${aws_vpc.cloud.id}"
  cidr_block = "10.0.0.0/24"

  ipv6_cidr_block = cidrsubnet(aws_vpc.cloud.ipv6_cidr_block, 8, 0)

  assign_ipv6_address_on_creation = true
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.cloud.id}"
}

resource "aws_egress_only_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.cloud.id}"
}

resource "aws_route_table" "rt" {
  vpc_id = "${aws_vpc.cloud.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = "${aws_egress_only_internet_gateway.gw.id}"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.rt.id}"
}

resource "aws_route_table_association" "private" {
  subnet_id      = "${aws_subnet.private.id}"
  route_table_id = "${aws_route_table.rt.id}"
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

resource "aws_instance" "jumpbox" {
  ami           = "${var.ec2_ami}"
  instance_type = "t3.medium"
  subnet_id     = "${aws_subnet.public.id}"
  key_name      = "${aws_key_pair.provisioning.key_name}"

  vpc_security_group_ids = [
    "${aws_security_group.external-ssh-ingress.id}",
    "${aws_security_group.standard.id}"
  ]

  tags = {
    name = "jumpbox"
  }

  root_block_device {
    volume_size = 10
  }
}

resource "aws_route53_record" "jumpbox-ipv4" {
  zone_id = "${aws_route53_zone.external.zone_id}"
  name    = "jumpbox.${aws_route53_zone.external.name}"
  type    = "A"
  ttl     = 300
  records = ["${aws_instance.jumpbox.public_ip}"]
}

resource "aws_route53_record" "jumpbox-ipv6" {
  zone_id = "${aws_route53_zone.external.zone_id}"
  name    = "jumpbox.${aws_route53_zone.external.name}"
  type    = "AAAA"
  ttl     = 300
  records = "${aws_instance.jumpbox.ipv6_addresses}"
}

resource "aws_route53_record" "jumpbox" {
  zone_id = "${aws_route53_zone.internal.zone_id}"
  name    = "jumpbox.${aws_route53_zone.internal.name}"
  type    = "A"
  ttl     = 300
  records = ["${aws_instance.jumpbox.private_ip}"]
}


/* ************************************************************************* */
/* web */

resource "aws_instance" "web" {
  ami           = "${var.ec2_ami}"
  instance_type = "t3.medium"
  subnet_id     = "${aws_subnet.public.id}"
  key_name      = "${aws_key_pair.provisioning.key_name}"

  vpc_security_group_ids = [
    "${aws_security_group.external-web-ingress.id}",
    "${aws_security_group.standard.id}"
  ]

  tags = {
    name = "web"
  }

  root_block_device {
    volume_size = 10
  }
}

resource "aws_route53_record" "web-ipv4" {
  zone_id = "${aws_route53_zone.external.zone_id}"
  name    = "web.${aws_route53_zone.external.name}"
  type    = "A"
  ttl     = 300
  records = ["${aws_instance.web.public_ip}"]
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

resource "aws_route53_record" "web-ipv6" {
  zone_id = "${aws_route53_zone.external.zone_id}"
  name    = "web.${aws_route53_zone.external.name}"
  type    = "AAAA"
  ttl     = 300
  records = "${aws_instance.web.ipv6_addresses}"
}

resource "aws_route53_record" "web-ipv6-star" {
  zone_id = "${aws_route53_zone.external.zone_id}"
  name    = "*.web.${aws_route53_zone.external.name}"
  type    = "AAAA"

  alias {
    zone_id = "${aws_route53_record.web-ipv6.zone_id}"
    name    = "${aws_route53_record.web-ipv6.name}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "web" {
  zone_id = "${aws_route53_zone.internal.zone_id}"
  name    = "web.${aws_route53_zone.internal.name}"
  type    = "A"
  ttl     = 300
  records = ["${aws_instance.web.private_ip}"]
}


/* ************************************************************************* */
/* k8s-master */

resource "aws_instance" "k8s-master" {
  ami           = "${var.ec2_ami}"
  instance_type = "t3.medium"
  subnet_id     = "${aws_subnet.private.id}"
  key_name      = "${aws_key_pair.provisioning.key_name}"

  vpc_security_group_ids = [
    "${aws_security_group.standard.id}"
  ]

  tags = {
    name = "k8s-master"
  }

  root_block_device {
    volume_size = 10
  }
}

resource "aws_route53_record" "k8s-master" {
  zone_id = "${aws_route53_zone.internal.zone_id}"
  name    = "k8s-master.${aws_route53_zone.internal.name}"
  type    = "A"
  ttl     = 300
  records = ["${aws_instance.k8s-master.private_ip}"]
}


/* ************************************************************************* */
/* k8s-slave */

resource "aws_instance" "k8s-slave" {
  count = "${var.k8s_slaves}"

  ami           = "${var.ec2_ami}"
  instance_type = "m5.xlarge"
  subnet_id     = "${aws_subnet.private.id}"
  key_name      = "${aws_key_pair.provisioning.key_name}"

  vpc_security_group_ids = [
    "${aws_security_group.standard.id}"
  ]

  tags = {
    name  = "k8s-slave"
    index = "${count.index}"
  }

  root_block_device {
    volume_size = 10
  }
}

resource "aws_route53_record" "k8s-slave" {
  count = "${var.k8s_slaves}"

  zone_id = "${aws_route53_zone.internal.zone_id}"
  name    = "k8s-slave-${count.index}.${aws_route53_zone.internal.name}"
  type    = "A"
  ttl     = 300
  records = ["${aws_instance.k8s-slave[count.index].private_ip}"]
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

    ipv6_cidr_blocks = ["::/0"]
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

    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

    ipv6_cidr_blocks = ["::/0"]
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

    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

    ipv6_cidr_blocks = ["::/0"]
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
  public_key = "${file("${var.provisioning_public_key_file}")}"
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
  value = "${aws_instance.jumpbox.public_ip}"
}

output "public-web-ip" {
  value = "${aws_instance.web.public_ip}"
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
