variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "jwt_secret" {
  description = "Secret key for JWT signing (must be at least 32 bytes for HS256)"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.jwt_secret) >= 32
    error_message = "JWT secret must be at least 32 bytes (256 bits) for security."
  }
}