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
