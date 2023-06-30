---
title: Guarding Against Unexpected Cloud Costs with AWS WAF
date: "2023-06-30T00:00:00.000Z"
description: Block bot-driven DDoS attacks alongside common exploits and malicious traffic using AWS WAF.
---
## We all use the cloud

It's uncontentious that operating software in the cloud [has many benefits](https://docs.aws.amazon.com/whitepapers/latest/aws-overview/six-advantages-of-cloud-computing.html).
How often have you seriously discussed with colleagues the merits of operating a new service on-prem?
Or opting to roll-your-own for whatever new-shiny-thing you want to use in your production workloads versus delegating that responsibility (and all the corresponding risk) to a managed service?
Nobody likes waking up at 2am because their server rack has caught fire - or because the night crew tripped over the power cable.


And so, operating software in the cloud has become ubiquitous.
Accordingly, our personal projects and hobby work have also changed from operating on toaster ovens beneath our desks to Amazuroogle-branded GUI fascia in your browser.

However, this shift has introduced new anxieties for concern.
While the cloud does have generous free tiers, we are using someone else's computer, and (generally) pay-per-request.
And the internet - as wonderful as it is - is anarchical and sometimes actively hostile.
Pay-per-request billing ups the ante on malicious traffic from "taking your service down" to "having a very large credit card bill".

Particular to hobbyists - arguing with support about the $5000 cloud charge I didn't know I could have is not a situation I ever want to be in.
You _can_ set an alert to notify you of these events - but what if you're asleep? 
Or if the damage has been done within a five minute interval?

Given I operate technoblather on AWS, I wanted to see if there was a way I could kibosh this nightmare scenario and consequently sleep soundly.

## There's a service for that

Surprise, surprise.
There [is a service for that](https://aws.amazon.com/waf/).
Web Application Firewall allows operators to define one or more rules to allow or block internet traffic to resources being operated.
AWS offers a [myriad of managed rules for common use cases](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-list.html) and allows for operators to define custom rules to meet their own requirements. 
Technoblather uses this service to block malicious traffic with a rate-limit fallback to provide an upper bound on the damage that can potentially be done.
Specifically, observe the following terraform declaration:

```terraform
# terraform/modules/blog/waf.tf

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
```

Technoblather uses a number of managed rules:
* `AWSManagedRulesAdminProtectionRuleSet`
* `AWSManagedRulesAmazonIpReputationList`
* `AWSManagedRulesAnonymousIpList`
* `AWSManagedRulesCommonRuleSet`
* `AWSManagedRulesKnownBadInputsRuleSet`
* `AWSManagedRulesBotControlRuleSet`

alongside a fallback rate-based-rule, limiting all traffic to a maximum of 100 requests per 5 minutes, or 0.16 rps.
This configuration uses 1127 out of [1500 allowed WCUs for the free tier](https://aws.amazon.com/waf/pricing/), meaning I only pay a flat fee for AWS WAF.
Moreover, it provides a blanket level of security that would take me days individually to set up and adjust alongside ongoing updates and maintenance.

This doesn't guarantee I won't get an expensive cloud bill one day, but like car theft, it means it's probably easier to move onto the next target.
Independent of having AWS WAF set up, setting up an alert (and potentially a killswitch automation) on cloud billing is recommended for hobby projects - personal applications don't need 100% uptime.
Hopefully you can integrate WAF with your hobby projects (or production workloads) to alleviate the same concerns I had.
Until next time - [my dog Ruby](ruby.png) will be waking me up at 6am regardless, but my sleep prior will be a little more sound.
