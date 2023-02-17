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
