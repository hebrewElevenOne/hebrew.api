# --- VPC & Networking ---
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-1a"
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-southeast-1b"
}

resource "aws_db_subnet_group" "db_group" {
  name       = "hebrews-db-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

# --- Database ---
resource "aws_db_parameter_group" "postgres16" {
  name   = "hebrews-db-params"
  family = "postgres16"
}

resource "aws_db_instance" "postgres" {
  identifier           = "hebrews-db"
  instance_class       = "db.t4g.micro"
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "16"
  username             = "adminuser"
  password             = var.db_password
  db_subnet_group_name = aws_db_subnet_group.db_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  parameter_group_name = aws_db_parameter_group.postgres16.name
  
  publicly_accessible  = false
  skip_final_snapshot  = true

  # Re-enabled these as they are best practices
  maintenance_window         = "sun:03:00-sun:04:00"
  auto_minor_version_upgrade = true
  backup_window              = "01:00-02:00"
  backup_retention_period    = 7
}

# --- Security Groups ---
resource "aws_security_group" "rds_sg" {
  name   = "hebrews-rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] 
  }
}

# --- IAM Roles ---

# Task Execution Role: Used to pull images and push logs
resource "aws_iam_role" "ecs_execution_role" {
  name = "hebrews-api-execution-role" 
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "://amazonaws.com" } # FIXED
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" # FIXED
}

# Infrastructure Role: Required for Express Mode to manage networking
resource "aws_iam_role" "ecs_infrastructure_role" {
  name = "hebrews-infrastructure-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",      
      Principal = { 
        Service = [
          "://amazonaws.com", 
          "delivery.://amazonaws.com" # FIXED
        ] 
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "infrastructure_policy" {
  role       = aws_iam_role.ecs_infrastructure_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRolePolicyForService" # REQUIRED FOR EXPRESS
}

# --- Logs & ECR ---
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/ecs/hebrews-api"
  retention_in_days = 7
}

resource "aws_ecr_repository" "api" {
  name         = "hebrews-api"
  force_delete = true
}

# --- ECS Express Service ---
resource "aws_ecs_express_gateway_service" "api" {
  service_name             = "hebrews-api"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  infrastructure_role_arn  = aws_iam_role.ecs_infrastructure_role.arn
  
  health_check_path = "/health" 

  primary_container {
    image          = "${aws_ecr_repository.api.repository_url}:latest"
    container_port = 8080
    
    aws_logs_configuration { # FIXED
      log_group = aws_cloudwatch_log_group.api_logs.name
    }

    environment {
      name  = "ConnectionStrings__DefaultConnection"
      value = "Host=${aws_db_instance.postgres.address};Port=5432;Database=postgres;Username=adminuser;Password=${var.db_password};"
    }
  }
}
