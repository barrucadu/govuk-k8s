variable "vpc_id" {
  type = string
}

variable "eip_id" {
  type = string
}

variable "gw_id" {
  type = string
}

variable "public_cidr_block" {
  type = string
}

variable "private_cidr_block" {
  type = string
}

variable "availability_zone" {
  type = string
}

variable "public_tags" {
  type    = map
  default = {}
}

variable "private_tags" {
  type    = map
  default = {}
}


/* ************************************************************************* */
/* public */

resource "aws_subnet" "public" {
  vpc_id     = "${var.vpc_id}"
  cidr_block = "${var.public_cidr_block}"

  availability_zone = "${var.availability_zone}"

  map_public_ip_on_launch = true

  tags = "${merge(var.public_tags, map("Scope", "public"))}"
}

resource "aws_route_table" "public" {
  vpc_id = "${var.vpc_id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${var.gw_id}"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public.id}"
}


/* ************************************************************************* */
/* private */

resource "aws_nat_gateway" "nat" {
  allocation_id = "${var.eip_id}"
  subnet_id     = "${aws_subnet.public.id}"
}

resource "aws_subnet" "private" {
  vpc_id     = "${var.vpc_id}"
  cidr_block = "${var.private_cidr_block}"

  availability_zone = "${var.availability_zone}"

  tags = "${merge(var.private_tags, map("Scope", "private"))}"
}

resource "aws_route_table" "private" {
  vpc_id = "${var.vpc_id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.nat.id}"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = "${aws_subnet.private.id}"
  route_table_id = "${aws_route_table.private.id}"
}


/* ************************************************************************* */

output "public_id" {
  value = "${aws_subnet.public.id}"
}

output "private_id" {
  value = "${aws_subnet.private.id}"
}
