# AWS Provider — credentials via environment variables or IAM role
# Never hardcode credentials here
# Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY as environment variables
# or use an IAM instance role (recommended for EC2/CI)
provider "aws" {
  region = "us-east-1"
}

# EC2 Instance
resource "aws_instance" "app" {
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  tags = {
    Name        = "devops-app"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# Security Group — restrict to only required ports
resource "aws_security_group" "app_sg" {
  name        = "app-sg"
  description = "Allow only app port and SSH from known IPs"

  # Allow app traffic on port 5000 only
  ingress {
    description = "App port"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH from known IP only
  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  # Allow only outbound HTTP/HTTPS
  egress {
    description = "Allow outbound HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "app-sg"
    ManagedBy = "terraform"
  }
}

# Variables
variable "key_name" {
  description = "EC2 SSH key pair name"
  type        = string
}

variable "admin_cidr" {
  description = "CIDR block allowed to SSH into the instance"
  type        = string
}
