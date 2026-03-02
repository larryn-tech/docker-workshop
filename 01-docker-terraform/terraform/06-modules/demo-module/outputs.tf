output "rds_endpoint" {
  description = "RDS instance hostname"
  value       = aws_db_instance.db_instance.address
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.db_instance.port
}

output "web_public_ip" {
  description = "Public IP address of web server"
  value       = aws_eip.ln_web_eip[0].public_ip
  depends_on  = [aws_eip.ln_web_eip]
}

output "web_public_dns" {
  description = "Public DNS address of web server"
  value       = aws_eip.ln_web_eip[0].public_dns
  depends_on  = [aws_eip.ln_web_eip]
}