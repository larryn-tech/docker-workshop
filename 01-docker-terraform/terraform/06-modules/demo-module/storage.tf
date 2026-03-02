# RDS

resource "aws_db_subnet_group" "ln_private_db_subnet" {
  name        = "${var.environment_name}-psql-rds-private-subnet-group"
  subnet_ids  = [aws_subnet.ln_private_subnet_a.id, aws_subnet.ln_private_subnet_b.id]
  description = "Private subnets for RDS"
}

resource "aws_security_group" "ln_rds_sg" {
  name        = "${var.db_name}-rds-sg"
  description = "RDS security group to allow psql traffic"
  vpc_id      = aws_vpc.ln_vpc.id
  depends_on  = [aws_vpc.ln_vpc]
}

resource "aws_security_group_rule" "allow_psql_in" {
  description              = "Allow inbound PostgreSQL connections"
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ln_default_sg.id
  security_group_id        = aws_security_group.ln_rds_sg.id
}

resource "aws_db_instance" "db_instance" {
  db_name                = var.db_name
  allocated_storage      = 20
  storage_type           = "gp3"
  engine                 = "postgres"
  engine_version         = "18"
  instance_class         = "db.t3.micro"
  multi_az               = true
  username               = var.db_user
  password               = var.db_pass
  db_subnet_group_name   = aws_db_subnet_group.ln_private_db_subnet.name
  vpc_security_group_ids = [aws_security_group.ln_rds_sg.id]
  skip_final_snapshot    = true
}