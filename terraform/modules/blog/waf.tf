resource "aws_wafv2_web_acl" "cf_web_acl" {
  count = var.common_tags["Environment"] == "production" ? 1 : 0
  # Since this costs $$$, only enable firewall acl in prod
  name        = "technoblather-cf-web-acl"
  description = "Web acl for technoblather cloudfront distribution"
  scope       = "CLOUDFRONT"
  provider    = aws.acm_provider

  default_action {
    allow {}
  }

  rule {
    name     = "admin-protection-managed-rule"
    priority = 100

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAdminProtectionRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "technoblather-cf-web-acl-admin-protection-rule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "ip-reputation-managed-rule"
    priority = 200

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "technoblather-cf-web-acl-ip-reputation-rule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "anonymous-ip-managed-rule"
    priority = 300

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "technoblather-cf-web-acl-anonymous-ip-rule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "common-managed-rule"
    priority = 400

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "technoblather-cf-web-acl-common-rule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "known-bad-inputs-rule"
    priority = 500

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "technoblather-cf-web-acl-known-bad-inputs-rule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "bots-rule"
    priority = 600

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesBotControlRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "technoblather-cf-web-acl-bots-rule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "rate-based-rule"
    priority = 1000

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
      cloudwatch_metrics_enabled = false
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