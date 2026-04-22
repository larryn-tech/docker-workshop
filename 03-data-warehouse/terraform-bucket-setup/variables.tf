variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-west-1" # Set to your preferred AWS region
}

variable "bucket_name" {
  description = "Name for the S3 bucket"
  type        = string
  default     = "ln-zoomcamp-kestra-aws" # TODO: Replace with globally unique name
}