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
  default = "ami-f976839e"
}

variable "external_domain_name" {
  type    = string
  default = "govuk-k8s.barrucadu.co.uk"
}

variable "internal_domain_name" {
  type    = string
  default = "internal.govuk-k8s.barrucadu.co.uk"
}

variable "provisioning_public_key_file" {
  type    = string
  default = "/home/barrucadu/.ssh/id_rsa.pub"
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
}

resource "aws_subnet" "public" {
  vpc_id     = "${aws_vpc.cloud.id}"
  cidr_block = "10.0.255.0/24"

  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  vpc_id     = "${aws_vpc.cloud.id}"
  cidr_block = "10.0.0.0/24"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.cloud.id}"
}

resource "aws_route_table" "rt" {
  vpc_id = "${aws_vpc.cloud.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
}

resource "aws_route_table_association" "assoc" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.rt.id}"
}

resource "aws_route53_zone" "external" {
  name = "${var.external_domain_name}"
}

resource "aws_route53_zone" "internal" {
  name = "${var.internal_domain_name}"

  vpc {
    vpc_id = "${aws_vpc.cloud.id}"
  }
}


/* ************************************************************************* */
/* jumpbox */

resource "aws_instance" "jumpbox" {
  ami           = "${var.ec2_ami}"
  instance_type = "t3.micro"
  subnet_id     = "${aws_subnet.public.id}"
  key_name      = "${aws_key_pair.provisioning.key_name}"

  vpc_security_group_ids = [
    "${aws_security_group.ssh-external.id}",
    "${aws_security_group.ssh-internal.id}"
  ]

  tags = {
    name = "jumpbox"
  }
}

resource "aws_route53_record" "jumpbox" {
  zone_id = "${aws_route53_zone.external.zone_id}"
  name    = "jumpbox.${aws_route53_zone.external.name}"
  type    = "A"
  ttl     = 300
  records = ["${aws_instance.jumpbox.public_ip}"]
}


/* ************************************************************************* */
/* puppet-master */

resource "aws_instance" "puppet-master" {
  ami           = "${var.ec2_ami}"
  instance_type = "t3.micro"
  subnet_id     = "${aws_subnet.private.id}"
  key_name      = "${aws_key_pair.provisioning.key_name}"

  vpc_security_group_ids = [
    "${aws_security_group.friends.id}",
    "${aws_security_group.ssh-internal.id}"
  ]

  tags = {
    name = "puppet-master"
  }
}

resource "aws_route53_record" "puppet-master" {
  zone_id = "${aws_route53_zone.internal.zone_id}"
  name    = "puppet-master.${aws_route53_zone.internal.name}"
  type    = "A"
  ttl     = 300
  records = ["${aws_instance.puppet-master.private_ip}"]
}


/* ************************************************************************* */
/* k8s-master */

resource "aws_instance" "k8s-master" {
  ami           = "${var.ec2_ami}"
  instance_type = "t3.micro"
  subnet_id     = "${aws_subnet.private.id}"
  key_name      = "${aws_key_pair.provisioning.key_name}"

  vpc_security_group_ids = [
    "${aws_security_group.friends.id}",
    "${aws_security_group.ssh-internal.id}"
  ]

  tags = {
    name = "k8s-master"
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
  ami           = "${var.ec2_ami}"
  instance_type = "m5.xlarge"
  subnet_id     = "${aws_subnet.private.id}"
  key_name      = "${aws_key_pair.provisioning.key_name}"

  vpc_security_group_ids = [
    "${aws_security_group.friends.id}",
    "${aws_security_group.ssh-internal.id}"
  ]

  tags = {
    name = "k8s-slave"
  }
}

resource "aws_route53_record" "k8s-slave" {
  zone_id = "${aws_route53_zone.internal.zone_id}"
  name    = "k8s-slave.${aws_route53_zone.internal.name}"
  type    = "A"
  ttl     = 300
  records = ["${aws_instance.k8s-slave.private_ip}"]
}


/* ************************************************************************* */
/* security */

resource "aws_security_group" "friends" {
  name   = "sg_friends"
  vpc_id = "${aws_vpc.cloud.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${aws_subnet.private.cidr_block}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${aws_subnet.private.cidr_block}"]
  }
}

resource "aws_security_group" "ssh-external" {
  name   = "sg_ssh-external"
  vpc_id = "${aws_vpc.cloud.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ssh-internal" {
  name   = "sg_ssh-internal"
  vpc_id = "${aws_vpc.cloud.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [
      "${aws_subnet.public.cidr_block}",
      "${aws_subnet.private.cidr_block}"
    ]
  }

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [
      "${aws_subnet.public.cidr_block}",
      "${aws_subnet.private.cidr_block}"
    ]
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

output "public_ip" {
  value = "${aws_instance.jumpbox.public_ip}"
}
