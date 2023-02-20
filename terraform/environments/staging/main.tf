terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }

  }

  backend "s3" {
    bucket         = "technoblather-terraform-states"
    key            = "staging.tfstate"
    region         = "ca-central-1"
    dynamodb_table = "technoblather-terraform"
  }

  required_version = ">= 1.2.0"
}

module "technoblather-staging" {
  source = "../../modules/blog"

  # TODO: extract to tfvars
  domain_name = "staging.technoblather.ca"
  common_tags = {
    Project     = "technoblather"
    Environment = "staging"
  }

  providers = {
    aws.acm_provider = aws.acm_provider
  }
}