variable "aws_region" {
  description = "AWS region containing your existing EC2 key pair and default VPC."
  type        = string
}

variable "instance_type" {
  description = "Amazon Linux 2023 instance type."
  type        = string
  default     = "t3.micro"
}

variable "ssh_admin_cidr" {
  description = "Your current public IPv4 address followed by /32."
  type        = string

  validation {
    condition     = can(cidrhost(var.ssh_admin_cidr, 0)) && can(regex("^[0-9.]+/32$", var.ssh_admin_cidr))
    error_message = "Set ssh_admin_cidr to your current valid public IPv4 followed by /32."
  }
}

variable "existing_key_pair_name" {
  description = "Exact name of an existing AWS EC2 key pair in the deployment region, not a local file path."
  type        = string

  validation {
    condition     = length(trimspace(var.existing_key_pair_name)) > 0
    error_message = "Provide the existing EC2 key-pair name shown in AWS."
  }
}

variable "asha_public_key" {
  description = "Complete OpenSSH PUBLIC key for the asha Linux account."
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)[ ]+[A-Za-z0-9+/=]+", trimspace(var.asha_public_key)))
    error_message = "Provide Asha's complete OpenSSH public key, never a private key."
  }
}

variable "ravi_public_key" {
  description = "Complete OpenSSH PUBLIC key for the ravi Linux account."
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)[ ]+[A-Za-z0-9+/=]+", trimspace(var.ravi_public_key)))
    error_message = "Provide Ravi's complete OpenSSH public key, never a private key."
  }
}

variable "data_volume_size_gib" {
  description = "Size of the separate gp3 website EBS volume in GiB."
  type        = number
  default     = 2

  validation {
    condition     = var.data_volume_size_gib >= 1 && var.data_volume_size_gib <= 16384
    error_message = "data_volume_size_gib must be between 1 and 16384 GiB."
  }
}

variable "github_repository_url" {
  description = "Optional existing GitHub remote. Prefer git@github.com:OWNER/REPO.git for per-user SSH authentication. No passwords or tokens."
  type        = string
  default     = ""

  validation {
    condition     = trimspace(var.github_repository_url) == "" || can(regex("^(https://github[.]com/|git@github[.]com:)[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.-]+[.]git$", trimspace(var.github_repository_url)))
    error_message = "Use https://github.com/OWNER/REPO.git or git@github.com:OWNER/REPO.git, without embedded credentials."
  }
}
