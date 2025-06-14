provider "aws" {
  region = var.aws_region
}

# Create a VPC with a 10.0.0.0/16 CIDR block
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Create a public subnet in us-east-2a
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2a"
}

# Create an internet gateway to allow external access
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Create a route table that routes traffic to the internet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate the subnet with the route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Create a security group allowing SSH access (insecure for demo purposes)
resource "aws_security_group" "ssh_access" {
  name        = "ssh_access"
  description = "Allow SSH access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Insecure: open to the world
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch EC2 instance using Amazon Linux 2 and install outdated MongoDB
resource "aws_instance" "mongo" {
  ami                         = "ami-04505e74c0741db8d" # Amazon Linux 2 (us-east-2)
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  key_name                    = "wiz-key" # Make sure this key exists in your AWS Console
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ssh_access.id]

  tags = {
    Name = "MongoDB on Amazon Linux 2"
  }

  # Simulate insecure startup (installing outdated MongoDB 3.6)
  user_data = <<-EOF
              #!/bin/bash
              exec > /var/log/user-data.log 2>&1
              set -e

              # Install prerequisites
              yum update -y
              yum install -y wget curl

              # Add outdated MongoDB 3.6 repo
              cat > /etc/yum.repos.d/mongodb-org-3.6.repo << EOM
              [mongodb-org-3.6]
              name=MongoDB Repository
              baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/3.6/x86_64/
              gpgcheck=1
              enabled=1
              gpgkey=https://www.mongodb.org/static/pgp/server-3.6.asc
              EOM

              # Install outdated MongoDB
              yum install -y mongodb-org-3.6.23

              # Start MongoDB
              systemctl start mongod
              systemctl enable mongod
              EOF
}

# Public S3 bucket for MongoDB backups (insecure practice)
resource "aws_s3_bucket" "public_backups" {
  bucket = "wiz-backups-${random_id.bucket_id.hex}"

  # No block public access settings — insecure
  acl    = "public-read"

  tags = {
    Name = "MongoDB Backup Bucket"
  }
}

# Add random suffix to S3 bucket name to ensure uniqueness
resource "random_id" "bucket_id" {
  byte_length = 4
}
