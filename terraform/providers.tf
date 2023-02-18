provider "aws" {
  alias  = "acm_provider"
  region = "us-east-1"
}

provider "aws" {
  profile = var.aws_profile
  region  = "ca-central-1"
}
