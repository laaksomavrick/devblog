resource "aws_sns_topic" "technoblather_sns_topic_500_error_threshold_exceeded" {
  provider = aws.acm_provider
  name     = "${var.common_tags["Environment"]}-technoblather-500-error-threshold-exceeded"
  delivery_policy = jsonencode({
    "http" : {
      "defaultHealthyRetryPolicy" : {
        "minDelayTarget" : 20,
        "maxDelayTarget" : 20,
        "numRetries" : 3,
        "numMaxDelayRetries" : 0,
        "numNoDelayRetries" : 0,
        "numMinDelayRetries" : 0,
        "backoffFunction" : "linear"
      },
      "disableSubscriptionOverrides" : false,
      "defaultThrottlePolicy" : {
        "maxReceivesPerSecond" : 1
      }
    }
  })
  tags = var.common_tags
}

resource "aws_sns_topic_subscription" "technoblather_sns_topic_500_error_threshold_exceeded_email_subscription" {
  provider  = aws.acm_provider
  count     = length(var.alert_emails)
  topic_arn = aws_sns_topic.technoblather_sns_topic_500_error_threshold_exceeded.arn
  protocol  = "email"
  endpoint  = var.alert_emails[count.index]
}