variable "db_password" {
  description = "The password for the RDS instance"
  type        = string
  sensitive   = true
}

variable "image_tag" {
  description = "The Docker image tag to deploy (e.g., from GitHub SHA)"
  type        = string
  default     = "latest" # Optional: provides a fallback if no tag is provided
}

variable "app_environment" {
  description = "The environment for the .NET application (e.g., Development, Production)"
  type        = string
  default     = "Production"
}

variable "swagger_username" {
  description = "username for basic auth"
  type        = string
}

variable "swagger_password" {
  description =  "password for basic auth"
  type        = string
}
