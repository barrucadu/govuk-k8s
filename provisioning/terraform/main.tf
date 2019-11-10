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

variable "web_subdomains" {
  type    = list
  default = ["live", "management"]
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

resource "aws_route53_record" "web-ipv4-subdomain-star" {
  count   = length(var.web_subdomains)
  zone_id = "${aws_route53_zone.external.zone_id}"
  name    = "*.${var.web_subdomains[count.index]}.web.${aws_route53_zone.external.name}"
  type    = "A"

  alias {
    zone_id = "${aws_route53_record.web-ipv4.zone_id}"
    name    = "${aws_route53_record.web-ipv4.name}"
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
/* ci */

resource "aws_instance" "ci" {
  ami           = "${var.ec2_ami}"
  instance_type = "m5.xlarge"
  subnet_id     = "${aws_subnet.public.id}"
  key_name      = "${aws_key_pair.provisioning.key_name}"

  vpc_security_group_ids = [
    "${aws_security_group.external-web-ingress.id}",
    "${aws_security_group.standard.id}"
  ]

  tags = {
    name = "ci"
  }

  root_block_device {
    volume_size = 25
  }
}

resource "aws_route53_record" "ci-ipv4" {
  zone_id = "${aws_route53_zone.external.zone_id}"
  name    = "ci.${aws_route53_zone.external.name}"
  type    = "A"
  ttl     = 300
  records = ["${aws_instance.ci.public_ip}"]
}

resource "aws_route53_record" "ci" {
  zone_id = "${aws_route53_zone.internal.zone_id}"
  name    = "ci.${aws_route53_zone.internal.name}"
  type    = "A"
  ttl     = 300
  records = ["${aws_instance.ci.private_ip}"]
}


/* ************************************************************************* */
/* registry */

resource "aws_instance" "registry" {
  ami           = "${var.ec2_ami}"
  instance_type = "t3.medium"
  subnet_id     = "${aws_subnet.private.id}"
  key_name      = "${aws_key_pair.provisioning.key_name}"

  vpc_security_group_ids = [
    "${aws_security_group.standard.id}"
  ]

  tags = {
    name = "registry"
  }

  root_block_device {
    volume_size = 25
  }
}

resource "aws_route53_record" "registry" {
  zone_id = "${aws_route53_zone.internal.zone_id}"
  name    = "registry.${aws_route53_zone.internal.name}"
  type    = "A"
  ttl     = 300
  records = ["${aws_instance.registry.private_ip}"]
}


/* ************************************************************************* */
/* k8s-master */

resource "aws_instance" "k8s-master" {
  ami           = "${var.ec2_ami}"
  instance_type = "t3.medium"
  subnet_id     = "${aws_subnet.private.id}"
  key_name      = "${aws_key_pair.provisioning.key_name}"

  iam_instance_profile = "${aws_iam_instance_profile.k8s-master.name}"

  vpc_security_group_ids = [
    "${aws_security_group.standard.id}"
  ]

  tags = {
    name              = "k8s-master"
    KubernetesCluster = "govuk-k8s"
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

resource "aws_iam_instance_profile" "k8s-master" {
  name = "k8s-master-profile"
  role = "${aws_iam_role.k8s-master.name}"
}

resource "aws_iam_role" "k8s-master" {
  name = "k8s-master-role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


/* ************************************************************************* */
/* k8s-slave */

resource "aws_instance" "k8s-slave" {
  count = "${var.k8s_slaves}"

  ami           = "${var.ec2_ami}"
  instance_type = "m5.xlarge"
  subnet_id     = "${aws_subnet.private.id}"
  key_name      = "${aws_key_pair.provisioning.key_name}"

  iam_instance_profile = "${aws_iam_instance_profile.k8s-slave.name}"

  vpc_security_group_ids = [
    "${aws_security_group.standard.id}"
  ]

  tags = {
    name              = "k8s-slave"
    index             = "${count.index}"
    KubernetesCluster = "govuk-k8s"
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

resource "aws_iam_instance_profile" "k8s-slave" {
  name = "k8s-slave-profile"
  role = "${aws_iam_role.k8s-slave.name}"
}

resource "aws_iam_role" "k8s-slave" {
  name = "k8s-slave-role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
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
/* k8s storage auto-provisioning */

resource "aws_iam_role_policy_attachment" "k8s-master-ebs-policy" {
  role       = "${aws_iam_role.k8s-master.name}"
  policy_arn = "${aws_iam_policy.k8s-master-ebs-policy.arn}"
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

resource "aws_iam_role_policy_attachment" "k8s-slave-ebs-policy" {
  role       = "${aws_iam_role.k8s-slave.name}"
  policy_arn = "${aws_iam_policy.k8s-slave-ebs-policy.arn}"
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
