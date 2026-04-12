# The Public URL of your .NET API (for React Native)
output "api_public_url" {
  description = "The public endpoint for your ECS Express Service"
  value       = aws_ecs_express_gateway_service.api.service_url
}

# The Database Address (for your records)
output "db_endpoint" {
  description = "The connection endpoint for the RDS database"
  value       = aws_db_instance.postgres.endpoint
}

# The IAM Roles (you'll need these for the GitHub Action secrets)
output "ecs_execution_role_arn" {
  value = aws_iam_role.ecs_execution_role.arn
}

output "ecs_infra_role_arn" {
  value = aws_iam_role.ecs_infrastructure_role.arn
}
