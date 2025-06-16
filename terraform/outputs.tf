output "instance_public_ip" {
  description = "Public IP of the MongoDB instance"
  value       = aws_instance.mongo.public_ip
}

output "s3_bucket_name" {
  description = "Name of the public S3 backup bucket"
  value       = aws_s3_bucket.public_backups.bucket
}

output "s3_bucket_url" {
  description = "Public URL to access objects in the S3 bucket"
  value       = "https://${aws_s3_bucket.public_backups.bucket}.s3.amazonaws.com/"
}

output "mongodb_status_url" {
  description = "Public URL to check MongoDB version and backup timestamp"
  value       = "http://${aws_instance.mongo.public_ip}/status.txt"
}
