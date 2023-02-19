variable "aws_profile" {
  type        = string
  description = "The name of the aws profile to use."
}

variable "stack_name" {
  type        = string
  description = "The stack name for the module. Must be unique."
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

variable "is_production" {
  type        = bool
  description = "Whether or not this environment is the production environment"
}

variable "staging_name_servers" {
  type        = list(string)
  description = "List of staging name servers. Needs to be set if is_production is true."
  default     = []
}