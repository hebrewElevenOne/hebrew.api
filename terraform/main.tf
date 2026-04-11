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
