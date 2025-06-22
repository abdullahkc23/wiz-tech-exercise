provider "aws" {
  region = var.aws_region
}

# --- IAM Role & Policy ---
resource "aws_iam_role" "ec2_s3_role" {
  count = var.create_iam ? 1 : 0
  name  = "wiz-ec2-s3-role-v15"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [name]
  }

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "s3_backup_policy" {
  count       = var.create_iam ? 1 : 0
  name        = "wiz-s3-backup-policy-v15"
  description = "EC2 to S3 access policy"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [name]
  }

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"],
      Resource = [
        "${aws_s3_bucket.public_backups[0].arn}",
        "${aws_s3_bucket.public_backups[0].arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_s3_attachment" {
  count      = var.create_iam ? 1 : 0
  role       = aws_iam_role.ec2_s3_role[0].name
  policy_arn = aws_iam_policy.s3_backup_policy[0].arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  count = var.create_iam ? 1 : 0
  name  = "wiz-ec2-instance-profile-v15"
  role  = aws_iam_role.ec2_s3_role[0].name

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [name]
  }
}

# --- VPC, Subnet, Route, SG ---
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2a"
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = true
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

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ssh_access" {
  name        = "ssh_access"
  description = "Allow SSH, HTTP and MongoDB access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
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

# --- EC2 Instance ---
resource "aws_instance" "mongo" {
  count                       = var.create_ec2 ? 1 : 0
  ami                         = "ami-05803413c51f242b7"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_a.id
  key_name                    = "wiz-key"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ssh_access.id]
  iam_instance_profile        = var.create_iam ? aws_iam_instance_profile.ec2_instance_profile[0].name : null

  tags = { Name = "MongoDB VM" }

  user_data = <<-EOF
              #!/bin/bash
              exec > /var/log/user-data.log 2>&1
              set -x
              apt-get update
              apt-get install -y gnupg wget curl apache2 awscli
              wget -qO - https://www.mongodb.org/static/pgp/server-3.6.asc | apt-key add -
              echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.6 multiverse" > /etc/apt/sources.list.d/mongodb-org-3.6.list
              apt-get update
              apt-get install -y mongodb-org=3.6.23
              sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
              systemctl start mongod || true
              systemctl enable mongod || true
              systemctl start apache2
              systemctl enable apache2
              echo "<html><body><h1>Apache OK</h1></body></html>" > /var/www/html/index.html
              sleep 15
              cat << 'EOL' > /opt/mongo_backup.sh
              #!/bin/bash
              TIMESTAMP=$(date +%F-%H-%M)
              BACKUP_DIR="/tmp/mongo_backup_$TIMESTAMP"
              S3_BUCKET="s3://${aws_s3_bucket.public_backups[0].bucket}"
              mkdir -p "$BACKUP_DIR"
              mongodump --out "$BACKUP_DIR"
              tar -czf "$BACKUP_DIR.tar.gz" -C "$BACKUP_DIR" .
              aws s3 cp "$BACKUP_DIR.tar.gz" "$S3_BUCKET/"
              echo "Last Backup: $TIMESTAMP" > /var/www/html/status.txt
              mongod --version | head -n 1 >> /var/www/html/status.txt
              EOL
              chmod +x /opt/mongo_backup.sh
              /opt/mongo_backup.sh
              echo "0 * * * * root /opt/mongo_backup.sh" >> /etc/crontab
              EOF
}

# --- S3 Bucket ---
resource "random_id" "bucket_id" {
  byte_length = 4
}

resource "aws_s3_bucket" "public_backups" {
  count         = var.create_s3 ? 1 : 0
  bucket        = "wiz-backups-${random_id.bucket_id.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  count                   = var.create_s3 ? 1 : 0
  bucket                  = aws_s3_bucket.public_backups[0].id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}


# --- EKS IAM Role for Control Plane ---
resource "aws_iam_role" "eks_cluster_role" {
  count = var.create_eks ? 1 : 0
  name  = "wiz-eks-cluster-role-v8"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count      = var.create_eks ? 1 : 0
  role       = aws_iam_role.eks_cluster_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cloudwatch_logs" {
  count      = var.create_eks ? 1 : 0
  role       = aws_iam_role.eks_cluster_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# --- EKS Cluster ---
resource "aws_eks_cluster" "wiz_eks" {
  count    = var.create_eks ? 1 : 0
  name     = "wiz-eks-cluster-v8"
  version  = "1.29"
  role_arn = aws_iam_role.eks_cluster_role[0].arn

  vpc_config {
    subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_cloudwatch_logs
  ]
}

# --- EKS IAM Role for Worker Nodes ---
resource "aws_iam_role" "eks_node_role" {
  count = var.create_eks ? 1 : 0
  name  = "wiz-eks-node-role-v8"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  count      = var.create_eks ? 1 : 0
  role       = aws_iam_role.eks_node_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  count      = var.create_eks ? 1 : 0
  role       = aws_iam_role.eks_node_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_registry_policy" {
  count      = var.create_eks ? 1 : 0
  role       = aws_iam_role.eks_node_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# --- EKS Managed Node Group ---
resource "aws_eks_node_group" "wiz_nodes" {
  count           = var.create_eks ? 1 : 0
  cluster_name    = aws_eks_cluster.wiz_eks[0].name
  node_group_name = "wiz-eks-nodes-v8"
  node_role_arn   = aws_iam_role.eks_node_role[0].arn
  subnet_ids      = [aws_subnet.public_a.id]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_registry_policy
  ]
}
