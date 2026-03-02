# EC2

resource "aws_instance" "ln_web_server" {
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.ln_public_subnet.id
  associate_public_ip_address = true
  key_name                    = var.ssh_key_name
  vpc_security_group_ids      = [aws_security_group.ln_default_sg.id]
  depends_on                  = [aws_security_group.ln_default_sg]

  tags = {
    Name = "${var.instance_name}-${var.environment_name}"
  }
}

resource "aws_eip" "ln_web_eip" {
  count    = 1
  instance = aws_instance.ln_web_server.id
  domain   = "vpc"
}
