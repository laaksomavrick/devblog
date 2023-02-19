terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  backend "s3" {
    bucket         = "technoblather-staging-terraform"
    dynamodb_table = "technoblather-staging-terraform"
    key            = "tfstate"
    region         = "ca-central-1"
  }

  required_version = ">= 1.2.0"
}

module "technoblather-staging" {
  source = "../../modules/blog"

  # TODO: extract to tfvars
  aws_profile  = "default"
  stack_name   = "staging"
  alert_emails = ["laakso.mavrick@gmail.com"]
  common_tags = {
    Project     = "technoblather"
    Environment = "staging"
  }
  domain_name   = "staging.technoblather.ca"
  bucket_name   = "staging.technoblather.ca"
  is_production = false

  providers = {
    aws.acm_provider = aws.acm_provider
  }
}