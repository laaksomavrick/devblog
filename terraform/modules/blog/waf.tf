resource "aws_wafv2_web_acl" "cf_web_acl" {
  count       = var.common_tags["Environment"] == "production" ? 1 : 0 # Since this costs $$$, only enable firewall acl in prod
  name        = "technoblather-cf-web-acl"
  description = "Web acl for technoblather cloudfront distribution"
  scope       = "CLOUDFRONT"
  provider    = aws.acm_provider

  default_action {
    allow {}
  }

  rule {
    name     = "rate-based-rule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 100 # 100 request every 5m or 0.16rps
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "technoblather-cf-web-acl-rate-based-rule"
      sampled_requests_enabled   = true
    }
  }

  tags = var.common_tags

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "technoblather-cf-web-acl"
    sampled_requests_enabled   = false
  }
}