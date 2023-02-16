provider "aws" {
  shared_credentials_files = ["~/.aws/credentials"] # TODO: is this necessary?
  profile = "mlaakso-admin" # TODO: extract to variable

  assume_role {
    role_arn = var.workspace_iam_roles[terraform.workspace]
  }
}

provider "aws" {
  alias  = "acm_provider"
  region = "us-east-1"
}
