provider "aws" {
  profile = var.aws_profile

  assume_role {
    role_arn = var.workspace_iam_roles[terraform.workspace]
  }
}

provider "aws" {
  alias  = "acm_provider"
  region = "us-east-1"
}
