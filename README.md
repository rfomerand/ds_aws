# Terraform AWS EC2 Instance Module

This Terraform module provisions an EC2 instance on AWS with a configured security group for SSH access. It's designed to quickly deploy compute instances with customizable settings for different environments.

## Resources Created

This module creates the following AWS resources:

### 1. **AWS Security Group** (`aws_security_group.allow_ssh`)
- **Purpose**: Manages network access rules for the EC2 instance
- **Ingress Rules**: 
  - Allows SSH (TCP port 22) from specified IP ranges
- **Egress Rules**: 
  - Allows all outbound traffic
- **Tags**: 
  - Name: `{instance_name}-ssh`
  - Environment: `{environment}`

### 2. **AWS EC2 Instance** (`aws_instance.example`)
- **Purpose**: Virtual compute server for running applications
- **Configuration**:
  - Associates with the security group created above
  - Assigns a public IP address automatically
  - Uses specified SSH key pair for access
- **Lifecycle**: 
  - `prevent_destroy = false` (allows destruction via Terraform)
- **Tags**: 
  - Name: `{instance_name}`
  - Environment: `{environment}`

## Variables

### Input Variable Reference

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `region` | AWS region for resource deployment | `string` | `"us-east-1"` | No |
| `ami_id` | Amazon Machine Image ID for the EC2 instance | `string` | `"ami-09eb231ad55c3963d"` | No |
| `instance_type` | EC2 instance type (size and capacity) | `string` | `"t2.micro"` | No |
| `instance_name` | Name tag for the EC2 instance | `string` | `"bigo"` | No |
| `ssh_key_name` | Name of AWS SSH key pair | `string` | `"create a new ssh key pair"` | **Yes** |
| `environment` | Environment tag (dev/staging/prod) | `string` | `"production"` | No |
| `allowed_ssh_ips` | CIDR blocks allowed SSH access | `string` | `"0.0.0.0/0"` | No |

### Variable Purposes

- **`region`**: Specifies the AWS geographical location where resources will be created
- **`ami_id`**: Determines the operating system and pre-installed software (default is Ubuntu 20.04 for us-east-1)
- **`instance_type`**: Controls computing resources - t2.micro is free-tier eligible
- **`ssh_key_name`**: **Must be updated** to match an existing key pair in your AWS account
- **`environment`**: Used for tagging and organizing resources by deployment stage
- **`allowed_ssh_ips`**: Controls network security - default allows all IPs (not recommended for production)

## Outputs

| Output | Description |
|--------|-------------|
| `instance_public_ip` | The public IPv4 address assigned to the EC2 instance |
| `ssh_command_example` | Example SSH command to connect to the instance |

## Prerequisites

1. **Terraform** version 0.12 or higher installed
2. **AWS CLI** configured with valid credentials
3. **SSH key pair** created in your target AWS region
4. **IAM permissions** for EC2 and VPC operations

## Usage

### Basic Usage

1. Create a new Terraform configuration file:

```hcl
module "my_ec2" {
  source = "./path/to/module"
  
  # Required: specify your SSH key
  ssh_key_name = "my-existing-key"
}
```

2. Initialize and apply:

```bash
terraform init
terraform apply
```

3. Connect to your instance:

```bash
$(terraform output -module=my_ec2 ssh_command_example)
```

### Complete Example

```hcl
# main.tf
terraform {
  required_version = ">= 0.12"
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  default = "us-west-2"
}

# Deploy EC2 Module
module "web_server" {
  source = "./modules/ec2"
  
  # AWS Configuration
  region = var.aws_region
  ami_id = "ami-0cf2b4e024cdb6960"  # Ubuntu 20.04 for us-west-2
  
  # Instance Settings
  instance_type = "t3.small"
  instance_name = "web-application"
  ssh_key_name  = "production-key"
  
  # Security Configuration
  environment     = "staging"
  allowed_ssh_ips = "10.0.0.0/16"  # Corporate network only
}

# Outputs
output "server_ip" {
  value = module.web_server.instance_public_ip
  description = "Public IP of the web server"
}

output "ssh_command" {
  value = module.web_server.ssh_command_example
  description = "SSH connection command"
}
```

## Example Usage Instructions

### Step 1: Create SSH Key Pair

```bash
# Create a new key pair in AWS
aws ec2 create-key-pair \
  --key-name my-terraform-key \
  --query 'KeyMaterial' \
  --output text > my-terraform-key.pem

# Set correct permissions
chmod 400 my-terraform-key.pem
```

### Step 2: Configure Your Module

Create `terraform.tf`:

```hcl
module "development_server" {
  source = "./ec2-module"
  
  instance_name   = "dev-app-server"
  ssh_key_name    = "my-terraform-key"
  instance_type   = "t2.micro"
  environment     = "development"
  allowed_ssh_ips = "192.168.1.100/32"  # Your IP address
}
```

### Step 3: Deploy

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply configuration
terraform apply

# Get instance details
terraform output
```

### Step 4: Connect and Verify

```bash
# SSH into the instance
ssh -i my-terraform-key.pem ubuntu@$(terraform output -module=development_server instance_public_ip)

# Verify the instance
aws ec2 describe-instances --filters "Name=tag:Name,Values=dev-app-server"
```

## Additional Examples

### Production Environment

```hcl
module "production_api" {
  source = "./ec2-module"
  
  region          = "eu-central-1"
  ami_id          = "ami-0a49b025fffbbdac6"  # Ubuntu 20.04 in Frankfurt
  instance_type   = "t3.medium"
  instance_name   = "api-prod-01"
  ssh_key_name    = "prod-eu-key"
  environment     = "production"
  allowed_ssh_ips = "10.0.0.0/8"  # VPN access only
}
```

### Multi-Environment Setup

```hcl
# Development
module "dev" {
  source          = "./ec2-module"
  instance_name   = "app-dev"
  ssh_key_name    = "dev-key"
  environment     = "development"
}

# Staging
module "staging" {
  source          = "./ec2-module"
  instance_name   = "app-staging"
  ssh_key_name    = "staging-key"
  instance_type   = "t3.small"
  environment     = "staging"
  allowed_ssh_ips = "10.0.0.0/16"
}

# Production
module "production" {
  source          = "./ec2-module"
  instance_name   = "app-prod"
  ssh_key_name    = "prod-key"
  instance_type   = "t3.large"
  environment     = "production"
  allowed_ssh_ips = "10.1.0.0/24"
}
```

## Security Considerations

⚠️ **Important Security Notes:**

1. **SSH Access**: The default `allowed_ssh_ips` value of `0.0.