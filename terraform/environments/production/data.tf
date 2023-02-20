data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = "technoblather-terraform-states"
    key    = "infrastructure.tfstate"
    region = "ca-central-1"
  }
}

data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = "technoblather-terraform-states"
    key    = "infrastructure.tfstate"
    region = "ca-central-1"
  }
}
