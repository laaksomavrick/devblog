variable "administrator_arn" {
  type        = string
  description = "The ARN for the technoblather administrator IAM role - check AWS console for TechnoblatherAdministrator"
}

variable "domain_name" {
  type    = string
  default = "technoblather.ca"
}

variable "tfstate_bucket" {
  type    = string
  default = "technoblather-terraform-states"
}

variable "production_tfstate_key" {
  type    = string
  default = "production.tfstate"
}
variable "staging_tfstate_key" {
  type    = string
  default = "staging.tfstate"
}
