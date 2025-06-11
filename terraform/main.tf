provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2a"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_instance" "mongo" {
  ami           = "ami-0ddda618e961f2270" # Ubuntu 16.04 (outdated)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  key_name      = "wiz-key"
  associate_public_ip_address = true

  tags = {
    Name = "MongoDB VM"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y mongodb
              systemctl start mongodb
              systemctl enable mongodb
              EOF
}

resource "aws_s3_bucket" "public_backups" {
  bucket = "wiz-backups-${random_id.bucket_id.hex}"

  acl    = "public-read"

  website {
    index_document = "index.html"
  }
}

resource "random_id" "bucket_id" {
  byte_length = 4
}
