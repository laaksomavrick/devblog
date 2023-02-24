terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  backend "s3" {
    bucket         = "technoblather-terraform-states"
    key            = "infrastructure.tfstate"
    region         = "ca-central-1"
    dynamodb_table = "technoblather-terraform"
  }

  required_version = ">= 1.2.0"
}