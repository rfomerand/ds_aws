# AWS EC2 Instance Terraform Module

A Terraform module that provisions an AWS EC2 instance with customizable security settings and network configuration. This module creates a complete compute environment suitable for development, testing, or production workloads.

## Description

This Terraform module automates the deployment of an EC2 instance in AWS with the following components:
- **EC2 Instance**: A compute instance with configurable size and operating system
- **Security Group**: Network security rules controlling inbound SSH access
- **Network Configuration**: Public IP assignment and network interface setup
- **Resource Tags**: Organized labeling for cost tracking and management

## Requirements

- Terraform >= 0.12
- AWS Provider >= 3.0
- Valid AWS credentials configured
- An existing SSH key pair in your AWS account

## Resources Created

This module creates the following AWS resources:

1. **AWS Security Group** (`aws_security_group.allow_ssh`)
   - Allows inbound SSH traffic (port 22) from specified IP ranges
   - Allows all outbound traffic

2. **AWS EC2 Instance** (`aws_instance.example`)
   - Configurable instance type and AMI
   - Public IP address assignment
   - SSH key pair association
   - Environment and name tags

## Input Variables

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `region` | The AWS region to deploy resources in | `string` | `"us-east-1"` | No |
| `ami_id` | The Amazon Machine Image ID to use for the EC2 instance | `string` | `"ami-09eb231ad55c3963d"` | No |
| `instance_type` | The type of EC2 instance to launch (e.g., t2.micro, t3.small) | `string` | `"t2.micro"` | No |
| `instance_name` | A descriptive name for the EC2 instance | `string` | `"bigo"` | No |
| `ssh_key_name` | The name of the AWS SSH key pair to associate with the instance | `string` | `"create a new ssh key pair"` | Yes* |
| `environment` | The deployment environment (dev, staging, production) | `string` | `"production"` | No |
| `allowed_ssh_ips` | CIDR block of IPs allowed to SSH into the instance | `string` | `"0.0.0.0/0"` | No |

*Note: You must replace the default `ssh_key_name` with an actual key pair name from your AWS account.

## Outputs

| Output | Description | Example |
|--------|-------------|---------|
| `instance_public_ip` | The public IP address assigned to the EC2 instance | `54.123.45.67` |
| `ssh_command_example` | A ready-to-use SSH command for connecting to the instance | `ssh -i ~/.ssh/your-key.pem ubuntu@54.123.45.67` |

## Usage Examples

### Basic Usage

Create a `main.tf` file:

```hcl
module "web_server" {
  source = "./path-to-module"
  
  ssh_key_name = "my-aws-keypair"
}
```

### Custom Configuration

```hcl
module "app_server" {
  source = "./path-to-module"
  
  region          = "us-west-2"
  ami_id          = "ami-0d70546e43a941d70"  # Ubuntu 22.04 in us-west-2
  instance_type   = "t3.small"
  instance_name   = "app-backend"
  ssh_key_name    = "production-keypair"
  environment     = "staging"
  allowed_ssh_ips = "192.168.1.0/24"  # Only allow SSH from corporate network
}
```

### Production Deployment

```hcl
module "production_api" {
  source = "./path-to-module"
  
  region          = "eu-west-1"
  ami_id          = "ami-0d75513e7706cf2d9"  # Amazon Linux 2
  instance_type   = "t3.medium"
  instance_name   = "api-server-prod"
  ssh_key_name    = "prod-eu-keypair"
  environment     = "production"
  allowed_ssh_ips = "10.0.0.0/8"  # Internal network only
}

terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "production/ec2/terraform.tfstate"
    region = "eu-west-1"
  }
}
```

## Getting Started

1. **Clone or download this module** to your local machine

2. **Create your SSH key pair** in AWS (if not already done):
   ```bash
   aws ec2 create-key-pair --key-name my-keypair --query 'KeyMaterial' --output text > my-keypair.pem
   chmod 400 my-keypair.pem
   ```

3. **Initialize Terraform**:
   ```bash
   terraform init
   ```

4. **Plan your deployment**:
   ```bash
   terraform plan -var="ssh_key_name=my-keypair"
   ```

5. **Apply the configuration**:
   ```bash
   terraform apply -var="ssh_key_name=my-keypair"
   ```

6. **Connect to your instance**:
   ```bash
   # Get the SSH command from outputs
   terraform output ssh_command_example
   ```

## Important Notes

### Security Best Practices

- **⚠️ SSH Access**: The default configuration allows SSH from anywhere (`0.0.0.0/0`). Always restrict this to specific IP addresses or ranges in production environments.
- **Key Management**: Store your private SSH keys securely and never commit them to version control.
- **AMI Updates**: Regularly update AMI IDs to use the latest patched images.

### Cost Considerations

- The default `t2.micro` instance type is eligible for AWS Free Tier
- Remember to destroy resources when not in use: `terraform destroy`
- Use appropriate instance types for your workload to optimize costs

### Lifecycle Configuration

The EC2 instance has `prevent_destroy` set to `false`, allowing Terraform to destroy it. To prevent accidental deletion, you can modify this in the module:

```hcl
lifecycle {
  prevent_destroy = true
}
```

## Cleanup

To remove all resources created by this module:

```bash
terraform destroy
```

## Support

For issues, questions, or contributions, please:
1. Check existing documentation
2. Review AWS EC2 documentation
3. Verify your AWS credentials and permissions

## License

This module is available under the [MIT License](LICENSE).