variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "dev-workstation"
}

variable "instance_type" {
  description = "EC2 instance type (must be ARM/Graviton for t4g)"
  type        = string
  default     = "t4g.large"
}

variable "vpc_id" {
  description = "VPC ID to deploy the instance into"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID (use a public subnet if create_eip = true)"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to SSH and RDP into the workstation"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this to your IP in production
}

variable "public_key_path" {
  description = "Path to your SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "rdp_password" {
  description = "Password for the ubuntu user RDP session"
  type        = string
  sensitive   = true
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 50
}

variable "create_eip" {
  description = "Whether to allocate and attach an Elastic IP"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "dev-workstation"
    ManagedBy   = "terraform"
  }
}
