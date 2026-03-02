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
  name        = "${var.instance_name}-#{var.environment_name}-sg"
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
