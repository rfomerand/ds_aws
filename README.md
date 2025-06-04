# Terraform AWS EC2 Instance Module

This Terraform module deploys a single EC2 instance on AWS with a pre-configured security group for SSH access. It provides a simple way to launch compute resources with customizable parameters for different environments.

## Table of Contents

- [Overview](#overview)
- [Resources Created](#resources-created)
- [Variables](#variables)
- [Outputs](#outputs)
- [Usage](#usage)
- [Examples](#examples)
- [Security Notes](#security-notes)
- [Requirements](#requirements)
- [Troubleshooting](#troubleshooting)

## Overview

This module automates the provisioning of:
- An EC2 instance with public IP address
- A security group with SSH access rules
- Environment-based resource tagging

Perfect for quickly spinning up development servers, testing environments, or production workloads with proper access controls.

## Resources Created

### 1. Security Group (`aws_security_group.allow_ssh`)
**Purpose**: Controls network access to the EC2 instance

- **Ingress Rules**: 
  - SSH (TCP port 22) from specified IP ranges
- **Egress Rules**: 
  - All traffic allowed (default behavior)
- **Tags**: 
  - Name: `${var.instance_name}-ssh`
  - Environment: `${var.environment}`

### 2. EC2 Instance (`aws_instance.example`)
**Purpose**: The compute resource running your application

- **Configuration**:
  - AMI: Configurable via variable
  - Instance Type: Configurable via variable
  - Public IP: Automatically assigned
  - Security Group: References the created security group
  - SSH Key: Uses specified AWS key pair
- **Lifecycle**: 
  - `prevent_destroy = false` (allows easy cleanup)
- **Tags**: 
  - Name: `${var.instance_name}`
  - Environment: `${var.environment}`

## Variables

### Input Variables Reference

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `region` | AWS region where resources will be created | `string` | `"us-east-1"` | No |
| `ami_id` | ID of the AMI to use for the instance | `string` | `"ami-09eb231ad55c3963d"` | No |
| `instance_type` | Type of instance to launch | `string` | `"t2.micro"` | No |
| `instance_name` | Name to assign to the instance | `string` | `"bigo"` | No |
| `ssh_key_name` | Name of the SSH key pair in AWS | `string` | `"create a new ssh key pair"` | **Yes*** |
| `environment` | Environment name for tagging | `string` | `"production"` | No |
| `allowed_ssh_ips` | CIDR blocks allowed to SSH | `string` | `"0.0.0.0/0"` | No |

**Important***: You must change the `ssh_key_name` to an existing key pair in your AWS account.

### Variable Details

#### `region`
- **Purpose**: Determines the AWS data center location for your resources
- **Example Values**: `"us-west-2"`, `"eu-central-1"`, `"ap-southeast-1"`

#### `ami_id`
- **Purpose**: Specifies the operating system image for the EC2 instance
- **Default**: Ubuntu 20.04 LTS in us-east-1
- **Note**: AMI IDs are region-specific; update when changing regions

#### `instance_type`
- **Purpose**: Defines the hardware configuration (CPU, memory, network)
- **Common Values**: 
  - `"t2.micro"` - 1 vCPU, 1 GB RAM (free tier)
  - `"t3.small"` - 2 vCPU, 2 GB RAM
  - `"t3.medium"` - 2 vCPU, 4 GB RAM

#### `instance_name`
- **Purpose**: Human-readable identifier for the instance
- **Used In**: AWS console, resource tags, and billing reports

#### `ssh_key_name`
- **Purpose**: Enables SSH authentication to the instance
- **Required**: Must reference an existing key pair in the target region
- **Create New**: `aws ec2 create-key-pair --key-name my-key`

#### `environment`
- **Purpose**: Categorizes resources by deployment stage
- **Common Values**: `"development"`, `"staging"`, `"production"`

#### `allowed_ssh_ips`
- **Purpose**: Restricts SSH access to specific IP addresses
- **Security**: Default allows all IPs - **always restrict in production!**
- **Examples**: 
  - Single IP: `"203.0.113.5/32"`
  - IP Range: `"10.0.0.0/16"`

## Outputs

| Output Name | Description | Example Value |
|-------------|-------------|---------------|
| `instance_public_ip` | Public IP address of the EC2 instance | `"54.123.45.67"` |
| `ssh_command_example` | Ready-to-use SSH command | `"ssh -i ~/.ssh/my-key.pem ubuntu@54.123.45.67"` |

## Usage

### Quick Start

1. **Create a new directory**:
   ```bash
   mkdir my-ec2-project && cd my-ec2-project
   ```

2. **Create `main.tf`**:
   ```hcl
   module "ec2" {
     source = "./path-to-module"
     
     ssh_key_name = "my-existing-key"  # Required: your actual key name
   }
   ```

3. **Deploy**:
   ```bash
   terraform init
   terraform apply
   ```

4. **Connect**:
   ```bash
   terraform output -module=ec2 ssh_command_example
   ```

### Step-by-Step Instructions

#### 1. Prerequisites
```bash
# Configure AWS credentials
aws configure

# List existing key pairs
aws ec2 describe-key-pairs --query 'KeyPairs[*].KeyName'

# Create a new key pair if needed
aws ec2 create-key-pair --key-name my-key --query 'KeyMaterial' > my-key.pem
chmod 400 my-key.pem
```

#### 2. Write Configuration
Create `terraform.tf`:
```hcl
terraform {
  required_version = ">= 0.12"
}

module "my_server" {
  source = "./ec2-module"
  
  # Customize these values
  ssh_key_name    = "my-key"
  instance_name   = "web-app"
  allowed_ssh_ips = "192.168.1.0/24"  # Your network CIDR
}

# Display outputs
output "ip_address" {
  value = module.my_server.instance_public_ip
}

output "connection_string" {
  value = module.my_server.ssh_command_example
}
```

#### 3. Deploy Infrastructure
```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply configuration
terraform apply -auto-approve

# Save outputs
terraform output > instance-details.txt
```

## Examples

### Development Environment

```hcl
module "dev_instance" {
  source = "./modules/ec2"
  
  # Basic configuration
  instance_name = "dev-sandbox"
  instance_type = "t2.micro"
  ssh_key_name  = "developer-key"
  
  # Development settings
  environment     = "development"
  allowed_ssh_ips = "0.0.0.0/0"  # Open access for dev
}
```

### Production with Security

```hcl
module "prod_api_server" {
  source = "./modules/ec2"
  
  # Region and OS
  region = "eu-west-1"
  ami_id = "ami-0694d931cee176e7d"  # Ubuntu 20.04 in EU
  
  # Production specs
  instance_type = "t3.large"
  instance_name = "api-backend-prod-01"
  ssh_key_name  = "production-ireland-key"
  
  # Security settings
  environment     = "production"
  allowed_ssh_ips = "10.0.0.0/