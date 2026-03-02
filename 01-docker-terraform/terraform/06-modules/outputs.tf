output "dev_web_public_dns" {
  value = module.web_app_dev.web_public_dns
}

output "staging_web_public_dns" {
  value = module.web_app_staging.web_public_dns
}

output "dev_rds_endpoint" {
  value = module.web_app_dev.rds_endpoint
}

output "staging_rds_endpoint" {
  value = module.web_app_staging.rds_endpoint
}