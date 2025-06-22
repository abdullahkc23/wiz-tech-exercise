variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "create_ec2" {
  description = "Set to true to create EC2 instance"
  type        = bool
  default     = true
}

variable "create_s3" {
  description = "Set to true to create S3 bucket"
  type        = bool
  default     = true
}

variable "create_iam" {
  description = "Set to true to create IAM role and instance profile"
  type        = bool
  default     = true
}

variable "create_eks" {
  description = "Flag to control EKS cluster creation"
  type        = bool
  default     = true
}

variable "account_id" {
  description = "AWS account ID (for GuardDuty member setup)"
  type        = string
  default     = ""
}

variable "account_email" {
  description = "Email associated with AWS account"
  type        = string
  default     = ""
}
