provider "aws" {
  region                   = "ca-central-1"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "technoblather"
}

provider "aws" {
  alias  = "acm_provider"
  region = "us-east-1"
}
