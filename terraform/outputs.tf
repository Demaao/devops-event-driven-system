output "api_base_url" {
  value = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${var.region}.amazonaws.com/prod"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.ingestion_bucket.bucket
}
