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

# Create a route table that routes traffic to the internet gateway
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

# Launch an EC2 instance with outdated Ubuntu 16.04 and install outdated MongoDB
resource "aws_instance" "mongo" {
  ami           = "ami-0ddda618e961f2270" # Ubuntu 16.04 LTS (outdated)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  key_name      = "wiz-key" # Ensure this key exists in the AWS console
  associate_public_ip_address = true

  tags = {
    Name = "MongoDB VM"
  }

  # Install outdated MongoDB 3.6 on startup
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y gnupg
              wget -qO - https://www.mongodb.org/static/pgp/server-3.6.asc | apt-key add -
              echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.6 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-3.6.list
              apt-get update
              apt-get install -y mongodb-org=3.6.23 mongodb-org-server=3.6.23 mongodb-org-shell=3.6.23 mongodb-org-mongos=3.6.23 mongodb-org-tools=3.6.23
              systemctl start mongod
              systemctl enable mongod
              EOF
}

# Create an S3 bucket for backups with a public website configuration (deprecated)
resource "aws_s3_bucket" "public_backups" {
  bucket = "wiz-backups-${random_id.bucket_id.hex}"

  website {
    index_document = "index.html"
  }
}

# Random suffix to make the S3 bucket name globally unique
resource "random_id" "bucket_id" {
  byte_length = 4
}

