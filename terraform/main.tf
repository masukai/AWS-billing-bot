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

data "aws_iam_policy_document" "lambda_billing_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_billing_role" {
  name               = "lambda-billing-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_billing_role.json
}

data "aws_iam_policy_document" "lambda_log_policy" {
  statement {
    sid = "CreateLambdaLogGroup"
    actions = [
      "logs:CreateLogGroup"
    ]
    resources = [
      aws_cloudwatch_log_group.lambda_billing_log_group.arn
    ]
  }
  statement {
    sid = "CreateLambdaStream"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.lambda_billing_log_group.arn}:*"
    ]
  }
}

resource "aws_iam_policy" "lambda_log_policy" {
  name        = "lambda-log-policy"
  description = "lambda log policy"
  policy      = data.aws_iam_policy_document.lambda_log_policy.json
}

data "aws_iam_policy_document" "cost_explorer_read_policy" {
  statement {
    sid = "VisualEditor0"
    actions = [
      "ce:DescribeCostCategoryDefinition",
      "ce:ListTagsForResource",
      "ce:GetAnomalySubscriptions",
      "ce:GetAnomalies",
      "ce:GetAnomalyMonitors"
    ]
    resources = [
      "arn:aws:ce::${data.aws_caller_identity.self.account_id}:anomalymonitor/*",
      "arn:aws:ce::${data.aws_caller_identity.self.account_id}:anomalysubscription/*",
      "arn:aws:ce::${data.aws_caller_identity.self.account_id}:costcategory/*"
    ]
  }
  statement {
    sid = "VisualEditor1"
    actions = [
      "ce:GetRightsizingRecommendation",
      "ce:GetCostAndUsage",
      "ce:GetSavingsPlansUtilization",
      "ce:GetReservationPurchaseRecommendation",
      "ce:GetCostForecast",
      "ce:GetPreferences",
      "ce:GetReservationUtilization",
      "ce:GetCostCategories",
      "ce:GetSavingsPlansPurchaseRecommendation",
      "ce:GetDimensionValues",
      "ce:GetSavingsPlansUtilizationDetails",
      "ce:GetCostAndUsageWithResources",
      "ce:DescribeReport",
      "ce:GetReservationCoverage",
      "ce:GetConsoleActionSetEnforced",
      "ce:GetSavingsPlansCoverage",
      "ce:DescribeNotificationSubscription",
      "ce:GetTags",
      "ce:GetUsageForecast"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "cost_explorer_read_policy" {
  name        = "cost-explorer-read-policy"
  description = "cost explorer read policy"
  policy      = data.aws_iam_policy_document.cost_explorer_read_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_billing_policy_attachment" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AWSAccountUsageReportAccess",
    "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess"
  ])
  role       = aws_iam_role.lambda_billing_role.name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "lambda_billing_log_policy_attachment" {
  role       = aws_iam_role.lambda_billing_role.name
  policy_arn = aws_iam_policy.lambda_log_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_billing_cost_policy_attachment" {
  role       = aws_iam_role.lambda_billing_role.name
  policy_arn = aws_iam_policy.cost_explorer_read_policy.arn
}

resource "aws_cloudwatch_log_group" "lambda_billing_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.example_lambda_billing.function_name}"
  retention_in_days = 30
}

resource "aws_cloudwatch_event_rule" "lambda_billing" {
  name                = "example-lambda-billing"
  description         = "example lambda billing"
  schedule_expression = local.cron
  is_enabled          = true
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
