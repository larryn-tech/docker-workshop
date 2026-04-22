provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "snowflake_raw_storage" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = {
    Name = "Zoomcamp"
  }
}

resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.snowflake_raw_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}