resource "aws_cloudfront_distribution" "www_s3_distribution" {

  origin {
    domain_name              = aws_s3_bucket.www_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.www_s3_origin_access_control.id
    origin_id                = "S3-www.${var.bucket_name}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = ["www.${var.domain_name}"]

  custom_error_response {
    error_caching_min_ttl = 0
    error_code            = 404
    response_code         = 200
    response_page_path    = "/404.html"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-www.${var.bucket_name}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }


    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.www_add_index.arn
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 31536000
    default_ttl            = 31536000
    max_ttl                = 31536000
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert_validation.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.1_2016"
  }

  tags = var.common_tags
}

resource "aws_cloudfront_origin_access_control" "www_s3_origin_access_control" {
  name                              = "www-s3-origin-access-control"
  description                       = ""
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_function" "www_add_index" {
  name    = "www_add_index"
  runtime = "cloudfront-js-1.0"
  comment = "my function"
  publish = true
  code    = file("functions/wwwAddIndex.js")
}

# Cloudfront S3 for redirect to www.
resource "aws_cloudfront_distribution" "root_s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.root_bucket.bucket_regional_domain_name
    origin_id                = "S3-.${var.bucket_name}"
  }

  enabled         = true
  is_ipv6_enabled = true

  aliases = [var.domain_name]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-.${var.bucket_name}"

    forwarded_values {
      query_string = true

      cookies {
        forward = "none"
      }

      headers = ["Origin"]
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert_validation.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.1_2016"
  }

  tags = var.common_tags
}
