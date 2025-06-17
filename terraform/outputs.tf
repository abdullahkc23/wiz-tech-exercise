output "instance_public_ip" {
  description = "Public IP of the MongoDB instance"
  value       = aws_instance.mongo.public_ip
}

output "s3_bucket_name" {
  description = "Name of the public S3 backup bucket"
  value       = aws_s3_bucket.public_backups.id
}

output "mongodb_status_url" {
  description = "Public URL to check MongoDB version and backup timestamp"
  value       = "http://${aws_instance.mongo.public_ip}/status.txt"
}

output "mongo_ami_id" {
  description = "The AMI ID used for the MongoDB instance"
  value       = aws_instance.mongo.ami
}

output "mongo_instance_state" {
  description = "State of the MongoDB instance"
  value       = aws_instance.mongo.instance_state
}

output "s3_bucket_arn" {
  description = "ARN of the S3 backup bucket"
  value       = aws_s3_bucket.public_backups.arn
}

output "mongo_version" {
  value = "3.6.23"
}
