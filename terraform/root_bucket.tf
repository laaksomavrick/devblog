resource "aws_s3_bucket" "root_bucket" {
  bucket = var.bucket_name
  tags   = var.common_tags
}

resource "aws_s3_bucket_policy" "root_blog_policy" {
  bucket = aws_s3_bucket.root_bucket.id
  policy = templatefile("templates/s3-policy.json", { bucket = var.bucket_name })
}

resource "aws_s3_bucket_acl" "root_acl" {
  bucket = aws_s3_bucket.root_bucket.id
  acl    = "public-read"
}

resource "aws_s3_bucket_website_configuration" "root_blog_website_configuration" {
  bucket = aws_s3_bucket.root_bucket.id
  redirect_all_requests_to {
    host_name = var.domain_name
    protocol  = "https"
  }
}