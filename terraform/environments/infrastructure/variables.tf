variable "administrator_arn" {
  type = string
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
