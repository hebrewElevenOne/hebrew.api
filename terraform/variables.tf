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
