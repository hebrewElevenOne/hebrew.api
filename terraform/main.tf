# Create the VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "sideline-vpc" }
}

# Public Subnets (For App Runner/Internet access)
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"
}

# Private Subnets (For your Database)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-1a"
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-southeast-1b" # RDS needs two subnets in different zones
}

# DB Subnet Group (Tells RDS which subnets to use)
resource "aws_db_subnet_group" "db_group" {
  name       = "sideline-db-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

# Security Group for RDS (Allows 5432 from App Runner only)
resource "aws_security_group" "rds_sg" {
  name   = "sideline-rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Only allow traffic from within our VPC
  }
}

resource "aws_db_instance" "postgres" {
  identifier           = "sideline-db"
  instance_class       = "db.t4g.micro"
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "16.2"
  username             = "adminuser"
  password             = var.db_password # We will set this in GitHub Secrets
  db_subnet_group_name = aws_db_subnet_group.db_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible  = false
  skip_final_snapshot  = true
}

