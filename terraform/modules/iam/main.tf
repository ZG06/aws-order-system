# Allow Lambda to assume this role
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Execution role
resource "aws_iam_role" "lambda_role" {
  name               = "${var.project_name}-lambda-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Least-Privilege Permissions policy document
data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    actions   = [
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:PutItem"
    ]
    resources = [var.dynamodb_table_arn]
    effect    = "Allow"
  }

  statement {
    actions   = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
    effect    = "Allow"
  }
}

# Create AWS JSON policy from the document
resource "aws_iam_policy" "lambda-policy" {
  name        = "${var.project_name}-lambda-policy-${var.environment}"
  description = "Least privilege execution policy for ${var.project_name} order handler"
  policy      = data.aws_iam_policy_document.lambda_permissions.json
}

# Attach the policy document to the role
resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda-policy.arn
}