terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = { Environment = "dev", ManagedBy = "terraform" }
  }
}

module "github_oidc" {
  source = "../../modules/github-oidc"
}

resource "aws_iam_policy" "ecr_push" {
  name = "GitHubActions-ECR-Push"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/*"
      }
    ]
  })
}

module "github_roles" {
  source            = "../../modules/iam-roles"
  oidc_provider_arn = module.github_oidc.oidc_provider_arn

  repositories = {
    "${var.github_org}/api-gateway" = {
      subject_claims = ["repo:${var.github_org}/api-gateway:*"]
      policy_arns    = [aws_iam_policy.ecr_push.arn]
    }
    # Add more repos here
  }
}

data "aws_caller_identity" "current" {}

variable "aws_region" {
  default = "eu-west-2"
}

variable "github_org" {
  type = string
}

output "role_arns" {
  value = module.github_roles.role_arns
}
