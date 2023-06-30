---
title: Guarding Against Unexpected Cloud Costs with AWS WAF
date: "2023-06-30T00:00:00.000Z"
description: Block bot-driven DDoS attacks alongside common exploits and malicious traffic using AWS WAF.
---

- Cloud cost anxiety

# Operating services on the cloud has become ubiquitous, personal projects and hobby work included.
# While the cloud does have generous free tiers, we are using someone else's computer, and (generally) pay-per-request.
# Malicious traffic can give you a big cloud bill without necessarily causing you downtime
# Creating a metric for increased traffic can mitigate this, but what if you're asleep?
# Enter WAF alongside a set of cost-effective rules

- Solution: AWS WAF

# Explain the product
# Explain the configuration used in technoblather
  # Note: this config uses 1127 WCUs. ensure not to go above 1500 otherwise price increase as per https://aws.amazon.com/waf/pricing/
  # Note: look at AWS for managed rules that may be applicable for your own application (e.g. wordpress)
  # Note: rate-limiting rule as a guaranteed upper bound on a DDoS' potential impact

# Explain possible next steps
# Note: not a guarantee but a good start - should have alerting on bill cost set up regardless as a failsafe. Can create an automation to take down the project as an automated escape hatch.
