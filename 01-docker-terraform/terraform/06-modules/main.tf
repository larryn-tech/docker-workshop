provider "aws" {
  region = "us-west-1"
}

module "web_app_dev" {
  source = "./demo-module"

  # Input variables
  environment_name = "dev"
  db_name          = "web_app_dev_db"
  db_user          = "root"
  db_pass          = var.dev_db_pass
  my_ip            = var.my_ip
  ssh_key_name     = aws_key_pair.ln_ec2_kp.key_name
}

module "web_app_staging" {
  source = "./demo-module"

  # Input variables
  environment_name = "staging"
  db_name          = "web_app_staging_db"
  db_user          = "root"
  db_pass          = var.staging_db_pass
  my_ip            = var.my_ip
  ssh_key_name     = aws_key_pair.ln_ec2_kp.key_name
}