variable "aws_profile" {
  type        = string
  description = "The name of the aws profile to use."
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