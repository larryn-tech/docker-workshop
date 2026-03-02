provider "aws" {
  region = var.region
}

# VPC

resource "aws_vpc" "ln_vpc" {
  cidr_block = var.vpc_cidr_block
}

resource "aws_internet_gateway" "ln_igw" {
  vpc_id = aws_vpc.ln_vpc.id
}

resource "aws_subnet" "ln_private_subnet_a" {
  vpc_id            = aws_vpc.ln_vpc.id
  cidr_block        = var.private_subnet_cidrs[0]
  availability_zone = var.azs[0]
}

resource "aws_subnet" "ln_private_subnet_b" {
  vpc_id            = aws_vpc.ln_vpc.id
  cidr_block        = var.private_subnet_cidrs[1]
  availability_zone = var.azs[1]
}

resource "aws_subnet" "ln_public_subnet" {
  vpc_id            = aws_vpc.ln_vpc.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = var.azs[0]
}

# Route Tables

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.ln_vpc.id
}

resource "aws_route_table_association" "private_rt_association_a" {
  subnet_id      = aws_subnet.ln_private_subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_rt_association_b" {
  subnet_id      = aws_subnet.ln_private_subnet_b.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.ln_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ln_igw.id
  }
}

resource "aws_route_table_association" "public_rt_association" {
  subnet_id      = aws_subnet.ln_public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Default Security Group

resource "aws_security_group" "ln_default_sg" {
  description = "Default security group to allow inbound/outbound traffic from VPC"
  vpc_id      = aws_vpc.ln_vpc.id
  depends_on  = [aws_vpc.ln_vpc]
}

resource "aws_security_group_rule" "allow_ssh_in" {
  description       = "Allow inbound SSH for EC2 instance"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["${var.my_ip}/32"]
  security_group_id = aws_security_group.ln_default_sg.id
}

resource "aws_security_group_rule" "allow_http_in" {
  description       = "Allow inbound HTTPS traffic"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ln_default_sg.id
}

resource "aws_security_group_rule" "allow_all_out" {
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ln_default_sg.id
}

# EC2

resource "aws_key_pair" "ln_ec2_kp" {
  key_name   = "ln_ec2_kp"
  public_key = file(".ssh/ec2_kp.pub")
}

resource "aws_instance" "ln_web_server" {
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.ln_public_subnet.id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ln_ec2_kp.key_name
  vpc_security_group_ids      = [aws_security_group.ln_default_sg.id]
  depends_on                  = [aws_security_group.ln_default_sg]

  tags = {
    Name = var.instance_name
  }
}

resource "aws_eip" "ln_web_eip" {
  count    = 1
  instance = aws_instance.ln_web_server.id
  domain   = "vpc"
}

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

# RDS

resource "aws_db_subnet_group" "ln_private_db_subnet" {
  name        = "psql-rds-private-subnet-group"
  subnet_ids  = [aws_subnet.ln_private_subnet_a.id, aws_subnet.ln_private_subnet_b.id]
  description = "Private subnets for RDS"
}

resource "aws_security_group" "ln_rds_sg" {
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