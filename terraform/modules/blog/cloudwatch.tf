resource "aws_cloudwatch_metric_alarm" "blog_broken_alarm" {
  provider            = aws.acm_provider
  alarm_name          = "${var.common_tags["Environment"]}-blog-broken-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  treat_missing_data  = "notBreaching"

  alarm_description = "Monitors whenever average error rate exceeds 1%"
  alarm_actions     = [aws_sns_topic.technoblather_sns_topic_500_error_threshold_exceeded.arn]

  dimensions = {
    DistributionId = aws_cloudfront_distribution.www_s3_distribution.id
    Region         = "Global"
  }

  tags = var.common_tags
}