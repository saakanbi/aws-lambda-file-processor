output "bucket_name" {
  value = aws_s3_bucket.upload_bucket.bucket
}

output "lambda_name" {
  value = aws_lambda_function.file_processor.function_name
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.api.api_endpoint
}
