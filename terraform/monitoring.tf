resource "aws_cloudwatch_dashboard" "lambda_dashboard" {
  dashboard_name = "lambda-dashboard-${var.env}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric",
        x = 0,
        y = 0,
        width = 12,
        height = 6,
        properties = {
          title = "Lambda Invocations, Errors, Duration",
          metrics = [
            [ "AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.file_processor.function_name ],
            [ ".", "Errors", ".", "." ],
            [ ".", "Duration", ".", "." ],
          ],
          period = 300,
          stat = "Sum",
          region = var.region,
          view = "timeSeries",
          stacked = false
        }
      },
      {
        type = "metric",
        x = 0,
        y = 7,
        width = 12,
        height = 6,
        properties = {
          title = "Throttles and Concurrent Executions",
          metrics = [
            [ "AWS/Lambda", "Throttles", "FunctionName", aws_lambda_function.file_processor.function_name ],
            [ ".", "ConcurrentExecutions", ".", "." ]
          ],
          view = "timeSeries",
          stacked = false,
          period = 300,
          stat = "Sum",
          region = var.region
        }
      },
      {
        type = "metric",
        x = 0,
        y = 14,
        width = 12,
        height = 6,
        properties = {
          title = "Memory Usage",
          metrics = [
            [ "AWS/Lambda", "MaxMemoryUsed", "FunctionName", aws_lambda_function.file_processor.function_name ],
            [ ".", "MemorySize", ".", "." ]
          ],
          view = "timeSeries",
          stacked = false,
          period = 300,
          stat = "Maximum",
          region = var.region
        }
      }
    ]
  })
}
# Monitoring and Alerts for Lambda Function
# This section sets up monitoring and alerting for the Lambda function using CloudWatch and SNS.

resource "aws_sns_topic" "alert_topic" {
  name = "lambda-alerts-${var.env}"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alert_topic.arn
  protocol  = "email"
  endpoint  = "woakanbi@gmail.com"  # 🔁 Replace with your actual email
}

resource "aws_cloudwatch_metric_alarm" "lambda_error_alarm" {
  alarm_name          = "LambdaErrorAlarm-${var.env}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Triggers when Lambda errors ≥ 1"
  dimensions = {
    FunctionName = aws_lambda_function.file_processor.function_name
  }
  alarm_actions = [aws_sns_topic.alert_topic.arn]
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttle_alarm" {
  alarm_name          = "LambdaThrottleAlarm-${var.env}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Triggers when Lambda is throttled"
  dimensions = {
    FunctionName = aws_lambda_function.file_processor.function_name
  }
  alarm_actions = [aws_sns_topic.alert_topic.arn]
}
resource "aws_cloudwatch_metric_alarm" "lambda_high_duration_alarm" {
  alarm_name          = "LambdaHighDurationAlarm-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 1000  # in milliseconds (1 second)
  alarm_description   = "Triggers when Lambda average duration exceeds 1 second"
  dimensions = {
    FunctionName = aws_lambda_function.file_processor.function_name
  }
  alarm_actions = [aws_sns_topic.alert_topic.arn]
}
resource "aws_cloudwatch_metric_alarm" "lambda_high_memory_alarm" {
  alarm_name          = "LambdaHighMemoryAlarm-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "MaxMemoryUsed"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Maximum"
  threshold           = 80  # in percentage of allocated memory
  alarm_description   = "Triggers when Lambda memory usage exceeds 80% of allocated memory"
  dimensions = {
    FunctionName = aws_lambda_function.file_processor.function_name
  }
  alarm_actions = [aws_sns_topic.alert_topic.arn]
}