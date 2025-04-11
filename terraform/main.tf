provider "aws" {
  region = var.aws_region
}

# S3 bucket to store the application JAR
resource "aws_s3_bucket" "app_bucket" {
  bucket = "securelend-auth-bucket-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Upload the JAR to S3
resource "aws_s3_object" "app_jar" {
  bucket = aws_s3_bucket.app_bucket.bucket
  key    = "authservice-0.0.1-SNAPSHOT.jar"
  source = "../target/authservice-0.0.1-SNAPSHOT.jar" # Built by GitHub Actions
}

# Elastic Beanstalk Application
resource "aws_elastic_beanstalk_application" "securelend_auth" {
  name        = "securelend-auth"
  description = "Authentication service for SecureLend"
}

# Elastic Beanstalk Application Version
resource "aws_elastic_beanstalk_application_version" "v1" {
  name        = "v${timestamp()}"  # Unique version per deploy
  application = aws_elastic_beanstalk_application.securelend_auth.name
  bucket      = aws_s3_bucket.app_bucket.bucket
  key         = aws_s3_object.app_jar.key
}

# Elastic Beanstalk Environment
resource "aws_elastic_beanstalk_environment" "securelend_auth_env" {
  name                = "securelend-auth-env"
  application         = aws_elastic_beanstalk_application.securelend_auth.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.1.1 running Corretto 17"
  version_label       = aws_elastic_beanstalk_application_version.v1.name

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t3.micro"
  }

  setting {
    namespace = "aws:elasticbeanstalk:container:java"
    name      = "Port"
    value     = "5000"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "SPRING_JWT_SECRET"
    value     = var.jwt_secret
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "SPRING_JWT_EXPIRATION"
    value     = "86400000"  # Hardcoded per your choice
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }

  setting {
    namespace = "aws:elbv2:listener:80"
    name      = "ListenerEnabled"
    value     = "true"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "1"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "4"
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs"
    value     = "true"
  }
}