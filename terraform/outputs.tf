output "app_url" {
  description = "URL of the deployed Elastic Beanstalk environment"
  value       = aws_elastic_beanstalk_environment.securelend_auth_env.endpoint_url
}