terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.25.0"
    }
  }
}

provider "aws" {
  profile                  = terraform.workspace
  region                   = "ap-northeast-1"
  shared_credentials_files = ["~/.aws/credentials"]
}

data "aws_caller_identity" "self" {}

data "archive_file" "example_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_function"
  output_path = "${path.module}/lambda_billing.zip"
}

resource "aws_lambda_function" "example_lambda_billing" {
  function_name    = "example-lambda-billing"
  handler          = "main.lambda_handler"
  runtime          = "python3.7" # requestがビルドインのため
  filename         = data.archive_file.example_zip.output_path
  source_code_hash = data.archive_file.example_zip.output_base64sha256
  role             = aws_iam_role.lambda_billing_role.arn
  timeout          = 30

  environment {
    variables = {
      "TEAMS_WEBHOOK_URL" = local.teams_webhook_url[terraform.workspace]
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_billing_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.example_lambda_billing.function_name}"
  retention_in_days = 30
}

resource "aws_cloudwatch_event_rule" "lambda_billing" {
  name                = "example-lambda-billing"
  description         = "example lambda billing"
  schedule_expression = local.cron
}

resource "aws_cloudwatch_event_target" "lambda_billing" {
  rule      = aws_cloudwatch_event_rule.lambda_billing.name
  target_id = aws_cloudwatch_event_rule.lambda_billing.name
  arn       = aws_lambda_function.example_lambda_billing.arn
}

resource "aws_lambda_permission" "lambda_billing" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example_lambda_billing.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_billing.arn
}
