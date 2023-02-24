provider "aws" {
  alias  = "acm_provider"
  region = "us-east-1"

  assume_role {
    role_arn = data.terraform_remote_state.infrastructure.outputs.tf_staging_role_arn
  }
}

provider "aws" {
  region = "ca-central-1"

  assume_role {
    role_arn = data.terraform_remote_state.infrastructure.outputs.tf_staging_role_arn
  }

}
