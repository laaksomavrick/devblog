data "terraform_remote_state" "staging_name_servers" {
  backend = "s3"
  config = {
    bucket = "technoblather-staging-terraform"
    key    = "tfstate"
    region = "ca-central-1"
  }
}

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

  # TODO: extract to tfvars
  domain_name  = "technoblather.ca"
  alert_emails = ["laakso.mavrick@gmail.com"]
  common_tags = {
    Project     = "technoblather"
    Environment = "production"
  }

  staging_name_servers = data.terraform_remote_state.staging_name_servers.outputs.aws_route53_zone_name_servers

  providers = {
    aws.acm_provider = aws.acm_provider
  }
}