# S3 - TF State

resource "aws_s3_bucket" "ln_tf_state" {
  bucket        = var.tf_state_bucket
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "ln_tf_bucket_versioning" {
  bucket = aws_s3_bucket.ln_tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ln_tf_state_crypto_conf" {
  bucket = aws_s3_bucket.ln_tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


# S3 Variables

variable "bucket_prefix" {
  description = "Creates unique bucket name starting with specified prefix"
  type        = string
  default     = "ln-bucket"
}

variable "tf_state_bucket" {
  description = "S3 bucket for storing Terraform state"
  type        = string
  default     = "ln-tfbackend-bucket"
}