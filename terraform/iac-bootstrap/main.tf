terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"


  # Store terraform state file in an S3 bucket 
  backend "s3" {
    bucket  = "order-system-terraform-state-storage"
    key     = "bootstrap/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = "us-east-1"
}

# GitHub OIDC Identity Provider
resource "aws_iam_openid_connect_provider" "ocid_provider" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# Configure trust policy
data "aws_iam_policy_document" "oidc" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.ocid_provider.arn]
    }

    condition {
      test     = "StringEquals"
      values   = ["sts.amazonaws.com"]
      variable = "token.actions.githubusercontent.com:aud"
    }

    condition {
      test     = "StringEquals"
      values   = [
        "repo:ZG06@92268833/aws-order-system@1454556221:ref:refs/heads/master",
        "repo:ZG06@92268833/aws-order-system@1454556221:pull_request"
      ]
      variable = "token.actions.githubusercontent.com:sub"
    }
  }
}

# Create IAM role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name               = "github-action-role"
  assume_role_policy = data.aws_iam_policy_document.oidc.json
}

# Least-Privilege permissions policy
resource "aws_iam_policy" "github_actions_deploy" {
  name        = "order-system-github-actions-deploy"
  description = "Least-privilege deployment policy for GitHub Actions CI/CD"
  policy      = file("${path.module}/resources/policy.json")
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "github_actions_attach" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_deploy.arn
}