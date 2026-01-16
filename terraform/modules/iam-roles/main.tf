terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  for_each = var.repositories

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = each.value.subject_claims
    }
  }
}

resource "aws_iam_role" "github_actions" {
  for_each           = var.repositories
  name               = "GitHubActions-${replace(each.key, "/", "-")}"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role[each.key].json
  tags               = merge(var.tags, { Repository = each.key })
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  for_each   = { for pair in local.role_policy_pairs : "${pair.repo}-${pair.policy}" => pair }
  role       = aws_iam_role.github_actions[each.value.repo].name
  policy_arn = each.value.policy
}

locals {
  role_policy_pairs = flatten([
    for repo, config in var.repositories : [
      for policy in config.policy_arns : { repo = repo, policy = policy }
    ]
  ])
}

variable "oidc_provider_arn" {
  type = string
}

variable "repositories" {
  type = map(object({
    subject_claims = list(string)
    policy_arns    = list(string)
  }))
}

variable "tags" {
  type    = map(string)
  default = { ManagedBy = "terraform" }
}

output "role_arns" {
  value = { for repo, role in aws_iam_role.github_actions : repo => role.arn }
}
