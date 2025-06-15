provider "aws" {
  region = var.aws_region
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Create a public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2a"
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate subnet with route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security group for SSH
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

# Launch EC2 instance with Amazon Linux 2
resource "aws_instance" "mongo" {
  ami                         = "ami-0c55b159cbfafe1f0" # ✅ Amazon Linux 2 in us-east-2
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  key_name                    = "wiz-key"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ssh_access.id]

  tags = {
    Name = "MongoDB on Amazon Linux 2"
  }

  user_data = <<-EOF
              #!/bin/bash
              exec > /var/log/user-data.log 2>&1
              set -e
              yum update -y
              yum install -y wget curl

              cat > /etc/yum.repos.d/mongodb-org-3.6.repo << EOM
              [mongodb-org-3.6]
              name=MongoDB Repository
              baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/3.6/x86_64/
              gpgcheck=1
              enabled=1
              gpgkey=https://www.mongodb.org/static/pgp/server-3.6.asc
              EOM

              yum install -y mongodb-org-3.6.23
              systemctl start mongod
              systemctl enable mongod
              EOF
}

# Random suffix for unique S3 bucket name
resource "random_id" "bucket_id" {
  byte_length = 4
}

# Public S3 bucket with misconfiguration (no block public access)
resource "aws_s3_bucket" "public_backups" {
  bucket = "wiz-backups-${random_id.bucket_id.hex}"
}

# Explicit ACL resource (replaces deprecated inline `acl`)
resource "aws_s3_bucket_acl" "public_acl" {
  bucket = aws_s3_bucket.public_backups.id
  acl    = "public-read"
}
