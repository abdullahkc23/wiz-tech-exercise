provider "aws" {
  region = var.aws_region
}

# --- VPC Networking ---

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

# Create an internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Route table for internet access
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

# --- Security Group for SSH ---

resource "aws_security_group" "ssh_access" {
  name        = "ssh_access"
  description = "Allow SSH and HTTP access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
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

# --- EC2 Instance with Outdated MongoDB ---

resource "aws_instance" "mongo" {
  ami                         = "ami-05803413c51f242b7" # Ubuntu 16.04 LTS in us-east-2
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  key_name                    = "wiz-key"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ssh_access.id]

  tags = {
    Name = "MongoDB VM"
  }

  user_data = <<-EOF
              #!/bin/bash
              exec > /var/log/user-data.log 2>&1
              set -e

              # Install dependencies
              apt-get update
              apt-get install -y gnupg wget curl awscli apache2

              # Install MongoDB 3.6
              wget -qO - https://www.mongodb.org/static/pgp/server-3.6.asc | apt-key add -
              echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.6 multiverse" > /etc/apt/sources.list.d/mongodb-org-3.6.list
              apt-get update
              apt-get install -y mongodb-org=3.6.23

              systemctl start mongod
              systemctl enable mongod

              # Create Apache default index page
              echo "<h1>Apache is running</h1>" > /var/www/html/index.html

              # Create status.txt manually (to confirm Apache serving it works)
              echo "MongoDB Version:" > /var/www/html/status.txt
              mongod --version | head -n 1 >> /var/www/html/status.txt
              echo "Initial Backup Not Yet Run" >> /var/www/html/status.txt

              # Define backup script
              cat << 'EOL' > /opt/mongo_backup.sh
              #!/bin/bash
              TIMESTAMP=$(date +%F-%H-%M)
              BACKUP_DIR="/tmp/mongo_backup_$TIMESTAMP"
              S3_BUCKET="s3://wiz-backups-${random_id.bucket_id.hex}"

              mkdir -p "$BACKUP_DIR"
              mongodump --out "$BACKUP_DIR"

              tar -czvf "$BACKUP_DIR.tar.gz" -C "$BACKUP_DIR" .
              aws s3 cp "$BACKUP_DIR.tar.gz" "$S3_BUCKET/"
              echo "Last Backup: $TIMESTAMP" > /var/www/html/status.txt
              mongod --version | head -n 1 >> /var/www/html/status.txt
              EOL

              chmod +x /opt/mongo_backup.sh

              # Schedule hourly backup
              echo "0 * * * * root /opt/mongo_backup.sh" >> /etc/crontab

              # Start Apache
              systemctl start apache2
              systemctl enable apache2
              EOF
}

# --- Public S3 Bucket with Intentional Misconfig ---

# Random ID for unique bucket name
resource "random_id" "bucket_id" {
  byte_length = 4
}

# Create S3 bucket
resource "aws_s3_bucket" "public_backups" {
  bucket        = "wiz-backups-${random_id.bucket_id.hex}"
  force_destroy = true
}

# Allow public access by disabling block settings
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.public_backups.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# S3 is Public Read
#resource "aws_s3_bucket_policy" "public_policy" {
#  bucket = aws_s3_bucket.public_backups.id

#  policy = jsonencode({
#    Version = "2012-10-17",
#    Statement = [
#      {
#        Sid       = "PublicRead",
#        Effect    = "Allow",
#        Principal = "*",
#        Action    = "s3:GetObject",
#        Resource  = "${aws_s3_bucket.public_backups.arn}/*"
#      }
#    ]
#  })
#}
