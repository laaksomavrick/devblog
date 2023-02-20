variable "aws_profile" {
  type        = string
  description = "The name of the aws profile to use."
  default = "default"
}

variable "domain_name" {
  type        = string
  description = "The domain name for the website."
}

variable "common_tags" {
  description = "Common tags you want applied to all components."
  type = object({
    Project     = string
    Environment = string
  })

  validation {
    condition     = var.common_tags["Environment"] == "production" || var.common_tags["Environment"] == "staging"
    error_message = "Environment must be either 'staging' or 'production'"
  }

  validation {
    condition     = var.common_tags["Project"] == "technoblather"
    error_message = "Project must be 'technoblather'"
  }
}

variable "alert_emails" {
  type        = list(string)
  description = "A list of emails for alerting via cloudwatch alarms."
  default = []
}

variable "staging_name_servers" {
  type        = list(string)
  description = "List of staging name servers. Needs to be set if is_production is true."
  default     = []
}