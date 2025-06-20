# --- EKS IAM Role for Control Plane ---
resource "aws_iam_role" "eks_cluster_role" {
  count = var.create_eks ? 1 : 0
  name  = "wiz-eks-cluster-role-v3"

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

# --- EKS Cluster ---
resource "aws_eks_cluster" "wiz_eks" {
  count    = var.create_eks ? 1 : 0
  name     = "wiz-eks-cluster-v3"
  version  = "1.29"
  role_arn = aws_iam_role.eks_cluster_role[0].arn

  vpc_config {
    subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# --- EKS IAM Role for Worker Nodes ---
resource "aws_iam_role" "eks_node_role" {
  count = var.create_eks ? 1 : 0
  name  = "wiz-eks-node-role-v3"

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
  node_group_name = "wiz-eks-nodes-v3"
  node_role_arn   = aws_iam_role.eks_node_role[0].arn
  subnet_ids      = [aws_subnet.public.id]

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
