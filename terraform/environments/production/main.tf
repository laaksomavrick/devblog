
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  backend "s3" {
    bucket         = "technoblather-terraform-states"
    key            = "production.tfstate"
    region         = "ca-central-1"
    dynamodb_table = "technoblather-terraform"
  }

  required_version = ">= 1.2.0"
}

module "technoblather" {
  source = "../../modules/blog"

  domain_name  = "technoblather.ca"
  alert_emails = ["laakso.mavrick@gmail.com"]
  common_tags = {
    Project     = "technoblather"
    Environment = "production"
  }

  staging_name_servers = data.terraform_remote_state.technoblather-staging.outputs.aws_route53_zone_name_servers
  github_repo_path     = "laaksomavrick/devblog"

  providers = {
    aws.acm_provider = aws.acm_provider
  }
}