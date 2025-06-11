output "instance_public_ip" {
  description = "Public IP of the MongoDB instance"
  value       = aws_instance.mongo.public_ip
}

output "s3_bucket_url" {
  description = "Public S3 backup bucket URL"
  value       = aws_s3_bucket.public_backups.website_endpoint
}
