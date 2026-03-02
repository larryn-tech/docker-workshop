terraform {
  required_version = ">= 1.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  # If Terraform state bucket has not been provisioned yet:
  # 1. Comment following backend block
  # 2. Run terraform init, plan, and & apply to provision S3 bucket
  # 3. Uncomment backend block
  # 4. Rerun terraform init to connect to remote backend

  #backend "s3" {
  #  bucket       = "ln-tfbackend-bucket"
  #  key          = "tf-infra/terraform.tfstate"
  #  region       = "us-west-1"
  #  use_lockfile = true
  #  encrypt      = true
  #}

  # Before running terraform destroy:
  # 1. Run the following to download TF state
  #       terraform state pull > terraform.tfstate
  # 2. Comment out backend block
  # 3. Run terraform init -migrate-state
  # 4. Run terraform destroy
}