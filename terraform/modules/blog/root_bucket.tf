resource "aws_s3_bucket" "root_bucket" {
  bucket = var.domain_name
  tags   = var.common_tags
}

resource "aws_s3_bucket_policy" "root_blog_policy" {
  bucket = aws_s3_bucket.root_bucket.id
  policy = templatefile("${path.module}/templates/s3-public-policy.json", { bucket = var.domain_name })
}

resource "aws_s3_bucket_acl" "root_acl" {
  bucket = aws_s3_bucket.root_bucket.id
  acl    = "public-read"
}

resource "aws_s3_bucket_website_configuration" "root_blog_website_configuration" {
  bucket = aws_s3_bucket.root_bucket.id
  redirect_all_requests_to {
    host_name = "www.${var.domain_name}"
    protocol  = "https"
  }
}