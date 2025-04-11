terraform {
  backend "s3" {
    bucket = "securelend-terraform-state"
    key    = "state/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_iam_role" "eb_instance_role" {
  name = "securelend-eb-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eb_instance_policy" {
  role       = aws_iam_role.eb_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_instance_profile" "eb_instance_profile" {
  name = "securelend-eb-instance-profile"
  role = aws_iam_role.eb_instance_role.name
}

resource "aws_s3_bucket" "app_bucket" {
  bucket = "securelend-auth-bucket-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_object" "app_jar" {
  bucket = aws_s3_bucket.app_bucket.bucket
  key    = "securelend-backend-0.0.1-SNAPSHOT.jar"
  source = "securelend-backend-0.0.1-SNAPSHOT.jar"
}

resource "aws_elastic_beanstalk_application" "securelend_auth" {
  name        = "securelend-auth"
  description = "Authentication service for SecureLend"
}

resource "aws_elastic_beanstalk_application_version" "v1" {
  name        = "v${timestamp()}"
  application = aws_elastic_beanstalk_application.securelend_auth.name
  bucket      = aws_s3_bucket.app_bucket.bucket
  key         = aws_s3_object.app_jar.key
}

resource "aws_elastic_beanstalk_environment" "securelend_auth_env" {
  name                = "securelend-auth-env"
  application         = aws_elastic_beanstalk_application.securelend_auth.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.5.0 running Corretto 17"
  version_label       = aws_elastic_beanstalk_application_version.v1.name

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_instance_profile.name
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t3.micro"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "SERVER_PORT"
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
    value     = "86400000"
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
    namespace = "aws:elb:healthcheck"
    name      = "Target"
    value     = "TCP:5000"
  }

  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "Timeout"
    value     = "1800"  # 30 minutes for deployment commands
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