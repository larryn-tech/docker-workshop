variable "dev_db_pass" {
  description = "Password for dev database"
  type        = string
  sensitive   = true
}

variable "staging_db_pass" {
  description = "Password for staging database"
  type        = string
  sensitive   = true
}

variable "my_ip" {
  description = "Your IP address for SSH"
  type        = string
  sensitive   = true
}