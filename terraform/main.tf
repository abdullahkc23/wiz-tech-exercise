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

              # Update and install MongoDB 3.6
              apt-get update
              apt-get install -y gnupg wget curl awscli apache2

              wget -qO - https://www.mongodb.org/static/pgp/server-3.6.asc | apt-key add -
              echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.6 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-3.6.list

              apt-get update
              apt-get install -y mongodb-org=3.6.23 mongodb-org-server=3.6.23 mongodb-org-shell=3.6.23 mongodb-org-mongos=3.6.23 mongodb-org-tools=3.6.23

              systemctl start mongod
              systemctl enable mongod

              # Create a backup script
              cat << 'EOL' > /opt/mongo_backup.sh
              #!/bin/bash
              TIMESTAMP=$(date +%F-%H-%M)
              BACKUP_DIR="/tmp/mongo_backup_$TIMESTAMP"
              S3_BUCKET="s3://${aws_s3_bucket.public_backups.bucket}"

              mkdir -p "$BACKUP_DIR"
              mongodump --out "$BACKUP_DIR"

              tar -czvf "$BACKUP_DIR.tar.gz" -C "$BACKUP_DIR" .
              aws s3 cp "$BACKUP_DIR.tar.gz" "$S3_BUCKET/"
              echo "Last Backup: $TIMESTAMP" > /var/www/html/status.txt
              mongod --version | head -n 1 >> /var/www/html/status.txt
              EOL

              chmod +x /opt/mongo_backup.sh

              # Run the backup script immediately
              /opt/mongo_backup.sh

              # Set up cron to run hourly
              echo "0 * * * * root /opt/mongo_backup.sh" >> /etc/crontab

              # Apache to serve the status page
              systemctl start apache2
              systemctl enable apache2

              echo "MongoDB Version:" > /var/www/html/status.txt
              mongod --version | head -n 1 >> /var/www/html/status.txt
              echo "Initial Backup Triggered" >> /var/www/html/status.txt
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

# Apply public-read access via policy
resource "aws_s3_bucket_policy" "public_policy" {
  bucket = aws_s3_bucket.public_backups.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicRead",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.public_backups.arn}/*"
      }
    ]
  })
}
