resource "aws_s3_bucket" "site" {
  bucket = "cloud-daisy-website-prod"
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_acm_certificate" "site" {
  provider                  = aws.us_east_1
  domain_name                = "cloud-daisy.com"
  subject_alternative_names  = ["www.cloud-daisy.com"]
  validation_method           = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "site" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for record in aws_acm_certificate.site.domain_validation_options : record.resource_record_name]
}

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "cloud-daisy-website-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                   = "always"
  signing_protocol                   = "sigv4"
}

resource "aws_cloudfront_function" "origin_verify" {
  name    = "cloud-daisy-origin-verify"
  runtime = "cloudfront-js-2.0"
  comment = "Blocks requests that don't carry the Cloudflare secret header"
  publish = true
  code    = <<-EOT
    function handler(event) {
      var request = event.request;
      var secret = request.headers['x-origin-verify'];

      if (!secret || secret.value !== '${var.origin_verify_secret}') {
        return {
          statusCode: 403,
          statusDescription: 'Forbidden'
        };
      }

      return request;
    }
  EOT
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  default_root_object = "index.html"
  aliases             = ["cloud-daisy.com", "www.cloud-daisy.com"]

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-cloud-daisy-website"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    allowed_methods         = ["GET", "HEAD"]
    cached_methods           = ["GET", "HEAD"]
    target_origin_id         = "s3-cloud-daisy-website"
    viewer_protocol_policy   = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.origin_verify.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn       = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method         = "sni-only"
    minimum_protocol_version   = "TLSv1.2_2021"
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.site.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.site.arn
          }
        }
      }
    ]
  })
}
