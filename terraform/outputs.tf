output "instance_public_ip" {
  description = "Public IP of the MongoDB instance"
  value       = var.create_ec2 ? aws_instance.mongo[0].public_ip : null
}

output "s3_bucket_name" {
  description = "Name of the public S3 backup bucket"
  value       = var.create_s3 ? aws_s3_bucket.public_backups[0].id : null
}

output "mongodb_status_url" {
  description = "Public URL to check MongoDB version and backup timestamp"
  value       = var.create_ec2 ? "http://${aws_instance.mongo[0].public_ip}/status.txt" : null
}

output "mongo_ami_id" {
  description = "The AMI ID used for the MongoDB instance"
  value       = var.create_ec2 ? aws_instance.mongo[0].ami : null
}

output "mongo_instance_state" {
  description = "State of the MongoDB instance"
  value       = var.create_ec2 ? aws_instance.mongo[0].instance_state : null
}

output "s3_bucket_arn" {
  description = "ARN of the S3 backup bucket"
  value       = var.create_s3 ? aws_s3_bucket.public_backups[0].arn : null
}

output "mongo_version" {
  description = "Installed MongoDB version"
  value       = "3.6.23"
}

# Uncomment this section only if you add the corresponding data block
# output "latest_backup_file" {
#   description = "Latest MongoDB backup file in S3"
#   value       = (
#     var.create_s3 && length(data.aws_s3_bucket_object.latest_backup.*.key) > 0
#     ? data.aws_s3_bucket_object.latest_backup[0].key
#     : "No backups found"
#   )
# }
