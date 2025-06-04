# AWS Ollama Inference Infrastructure

This repository contains Terraform code to deploy a GPU-enabled Ollama inference environment with OpenWebUI on AWS. The setup includes automated model deployment, CloudWatch monitoring, and secure access configuration.

## Prerequisites

Before you begin, ensure you have:

1. An AWS account with appropriate permissions
2. [AWS CLI](https://aws.amazon.com/cli/) installed and configured
3. [Terraform](https://www.terraform.io/downloads.html) (version >= 1.0.0) installed
4. SSH key pair for EC2 instance access
5. [GitHub Personal Access Token](https://github.com/settings/tokens) with repo access

## Quick Start

1. Clone the repository:
```bash
git clone https://github.com/rfomerand/ds_aws.git
cd ds_aws
```

## Example Configuration

Here's a complete example of a `terraform.tfvars` file:

```hcl
# Required variables
aws_region = "us-west-1"                                    # N. California region
ami_id = "ami-0d413c682033e11fd"                           # Ubuntu 22.04 LTS AMI
ssh_public_key_path = "~/.ssh/ollama-deploy.pub"           # Your SSH public key
ssh_private_key_path = "~/.ssh/ollama-deploy"              # Your SSH private key
github_token = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"   # GitHub PAT with repo access

# Optional variables with recommended values
instance_type = "r6i.metal"                                # High-memory metal instance
```

## Example Workflow

Here's a typical workflow for deploying and managing the infrastructure:

```bash
# 1. Initial setup
git clone https://github.com/yourusername/ds_aws.git
cd ds_aws
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Edit with your values

# 2. Generate SSH key if needed
ssh-keygen -t rsa -b 4096 -C "ollama-deploy" -f ~/.ssh/ollama-deploy

# 3. Initialize and check configuration
terraform init
terraform validate
terraform plan

# 4. Deploy infrastructure
terraform apply -auto-approve

# 5. Access the deployment (commands will be in terraform output)
# SSH access
ssh -i ~/.ssh/ollama-deploy ubuntu@<public-ip>

# View logs
ssh -i ~/.ssh/ollama-deploy ubuntu@<public-ip> 'sudo tail -f /var/log/deploy.log'
ssh -i ~/.ssh/ollama-deploy ubuntu@<public-ip> 'sudo tail -f /var/log/model-pull.log'

# Access URLs
# OpenWebUI: http://<public-ip>:8080
# Ollama API: http://<public-ip>:11434

# 6. Test deployment
curl http://<public-ip>:11434/api/tags  # List available models

# 7. Common management commands
# Stop instance (to save costs)
aws ec2 stop-instances --instance-ids <instance-id>

# Start instance
aws ec2 start-instances --instance-ids <instance-id>

# Update infrastructure
terraform plan    # Check changes
terraform apply   # Apply changes

# 8. Cleanup
terraform destroy -auto-approve  # Remove all resources
```

## Choosing an Instance Type

The default configuration uses r6i.metal, which is a high-memory bare metal instance. Here are some alternative options based on your needs:

### High Memory Workloads (Current Configuration)
- `r6i.metal`: Bare metal high-memory instance
  - 128 vCPUs
  - 1024 GB RAM
  - Best for large-scale memory-intensive workloads
  - Approximate cost: $10.032/hour

### Development and Testing
- `r6i.4xlarge`: More economical option
  - 16 vCPUs
  - 128 GB RAM
  - Good for testing and development
  - Approximate cost: $1.008/hour

### Production Workloads
- `r6i.8xlarge`: Balanced performance/cost
  - 32 vCPUs
  - 256 GB RAM
  - Suitable for most production workloads
  - Approximate cost: $2.016/hour

- `r6i.16xlarge`: Higher capacity
  - 64 vCPUs
  - 512 GB RAM
  - Better for larger workloads
  - Approximate cost: $4.032/hour

To specify an instance type:
1. Add it to your terraform.tfvars:
```hcl
instance_type = "r6i.metal"
```
2. Or specify it during apply:
```bash
terraform apply -var="instance_type=r6i.metal"
```

Note: The r6i.metal instance type is only available in specific availability zones (us-west-1b, us-west-1c). The deployment is configured to use these zones automatically.

## Monitoring and Logs
The deployment creates two CloudWatch log streams:
- Application logs: `/${name_prefix}/logs/${name_prefix}-stream`
- Model pull logs: `/${name_prefix}/logs/${name_prefix}-stream-model-pull`

View logs using:
```bash
terraform output cloudwatch_logs_url
```

## Security
- SSH access using private key authentication
- Basic authentication for OpenWebUI
- Security groups limiting access to required ports
- IAM roles following principle of least privilege

## Cost Considerations
Costs vary significantly based on the chosen instance type:
- P5 instances are the most expensive but offer highest performance
- G5 instances provide good balance of cost and performance
- G4dn instances are most economical for development/testing

Consider:
- Using smaller instances (g4dn.xlarge, g5.xlarge) for development
- Stopping instances when not in use
- Monitoring GPU utilization to right-size instance type
- Using Savings Plans or Reserved Instances for long-term deployments

## Troubleshooting
1. SSH Connection Issues:
   ```bash
   # Add to SSH config
   terraform output -raw ssh_config_entry >> ~/.ssh/config
   ```

2. View deployment logs:
   ```bash
   ssh ollama-instance "sudo tail -f /var/log/deploy.log"
   ```

3. View model pull progress:
   ```bash
   ssh ollama-instance "sudo tail -f /var/log/model-pull.log"
   ```

## Contributing
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License
This project is licensed under the MIT License - see the LICENSE file for details.
