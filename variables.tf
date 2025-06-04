variable "aws_region" {
  description = "AWS region to deploy the infrastructure"
  type        = string
  default     = "us-west-1"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance (Ubuntu 22.04 LTS)"
  type        = string
  default     = "ami-0735c191cf914754d"
}

variable "ssh_public_key_path" {
  description = "Path to the public SSH key for EC2 instance access"
  type        = string
  default     = "~/.ssh/id_rsa.rfomerand.github.pub"
}

 variable "ssh_private_key_path" {
  description = "Path to the public SSH key for EC2 instance access"
  type        = string
  default     = "~/.ssh/id_rsa.rfomerand.github"
}

variable "github_token" {
  description = "GitHub Personal Access Token for repository access"
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "EC2 instance type for the application"
  type        = string
  default     = "r6i.metal"  # Change this to the instance model, which makes the most sense for you. This one's kind of expensive. 
}
