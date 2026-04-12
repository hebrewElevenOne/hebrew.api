# Create the VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "hebrews-vpc" }
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
  name       = "hebrews-db-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

# Security Group for RDS (Allows 5432 from App Runner only)
resource "aws_security_group" "rds_sg" {
  name   = "hebrews-rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Only allow traffic from within our VPC
  }
}

resource "aws_db_instance" "postgres" {
  identifier           = "hebrews-db"
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

# IAM Role for Task Execution (Pulls the image from ECR)
resource "aws_iam_role" "ecs_execution_role" {
  name = "hebrew-api-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for Infrastructure (Manages the network/load balancer)
resource "aws_iam_role" "ecs_infrastructure_role" {
  name = "hebrew-api-infra-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# ECR Repo to store your Docker images
resource "aws_ecr_repository" "api" {
  name                 = "hebrew-api"
  force_delete         = true
}

# The ECS Express Service (Replaces App Runner)
resource "aws_ecs_express_gateway_service" "api" {
  name                    = "hebrew-api"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  infrastructure_role_arn  = aws_iam_role.ecs_infrastructure_role.arn
  
  # Connects to your existing VPC subnets
  subnet_ids         = [aws_subnet.public_a.id]
  security_group_ids = [aws_security_group.rds_sg.id] 

  primary_container {
    image          = "${aws_ecr_repository.api.repository_url}:latest"
    container_port = 8080
    
    environment {
      name  = "ConnectionStrings__DefaultConnection"
      value = "Host=${aws_db_instance.postgres.address};Port=5432;Database=${aws_db_instance.postgres.db_name};Username=adminuser;Password=${var.db_password};"
    }
  }
}





