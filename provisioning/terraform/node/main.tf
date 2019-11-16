variable "name" {
  type = string
}

variable "instance_ami" {
  type    = string
  default = "ami-02a2b5480a79084b7"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "instance_root_size" {
  type    = number
  default = 10
}

variable "subnet_id" {
  type = string
}

variable "key_name" {
  type = string
}

variable "security_group_ids" {
  type    = list
  default = []
}

variable "route53_zone_name" {
  type = string
}

variable "route53_zone_id" {
  type = string
}

variable "extra_tags" {
  type    = map
  default = {}
}

variable "role_policy_arns" {
  type    = list
  default = []
}


/* ************************************************************************* */

resource "aws_instance" "ec2" {
  ami           = "${var.instance_ami}"
  instance_type = "${var.instance_type}"
  subnet_id     = "${var.subnet_id}"
  key_name      = "${var.key_name}"

  vpc_security_group_ids = "${var.security_group_ids}"

  tags = "${merge(var.extra_tags, map("name", "${var.name}"))}"

  iam_instance_profile = "${aws_iam_instance_profile.profile.name}"

  root_block_device {
    volume_size = "${var.instance_root_size}"
  }
}

resource "aws_route53_record" "dns" {
  zone_id = "${var.route53_zone_id}"
  name    = "${var.name}.${var.route53_zone_name}"
  type    = "A"
  ttl     = 300
  records = ["${aws_instance.ec2.private_ip}"]
}

resource "aws_iam_instance_profile" "profile" {
  name = "${var.name}-profile"
  role = "${aws_iam_role.role.name}"
}

resource "aws_iam_role" "role" {
  name = "${var.name}-role"
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

resource "aws_iam_role_policy_attachment" "attachment" {
  count      = "${length(var.role_policy_arns)}"
  role       = "${aws_iam_role.role.name}"
  policy_arn = "${var.role_policy_arns[count.index]}"
}


/* ************************************************************************* */

output "public_ip" {
  value = "${aws_instance.ec2.public_ip}"
}

output "private_ip" {
  value = "${aws_instance.ec2.private_ip}"
}

output "role_name" {
  value = "${aws_iam_role.role.name}"
}
