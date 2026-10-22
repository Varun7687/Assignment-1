terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Use the account's default VPC and one of its default subnets.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_vpc" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  selected_subnet_id = sort(data.aws_subnets.default_vpc.ids)[0]
  user_data_script = templatefile("${path.module}/user_data.sh.tftpl", {
    data_volume_id            = aws_ebs_volume.website.id
    asha_public_key_b64       = base64encode(trimspace(var.asha_public_key))
    ravi_public_key_b64       = base64encode(trimspace(var.ravi_public_key))
    github_repository_url_b64 = base64encode(trimspace(var.github_repository_url))
  })
}

data "aws_subnet" "selected" {
  id = local.selected_subnet_id
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_security_group" "status_page" {
  name_prefix = "assignment-1-status-"
  description = "Assignment 1 status page: SSH from one trusted IPv4 and public HTTP."
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from administrator public IPv4 only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_admin_cidr]
  }

  ingress {
    description = "Public HTTP for the assignment demo"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow package installation and normal outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name       = "assignment-1-status-page-sg"
    Assignment = "1"
    Project    = "internal-team-status-page"
  }
}

# Look up an EXISTING key pair in the selected AWS account and region.
# Terraform does not create, import, or download any key material here.
# Keep the matching private-key file on your laptop for MobaXterm SSH.
data "aws_key_pair" "admin" {
  key_name = var.existing_key_pair_name
}

resource "aws_instance" "status_page" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.selected.id
  vpc_security_group_ids      = [aws_security_group.status_page.id]
  associate_public_ip_address = true

  # Use the existing AWS key pair for permanent ec2-user SSH access.
  # Asha and Ravi retain their separate keys installed by user data.
  key_name                    = data.aws_key_pair.admin.key_name
  user_data_base64            = base64gzip(local.user_data_script)
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name       = "assignment-1-status-page"
    Assignment = "1"
    Project    = "internal-team-status-page"
  }
}

resource "aws_ebs_volume" "website" {
  availability_zone = data.aws_subnet.selected.availability_zone
  size              = var.data_volume_size_gib
  type              = "gp3"
  encrypted         = true

  tags = {
    Name       = "assignment-1-status-page-data"
    Assignment = "1"
    Project    = "internal-team-status-page"
  }
}

resource "aws_volume_attachment" "website" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.website.id
  instance_id = aws_instance.status_page.id
}
