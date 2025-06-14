# Set AWS provider region
provider "aws" {
  region = var.aws_region
}

# Create a VPC with CIDR block 10.0.0.0/16
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Public subnet in availability zone us-east-2a
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2a"
}

# Internet Gateway for public access
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Route table to send internet-bound traffic to IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate the public subnet with the route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security group to allow SSH access (insecure: open to the world)
resource "aws_security_group" "ssh_access" {
  name        = "ssh_access"
  description = "Allow SSH access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 instance running Ubuntu 16.04 with MongoDB 3.6.23
resource "aws_instance" "mongo" {
  ami                         = "ami-05803413c51f242b7" # Hardcoded Ubuntu 16.04 AMI
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  key_name                    = "wiz-key" # Ensure this key pair exists
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ssh_access.id]

  tags = {
    Name = "MongoDB VM"
  }

  user_data = <<-EOF
              #!/bin/bash
              exec > /var/log/user-data.log 2>&1
              set -e

              apt-get update
              apt-get install -y gnupg wget curl

              wget -qO - https://www.mongodb.org/static/pgp/server-3.6.asc | apt-key add -
              echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.6 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-3.6.list

              apt-get update
              apt-get install -y mongodb-org=3.6.23 mongodb-org-server=3.6.23 mongodb-org-shell=3.6.23 mongodb-org-mongos=3.6.23 mongodb-org-tools=3.6.23

              systemctl start mongod
              systemctl enable mongod
              EOF
}

# Insecure public S3 bucket for database backups (intentionally misconfigured)
resource "aws_s3_bucket" "public_backups" {
  bucket = "wiz-backups-${random_id.bucket_id.hex}"
}

# Generate unique suffix for S3 bucket
resource "random_id" "bucket_id" {
  byte_length = 4
}
