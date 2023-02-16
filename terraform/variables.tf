variable "workspace_iam_roles" {
  type = map(string)
  description = "The IAM roles for the different workspace environments to be assumed"
  default = {
    staging    = "arn:aws:iam::844544735981:role/TechnoblatherAdministrator" # TODO: specify in tfvars
    production = "arn:aws:iam::844544735981:role/TechnoblatherAdministrator" # TODO: specify in tfvars
  }
}

variable "domain_name" {
  type        = string
  description = "The domain name for the website."
}

variable "bucket_name" {
  type        = string
  description = "The name of the bucket without the www. prefix. Normally domain_name."
}

variable "common_tags" {
  description = "Common tags you want applied to all components."
}

variable "alert_emails" {
  type        = list(string)
  description = "A list of emails for alerting via cloudwatch alarms."
}