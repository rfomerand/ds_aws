terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Generate unique ID for this deployment
resource "random_id" "unique" {
  byte_length = 4
}

locals {
  name_prefix = "ds-${random_id.unique.hex}"
  user_data_vars = {
    log_group_name    = aws_cloudwatch_log_group.app_logs.name
    app_log_stream    = aws_cloudwatch_log_stream.app_log_stream.name
    model_pull_stream = aws_cloudwatch_log_stream.model_pull_stream.name
    github_token      = var.github_token
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/${local.name_prefix}/logs"
  retention_in_days = 30

  tags = {
    Environment = "production"
    Application = local.name_prefix
  }
}

resource "aws_cloudwatch_log_stream" "app_log_stream" {
  name           = "${local.name_prefix}-stream"
  log_group_name = aws_cloudwatch_log_group.app_logs.name
}

resource "aws_cloudwatch_log_stream" "model_pull_stream" {
  name           = "${local.name_prefix}-stream-model-pull"
  log_group_name = aws_cloudwatch_log_group.app_logs.name
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-1b" 
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-subnet"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-rt"
  }
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.main.id
}

resource "aws_iam_role" "ec2_cloudwatch" {
  name = "${local.name_prefix}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudwatch_policy" {
  name = "${local.name_prefix}-policy"
  role = aws_iam_role.ec2_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.app_logs.arn}",
          "${aws_cloudwatch_log_group.app_logs.arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-profile"
  role = aws_iam_role.ec2_cloudwatch.name
}

resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-sg"
  description = "Security group for ${local.name_prefix}"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "OpenWebUI"
  }

  ingress {
    from_port   = 11434
    to_port     = 11434
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Ollama"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-sg"
  }
}

resource "aws_key_pair" "app" {
  key_name   = "${local.name_prefix}-key"
  public_key = file(var.ssh_public_key_path)
}

resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  key_name                    = aws_key_pair.app.key_name

  root_block_device {
    volume_size = 1000
    volume_type = "gp3"
    tags = {
      Name = "${local.name_prefix}-volume"
    }
  }

  tags = {
    Name        = "${local.name_prefix}-instance"
    Purpose     = "ollama-inference"
    Environment = "production"
    ManagedBy   = "terraform"
  }

  user_data = templatefile("${path.module}/templates/user_data.sh", local.user_data_vars)

  depends_on = [
    aws_internet_gateway.main,
    aws_cloudwatch_log_stream.model_pull_stream,
    aws_cloudwatch_log_stream.app_log_stream
  ]
}
