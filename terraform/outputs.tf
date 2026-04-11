# The URL of your .NET API
output "app_runner_url" {
  description = "The URL of the App Runner service"
  value       = aws_apprunner_service.api.service_url
}

# The address of your RDS Database (Important for your .NET Connection String)
output "db_endpoint" {
  description = "The connection endpoint for the RDS database"
  value       = aws_db_instance.postgres.endpoint
}

# The name of the database created
output "db_name" {
  value = aws_db_instance.postgres.db_name
}
