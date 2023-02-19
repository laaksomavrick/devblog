terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  backend "s3" {
    bucket         = "technoblather-terraform"
    dynamodb_table = "technoblather-terraform"
    key            = "tfstate"
    region         = "ca-central-1"
  }

  required_version = ">= 1.2.0"
}

module "technoblather" {
  source = "../../modules/blog"

  aws_profile  = "default"
  alert_emails = ["laakso.mavrick@gmail.com"]
  common_tags = {
    Project     = "technoblather"
    Environment = "production"
  }
  domain_name = "technoblather.ca"
  bucket_name = "technoblather.ca"

  providers = {
    aws.acm_provider = aws.acm_provider
  }
}

# Would be nice to:
# - run terraform plan/terraform apply without specifying the module (as changes will affect both)
# - not accidentally run an infra update on production
#    => module versioning?
# create iam roles for staging/prod respectively for use with running this ?
# https://blog.gruntwork.io/how-to-create-reusable-infrastructure-with-terraform-modules-25526d65f73d