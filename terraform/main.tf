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

# Inside your main.tf App Runner resource
resource "aws_apprunner_service" "api" {
  service_name = "hebrew-api"

  # THIS block belongs here
  instance_configuration {
    cpu    = "0.25 vCPU"
    memory = "0.5 GB"
    # instance_role_arn = aws_iam_role.apprunner_role.arn (Uncomment if you have the role)
  }

  # THIS block belongs here
  source_configuration {
    authentication_configuration {
      # This is the ARN for your GitHub Connection in App Runner
      connection_arn = var.app_runner_github_connection_arn 
    }
    
    code_repository {
      repository_url = "https://github.com"
      source_code_version {
        type  = "BRANCH"
        value = "main"
      }
      code_configuration {
        configuration_source = "API"
        code_configuration_values {
          runtime = "DOTNET_8"
          port    = "8080"
          runtime_environment_variables = {
            "ConnectionStrings__DefaultConnection" = "Host=${aws_db_instance.postgres.address};Port=5432;Database=${aws_db_instance.postgres.db_name};Username=adminuser;Password=${var.db_password};"
          }
        }
      }
    }
  }

  network_configuration {
    egress_configuration {
      egress_type       = "VPC"
      vpc_connector_arn = aws_apprunner_vpc_connector.connector.arn
    }
  }
}

# Create the VPC Connector
resource "aws_apprunner_vpc_connector" "connector" {
  vpc_connector_name = "sideline-vpc-connector"
  subnets            = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_groups    = [aws_security_group.rds_sg.id] # Reuse rds_sg or create a specific one
}



