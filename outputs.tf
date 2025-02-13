# #website endpoint
output "s3_url" {
  value = var.enable_cloudfront ? null :aws_s3_bucket_website_configuration.website[0].website_endpoint
}

output "cloudfront_url" {
  value = var.enable_cloudfront ? aws_cloudfront_distribution.s3_distribution[0].domain_name : null
}