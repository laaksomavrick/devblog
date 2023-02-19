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

module "technoblather" {
  source = "../../modules/blog"

  aws_profile  = "default"
  alert_emails = ["laakso.mavrick@gmail.com"]
  common_tags = {
    Project     = "technoblather"
    Environment = "staging"
  }
  domain_name = "staging.technoblather.ca"
  bucket_name = "staging.technoblather.ca"

  providers = {
    aws.acm_provider = aws.acm_provider
  }
}

# Would be nice to:
# - run terraform plan/terraform apply without specifying the module (as changes will affect both)
# - not accidentally run an infra update on production
#    => create a profile that only has access to staging and reference that in tfvars
# https://blog.gruntwork.io/how-to-create-reusable-infrastructure-with-terraform-modules-25526d65f73d