output "s3_bucket_arn" {
  value       = aws_s3_bucket.snowflake_raw_storage.arn
  description = "The ARN of the S3 bucket"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.snowflake_raw_storage.id
}