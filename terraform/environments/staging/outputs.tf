output "aws_route53_zone_name_servers" {
  description = "Name servers for route53 hosted zone"
  value       = module.technoblather-staging.aws_route53_zone_name_servers
}