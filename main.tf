#create bucket
resource "aws_s3_bucket" "react_bucket" {
  bucket = var.bucket_name
}

#bucket ownership control
resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.react_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

#bucket public access false
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.react_bucket.id

  block_public_acls       = var.bucket_permission
  block_public_policy     = var.bucket_permission
  ignore_public_acls      = var.bucket_permission
  restrict_public_buckets = var.bucket_permission
}

# bucket ACL public-read
resource "aws_s3_bucket_acl" "example" {
  count  = var.enable_cloudfront ? 0 : 1 
  depends_on = [
    aws_s3_bucket_ownership_controls.example,
    aws_s3_bucket_public_access_block.example,
  ]

  bucket = aws_s3_bucket.react_bucket.id
  acl    = "public-read"
}

#enable bucket versioning
resource "aws_s3_bucket_versioning" "versioning_example" {
  count  = var.enable_cloudfront ? 1 : 0
  bucket = aws_s3_bucket.react_bucket.id
  versioning_configuration {
    status = var.versioning_status
  }
}

#upload files using s3 object acl and content type as well 
#for react builds
resource "aws_s3_object" "build_object" {
  for_each = fileset(var.build_path, "**")
  bucket   = aws_s3_bucket.react_bucket.id
  key      = each.value
  source   = "${var.build_path}/${each.value}"
  content_type = lookup({
    "html" = "text/html",
    "css"  = "text/css",
    "js"   = "application/javascript",
  }, split(".", each.value)[length(split(".", each.value)) - 1], "text/plain")
}

#website configuration for index.html and error.html depends on bucket acl
resource "aws_s3_bucket_website_configuration" "website" {
  count = var.enable_cloudfront ? 0 : 1
  bucket = aws_s3_bucket.react_bucket.id
  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

  depends_on = [aws_s3_bucket_acl.example]
}

#add bucket policy
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid       = "GetObjectAccess"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.react_bucket.arn}/*"]
    principals {
      type        = var.enable_cloudfront ? "Service" : "*"
      identifiers = var.enable_cloudfront ? ["cloudfront.amazonaws.com"] : ["*"]
    }

    # Dynamic block for the condition
    dynamic "condition" {
      for_each = var.enable_cloudfront ? [1] : []  # Creates the condition block only if enabled
      content {
        test     = "ArnEquals"
        variable = "AWS:SourceArn"
        # values   = ["arn:aws:cloudfront::${aws_cloudfront_distribution.s3_distribution[0].id}"]
        values   = ["arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.s3_distribution[0].id}"]
      }
    }
  }
}
# Data source to get the current AWS account ID
data "aws_caller_identity" "current" {}

# Attach the Bucket Policy to the S3 Bucket
resource "aws_s3_bucket_policy" "react_static_site_policy" {
  bucket = aws_s3_bucket.react_bucket.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

#create OAC for cdn
resource "aws_cloudfront_origin_access_control" "example" {
  count = var.enable_cloudfront ? 1 : 0
  name                              = "example"
  description                       = "Example Policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

locals {
  s3_origin_id   = "${var.bucket_name}-origin"
  # s3_domain_name = aws_s3_bucket_website_configuration.website[0].website_endpoint
}

# Cache Policy: Managed-CachingOptimized
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

#create cloudfront distribution
resource "aws_cloudfront_distribution" "s3_distribution" {
  count = var.enable_cloudfront ? 1 : 0
  origin {
    domain_name = "${aws_s3_bucket.react_bucket.bucket}.s3.${var.aws_region}.amazonaws.com"
    origin_access_control_id = aws_cloudfront_origin_access_control.example[0].id
    origin_id   = local.s3_origin_id
    # custom_origin_config {
    #   http_port              = 80
    #   https_port             = 443
    #   origin_protocol_policy = "http-only"
    #   origin_ssl_protocols   = ["TLSv1"]
      
    # }
  }
  
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "cdn for s3 static website"
  default_root_object = "index.html"
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.s3_origin_id
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
    viewer_protocol_policy = "allow-all"
  }
  custom_error_response {
    error_code = 403
    response_code = 200
    response_page_path = "/error.html"
    error_caching_min_ttl = 20
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  price_class = "PriceClass_200"
  viewer_certificate {
    cloudfront_default_certificate = true
  }

}
