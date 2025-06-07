provider "aws" {
  region = var.region
}

# 0. Random suffix for unique S3 bucket
resource "random_id" "suffix" {
  byte_length = 4
  keepers = {
    # This value will only change when explicitly modified
    bucket_name = "project-upload-bucket-dev"
  }
}

# 1. S3 Bucket
resource "aws_s3_bucket" "upload_bucket" {
  bucket        = "project-upload-bucket-dev-${random_id.suffix.hex}"
  force_destroy = true

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [tags]
  }
}



# 2. IAM Role for Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name =  "lambda_exec_role_${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# 3. Lambda Function
resource "aws_lambda_function" "file_processor" {
  function_name = "file_processor_${random_id.suffix.hex}"
  filename         = "${path.module}/../lambda_function.zip"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  role             = aws_iam_role.lambda_exec_role.arn
  source_code_hash = filebase64sha256("${path.module}/../lambda_function.zip")
}

# 4. Lambda Permissions

## 4a. Allow S3 to invoke Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.file_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.upload_bucket.arn
}

## 4b. Allow API Gateway to invoke Lambda
resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.file_processor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

# 5. S3 trigger for Lambda
resource "aws_s3_bucket_notification" "trigger_lambda" {
  bucket = aws_s3_bucket.upload_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.file_processor.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# 6. API Gateway Setup

## 6a. Create HTTP API Gateway
resource "aws_apigatewayv2_api" "api" {
  name          = "fileProcessorAPI"
  protocol_type = "HTTP"
}

## 6b. Integration
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.file_processor.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

## 6c. Route
resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /process"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

## 6d. Stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

# 7. CloudWatch Monitoring is defined in monitoring.tf

