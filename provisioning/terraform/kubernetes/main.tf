/* based on https://learn.hashicorp.com/terraform/aws/eks-intro */

variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "subnet_ids" {
  type = list
}

variable "worker_ami" {
  type    = string
  default = "ami-097d908f4f4e38dc7"
}

variable "worker_instance_type" {
  type    = string
  default = "m5.xlarge"
}

variable "worker_instance_count" {
  type    = number
  default = 2
}


/* ************************************************************************* */
/* master */

resource "aws_eks_cluster" "eks" {
  name            = "${var.cluster_name}"
  role_arn        = "${aws_iam_role.master.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.master.id}"]
    subnet_ids         = "${var.subnet_ids}"
  }

  depends_on = [
    "aws_iam_role_policy_attachment.master-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.master-AmazonEKSServicePolicy",
  ]
}

resource "aws_iam_role" "master" {
  name = "eks-master"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "master-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.master.name}"
}

resource "aws_iam_role_policy_attachment" "master-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.master.name}"
}

resource "aws_security_group" "master" {
  description = "Cluster communication with worker nodes"
  name        = "sg_eks_master"
  vpc_id      = "${var.vpc_id}"
}

resource "aws_security_group_rule" "master_egress" {
  description = "Unrestricted outbound access"
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.master.id}"
}

resource "aws_security_group_rule" "master_ingress" {
  description = "Allow anything in VPC to communicate with the cluster API server"
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["${var.vpc_cidr}"]

  security_group_id = "${aws_security_group.master.id}"
}


/* ************************************************************************* */
/* workers */

resource "aws_iam_role" "worker" {
  name = "eks-worker"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "worker-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.worker.name}"
}

resource "aws_iam_role_policy_attachment" "worker-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.worker.name}"
}

resource "aws_iam_role_policy_attachment" "worker-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.worker.name}"
}

resource "aws_iam_role_policy_attachment" "worker-AmazonEBSCSIDriver" {
  policy_arn = "${aws_iam_policy.ebs-csi-driver.arn}"
  role       = "${aws_iam_role.worker.name}"
}

resource "aws_iam_policy" "ebs-csi-driver" {
  name   = "Amazon_EBS_CSI_Driver"
  path   = "/"
  policy = "${data.aws_iam_policy_document.ebs-csi-driver.json}"
}

data "aws_iam_policy_document" "ebs-csi-driver" {
  statement {
    actions = [
      "ec2:AttachVolume",
      "ec2:CreateSnapshot",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:DeleteSnapshot",
      "ec2:DeleteTags",
      "ec2:DeleteVolume",
      "ec2:DescribeInstances",
      "ec2:DescribeSnapshots",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DetachVolume",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_instance_profile" "worker" {
  name = "eks-worker"
  role = "${aws_iam_role.worker.name}"
}

resource "aws_security_group" "worker" {
  description = "Security group for all nodes in the cluster"
  name        = "sg_eks_worker"
  vpc_id      = "${var.vpc_id}"

  tags = {
     "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_security_group_rule" "worker_egress" {
  description = "Unrestricted outbound access"
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.worker.id}"
}

resource "aws_security_group_rule" "worker_ingress-mutual" {
  description = "Allows workers to communicate with each other"
  type        = "ingress"
  from_port   = 0
  to_port     = 65535
  protocol    = "-1"

  security_group_id        = "${aws_security_group.worker.id}"
  source_security_group_id = "${aws_security_group.worker.id}"
}

resource "aws_security_group_rule" "worker_ingress-master" {
  description = "Allows workers and pods to receive communication from the masters"
  type        = "ingress"
  from_port   = 1025
  to_port     = 65535
  protocol    = "tcp"

  security_group_id        = "${aws_security_group.worker.id}"
  source_security_group_id = "${aws_security_group.master.id}"
}


/* ************************************************************************* */
/* worker ASG */

locals {
  # see https://github.com/awslabs/amazon-eks-ami/blob/master/files/docker-daemon.json
  eks_docker_config_json = <<EOF
{
  "bridge": "none",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "10"
  },
  "live-restore": true,
  "max-concurrent-downloads": 10,
  "insecure-registries" : [ "registry.govuk-k8s.test:5000" ]
}
EOF

  eks_bootstrap_userdata = <<EOF
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.eks.endpoint}' --b64-cluster-ca '${aws_eks_cluster.eks.certificate_authority.0.data}' --docker-config-json '${local.eks_docker_config_json}' '${var.cluster_name}'
EOF
}

resource "aws_autoscaling_group" "worker" {
  desired_capacity     = "${var.worker_instance_count}"
  launch_configuration = "${aws_launch_configuration.worker.id}"
  max_size             = "${var.worker_instance_count}"
  min_size             = "${var.worker_instance_count}"
  name                 = "eks-worker"
  vpc_zone_identifier  = "${var.subnet_ids}"

  tag {
    key                 = "Name"
    value               = "eks-worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }
}

resource "aws_launch_configuration" "worker" {
  iam_instance_profile = "${aws_iam_instance_profile.worker.name}"
  image_id             = "${var.worker_ami}"
  instance_type        = "${var.worker_instance_type}"
  name_prefix          = "eks-worker"
  security_groups      = ["${aws_security_group.worker.id}"]
  user_data_base64     = "${base64encode(local.eks_bootstrap_userdata)}"

  associate_public_ip_address = false

  lifecycle {
    create_before_destroy = true
  }
}


/* ************************************************************************* */

locals {
  kubeconfig = <<EOF
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.eks.endpoint}
    certificate-authority-data: ${aws_eks_cluster.eks.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${var.cluster_name}"
EOF

  config_map_aws_auth = <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.worker.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOF
}

output "kubeconfig" {
  value = "${local.kubeconfig}"
}

output "config_map_aws_auth" {
  value = "${local.config_map_aws_auth}"
}
