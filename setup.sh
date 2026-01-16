#!/bin/bash
#
# Jenkins to GitHub Actions Migration Repository Generator
#
# This script creates the complete migration toolkit repository structure.
#
# Usage:
#   chmod +x generate-repo.sh
#   ./generate-repo.sh [target-directory]
#
# Suggested repo name: jenkins-to-gha-migration
#

set -euo pipefail

TARGET_DIR="${1:-jenkins-to-gha-migration}"

echo "🚀 Creating Jenkins to GitHub Actions migration repository in: $TARGET_DIR"

# Create directory structure
mkdir -p "$TARGET_DIR"/{docs,terraform/{modules/{github-oidc,iam-roles},environments/{dev,prod}},scripts,workflows/reusable,actions/{setup-tools,notify-slack},examples}

cd "$TARGET_DIR"

# ============================================================================
# README.md
# ============================================================================
cat > README.md << 'EOF'
# Jenkins to GitHub Actions Migration

Migration toolkit for transitioning ~30 repositories from Jenkins to GitHub Actions with zero downtime.

## Quick Start

```bash
# 1. Run the audit to understand your current Jenkins state
./scripts/jenkins-audit.sh

# 2. Use GitHub Actions Importer for automated conversion
gh actions-importer audit jenkins --output-dir audit-results

# 3. Migrate secrets
./scripts/migrate-secrets.sh

# 4. Run parallel pipelines (Jenkins + GHA) during transition
```

## Repository Structure

```
.
├── README.md                    # This file
├── docs/
│   ├── MIGRATION_GUIDE.md       # Detailed migration playbook
│   ├── PARALLEL_RUNNING.md      # Running Jenkins + GHA side-by-side
│   ├── ROLLBACK_PLAN.md         # If things go wrong
│   ├── SECRETS_MIGRATION.md     # Credentials handling
│   └── TROUBLESHOOTING.md       # Common issues and fixes
├── terraform/
│   ├── modules/
│   │   ├── github-oidc/         # AWS OIDC provider for keyless auth
│   │   └── iam-roles/           # Per-repo IAM roles
│   └── environments/
│       ├── dev/                 # Dev account OIDC setup
│       └── prod/                # Prod account OIDC setup
├── scripts/
│   ├── jenkins-audit.sh         # Audit existing Jenkins jobs
│   ├── migrate-secrets.sh       # Migrate credentials to GHA
│   ├── validate-migration.sh    # Compare Jenkins vs GHA outputs
│   └── cutover.sh               # Final switch script
├── workflows/
│   └── reusable/                # Centralised reusable workflows
└── actions/
    ├── setup-tools/             # Composite action: common tooling
    └── notify-slack/            # Composite action: Slack notifications
```

## Migration Phases

| Phase | Duration | Activities |
|-------|----------|------------|
| 1. Discovery | 1 week | Audit Jenkins, document jobs, identify dependencies |
| 2. Setup | 1 week | OIDC, secrets, runners, centralised workflows |
| 3. Migrate | 4–6 weeks | Convert pipelines (batch of 5–6 repos/week) |
| 4. Parallel | 2 weeks | Run both systems, validate parity |
| 5. Cutover | 1 week | Disable Jenkins triggers, archive |

## Prerequisites

```bash
# GitHub CLI with Actions Importer extension
gh extension install github/gh-actions-importer
gh actions-importer update

# Terraform for OIDC setup
terraform -v  # >= 1.5

# Jenkins API access for audit
export JENKINS_URL="https://jenkins.example.com"
export JENKINS_USER="your-user"
export JENKINS_TOKEN="your-api-token"
```

## Next Steps

1. Read [docs/MIGRATION_GUIDE.md](docs/MIGRATION_GUIDE.md) for the full playbook
2. Run the audit: `./scripts/jenkins-audit.sh`
3. Set up OIDC: `cd terraform/environments/dev && terraform apply`
4. Start with low-risk repos first
EOF

# ============================================================================
# docs/MIGRATION_GUIDE.md
# ============================================================================
cat > docs/MIGRATION_GUIDE.md << 'EOF'
# Migration Guide: Jenkins to GitHub Actions

Complete playbook for migrating ~30 repositories from Jenkins to GitHub Actions.

## Table of Contents

1. [Pre-Migration Checklist](#pre-migration-checklist)
2. [Phase 1: Discovery and Audit](#phase-1-discovery-and-audit)
3. [Phase 2: Infrastructure Setup](#phase-2-infrastructure-setup)
4. [Phase 3: Pipeline Migration](#phase-3-pipeline-migration)
5. [Phase 4: Parallel Running](#phase-4-parallel-running)
6. [Phase 5: Cutover](#phase-5-cutover)

---

## Pre-Migration Checklist

### Access Requirements

- [ ] GitHub organisation admin access
- [ ] Jenkins admin access (or API token with read permissions)
- [ ] AWS IAM permissions to create OIDC providers and roles
- [ ] Access to secret management system (Vault, AWS Secrets Manager, etc.)

### GitHub Actions Importer Setup

```bash
gh extension install github/gh-actions-importer
gh actions-importer configure
```

---

## Phase 1: Discovery and Audit

### 1.1 Jenkins Job Inventory

```bash
# Full audit with GitHub Actions Importer
gh actions-importer audit jenkins \
  --output-dir ./audit-results \
  --jenkins-instance-url $JENKINS_URL

# Or use the custom audit script
./scripts/jenkins-audit.sh
```

### 1.2 Categorise Jobs

| Repo | Job Type | Complexity | Dependencies | Priority | Owner |
|------|----------|------------|--------------|----------|-------|
| api-gateway | Declarative | Low | Docker, AWS | P1 | Team A |
| ml-pipeline | Scripted | High | GPU, S3 | P3 | Team B |

**Complexity scoring:**
- **Low**: Declarative pipeline, standard plugins, no custom libs
- **Medium**: Some custom scripts, multiple environments
- **High**: Scripted pipeline, shared libraries, custom plugins

---

## Phase 2: Infrastructure Setup

### 2.1 GitHub OIDC for AWS

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### 2.2 GitHub Secrets Structure

| Level | Use Case | Example |
|-------|----------|---------|
| Organisation | Shared across all repos | `SLACK_WEBHOOK`, `SONAR_TOKEN` |
| Repository | Repo-specific | `AWS_ROLE_ARN`, `DATABASE_URL` |
| Environment | Per-environment | `PROD_API_KEY`, `STAGING_DB_URL` |

```bash
# Set organisation secret
gh secret set SLACK_WEBHOOK --org your-org --visibility all

# Set repository secret
gh secret set AWS_ROLE_ARN --repo your-org/your-repo
```

---

## Phase 3: Pipeline Migration

### 3.1 Migration Order

**Batch 1 (Week 1–2):** Low complexity, non-critical
**Batch 2 (Week 3–4):** Medium complexity, staging environments
**Batch 3 (Week 5–6):** Production deployments

### 3.2 Per-Repo Migration Steps

```bash
REPO="your-org/your-repo"

# 1. Dry-run conversion
gh actions-importer dry-run jenkins \
  --source-url "$JENKINS_URL/job/your-job" \
  --output-dir "./migrations/$REPO"

# 2. Review and adjust generated workflow

# 3. Create PR with new workflows
gh actions-importer migrate jenkins \
  --source-url "$JENKINS_URL/job/your-job" \
  --target-url "https://github.com/$REPO" \
  --output-dir "./migrations/$REPO"
```

### 3.3 Common Mappings

```yaml
# Jenkins → GitHub Actions
env.BUILD_NUMBER → ${{ github.run_number }}
env.GIT_COMMIT   → ${{ github.sha }}
env.BRANCH_NAME  → ${{ github.ref_name }}
```

---

## Phase 4: Parallel Running

Run both systems for 2+ weeks before cutover. See [PARALLEL_RUNNING.md](PARALLEL_RUNNING.md).

---

## Phase 5: Cutover

```bash
# 1. Disable Jenkins webhooks
./scripts/cutover.sh disable-jenkins-triggers

# 2. Verify GitHub Actions triggers active
./scripts/cutover.sh verify-gha-triggers

# 3. Archive Jenkins jobs (don't delete yet)
./scripts/cutover.sh archive-jenkins-jobs
```
EOF

# ============================================================================
# docs/PARALLEL_RUNNING.md
# ============================================================================
cat > docs/PARALLEL_RUNNING.md << 'EOF'
# Parallel Running: Jenkins + GitHub Actions

Running both CI systems simultaneously during migration.

## Architecture

```
┌──────────────┐     push/PR      ┌──────────────────┐
│   GitHub     │─────────────────▶│  GitHub Actions  │
│   Webhook    │                  │  (new workflows) │
└──────────────┘                  └──────────────────┘
       │
       ▼
┌──────────────┐                  ┌──────────────────┐
│   Jenkins    │─────────────────▶│  Jenkins Jobs    │
│   Webhook    │                  │  (existing)      │
└──────────────┘                  └──────────────────┘
```

## Validation Script

```bash
./scripts/validate-migration.sh \
  --jenkins-build 1234 \
  --gha-run 5678 \
  --repo your-org/your-repo
```

## Success Criteria

| Metric | Target |
|--------|--------|
| Build success rate | >= 99% |
| Test parity | 100% |
| Artifact checksum match | 100% |
| Build time variance | < 20% |
EOF

# ============================================================================
# docs/ROLLBACK_PLAN.md
# ============================================================================
cat > docs/ROLLBACK_PLAN.md << 'EOF'
# Rollback Plan

## Rollback Triggers

- Production deployments fail repeatedly (>2 consecutive)
- Critical security vulnerability in GitHub Actions
- Extended GitHub Actions outage (>4 hours)

## Per-Repo Rollback

```bash
REPO="your-org/problem-repo"

# 1. Disable GitHub Actions workflows
gh workflow disable build.yml --repo $REPO

# 2. Re-enable Jenkins webhook
./scripts/cutover.sh enable-jenkins-trigger --repo $REPO

# 3. Verify Jenkins build triggers
curl -X POST "$JENKINS_URL/job/$REPO/build" \
  -u "$JENKINS_USER:$JENKINS_TOKEN"
```

## Full Rollback

```bash
./scripts/cutover.sh rollback --all
```
EOF

# ============================================================================
# docs/SECRETS_MIGRATION.md
# ============================================================================
cat > docs/SECRETS_MIGRATION.md << 'EOF'
# Secrets Migration Guide

## Credential Types Mapping

### Secret Text

```groovy
// Jenkins
withCredentials([string(credentialsId: 'api-key', variable: 'API_KEY')]) {
    sh 'curl -H "Authorization: Bearer $API_KEY" ...'
}
```

```yaml
# GitHub Actions
- name: Call API
  env:
    API_KEY: ${{ secrets.API_KEY }}
  run: curl -H "Authorization: Bearer $API_KEY" ...
```

### SSH Keys

```yaml
# GitHub Actions
- name: Setup SSH
  run: |
    mkdir -p ~/.ssh
    echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/id_rsa
    chmod 600 ~/.ssh/id_rsa
```

## Using OIDC (Recommended)

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - name: Configure AWS credentials
    uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
      aws-region: eu-west-2
```
EOF

# ============================================================================
# docs/TROUBLESHOOTING.md
# ============================================================================
cat > docs/TROUBLESHOOTING.md << 'EOF'
# Troubleshooting Guide

## Diagnostic Commands

```bash
# Check workflow status
gh run list --repo your-org/your-repo --limit 5

# View failed logs
gh run view <run-id> --repo your-org/your-repo --log-failed
```

## Common Issues

### OIDC Authentication Failures

**Symptom**: `Error: Not authorized to perform sts:AssumeRoleWithWebIdentity`

**Fix**: Check IAM trust policy matches repo path exactly:
```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:your-org/your-repo:*"
}
```

### Secrets Not Available

**Fix**: Verify secret name (case-sensitive) and scope (org/repo/environment).

### Docker Build Fails

**Fix**: Enable BuildKit caching:
```yaml
- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

### Tests Pass in Jenkins, Fail in GHA

**Fix**: Match runtime versions exactly:
```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '18.19.0'  # Exact version from Jenkins
```
EOF

# ============================================================================
# terraform/modules/github-oidc/main.tf
# ============================================================================
cat > terraform/modules/github-oidc/main.tf << 'EOF'
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  github_thumbprints = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = local.github_thumbprints
  tags            = var.tags
}

variable "tags" {
  type    = map(string)
  default = { ManagedBy = "terraform" }
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}
EOF

# ============================================================================
# terraform/modules/iam-roles/main.tf
# ============================================================================
cat > terraform/modules/iam-roles/main.tf << 'EOF'
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
EOF

# ============================================================================
# terraform/environments/dev/main.tf
# ============================================================================
cat > terraform/environments/dev/main.tf << 'EOF'
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
EOF

cat > terraform/environments/dev/terraform.tfvars.example << 'EOF'
aws_region = "eu-west-2"
github_org = "your-org"
EOF

# ============================================================================
# scripts/jenkins-audit.sh
# ============================================================================
cat > scripts/jenkins-audit.sh << 'EOF'
#!/bin/bash
# Jenkins Audit Script
# Exports Jenkins job information for migration planning.

set -euo pipefail

: "${JENKINS_URL:?Set JENKINS_URL}"
: "${JENKINS_USER:?Set JENKINS_USER}"
: "${JENKINS_TOKEN:?Set JENKINS_TOKEN}"

OUTPUT_DIR="${1:-jenkins-audit-$(date +%Y%m%d)}"
mkdir -p "$OUTPUT_DIR"

echo "📊 Auditing Jenkins at $JENKINS_URL"

# Get all jobs
echo "Fetching job list..."
curl -s -u "$JENKINS_USER:$JENKINS_TOKEN" \
  "$JENKINS_URL/api/json?tree=jobs[name,url,color]" | \
  jq -r '.jobs[] | [.name, .url, .color] | @csv' > "$OUTPUT_DIR/jobs.csv"

echo "name,url,status" | cat - "$OUTPUT_DIR/jobs.csv" > "$OUTPUT_DIR/jobs_header.csv"
mv "$OUTPUT_DIR/jobs_header.csv" "$OUTPUT_DIR/jobs.csv"

JOB_COUNT=$(wc -l < "$OUTPUT_DIR/jobs.csv")
echo "Found $((JOB_COUNT - 1)) jobs"

# Get build history for each job
echo "Fetching build history..."
while IFS=, read -r name url status; do
  [[ "$name" == "name" ]] && continue
  name=$(echo "$name" | tr -d '"')
  
  curl -s -u "$JENKINS_USER:$JENKINS_TOKEN" \
    "$JENKINS_URL/job/$name/api/json?tree=builds[number,result,duration,timestamp]" 2>/dev/null | \
    jq -r --arg job "$name" '.builds[]? | [$job, .number, .result, .duration, .timestamp] | @csv' \
    >> "$OUTPUT_DIR/builds.csv"
done < "$OUTPUT_DIR/jobs.csv"

echo "job,build_number,result,duration_ms,timestamp" | cat - "$OUTPUT_DIR/builds.csv" > "$OUTPUT_DIR/builds_header.csv"
mv "$OUTPUT_DIR/builds_header.csv" "$OUTPUT_DIR/builds.csv"

# Generate summary
echo "Generating summary..."
cat > "$OUTPUT_DIR/summary.md" << SUMMARY
# Jenkins Audit Summary

**Date**: $(date)
**Jenkins URL**: $JENKINS_URL

## Job Count

Total jobs: $((JOB_COUNT - 1))

## Jobs by Status

$(cat "$OUTPUT_DIR/jobs.csv" | tail -n +2 | cut -d',' -f3 | sort | uniq -c | sort -rn)

## Recent Build Statistics

$(cat "$OUTPUT_DIR/builds.csv" | tail -n +2 | cut -d',' -f3 | sort | uniq -c | sort -rn)

## Next Steps

1. Run GitHub Actions Importer: \`gh actions-importer audit jenkins --output-dir audit-results\`
2. Review generated workflows
3. Prioritise repos for migration
SUMMARY

echo "✅ Audit complete. Results in $OUTPUT_DIR/"
echo "   - jobs.csv: List of all jobs"
echo "   - builds.csv: Build history"
echo "   - summary.md: Summary report"
EOF
chmod +x scripts/jenkins-audit.sh

# ============================================================================
# scripts/migrate-secrets.sh
# ============================================================================
cat > scripts/migrate-secrets.sh << 'EOF'
#!/bin/bash
# Migrate secrets from Jenkins to GitHub Actions

set -euo pipefail

REPO="${1:?Usage: $0 <repo> [credentials.csv]}"
CREDS_FILE="${2:-credentials.csv}"

if [[ ! -f "$CREDS_FILE" ]]; then
  echo "Creating template credentials file: $CREDS_FILE"
  echo "jenkins_id,type,github_name" > "$CREDS_FILE"
  echo "# Add your credentials below" >> "$CREDS_FILE"
  echo "# Types: string, file" >> "$CREDS_FILE"
  echo "# Example: api-key,string,API_KEY" >> "$CREDS_FILE"
  exit 0
fi

echo "🔐 Migrating secrets to $REPO"

while IFS=, read -r jenkins_id cred_type github_name; do
  [[ "$jenkins_id" =~ ^#.*$ || "$jenkins_id" == "jenkins_id" ]] && continue
  
  echo "Migrating: $jenkins_id → $github_name"
  read -sp "Enter value for $jenkins_id: " cred_value
  echo
  
  case "$cred_type" in
    string)
      echo "$cred_value" | gh secret set "$github_name" --repo "$REPO"
      ;;
    file)
      echo "$cred_value" | base64 -w0 | gh secret set "${github_name}_B64" --repo "$REPO"
      ;;
    *)
      echo "⚠️  Unknown type: $cred_type, skipping"
      continue
      ;;
  esac
  
  echo "✅ Set $github_name"
done < "$CREDS_FILE"

echo "✅ Secret migration complete"
EOF
chmod +x scripts/migrate-secrets.sh

# ============================================================================
# scripts/validate-migration.sh
# ============================================================================
cat > scripts/validate-migration.sh << 'EOF'
#!/bin/bash
# Compare Jenkins and GitHub Actions build outputs

set -euo pipefail

usage() {
  echo "Usage: $0 --jenkins-build <num> --gha-run <id> --repo <org/repo>"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --jenkins-build) JENKINS_BUILD="$2"; shift 2 ;;
    --gha-run) GHA_RUN="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    *) usage ;;
  esac
done

: "${JENKINS_BUILD:?}" "${GHA_RUN:?}" "${REPO:?}"
: "${JENKINS_URL:?Set JENKINS_URL}"
: "${JENKINS_USER:?Set JENKINS_USER}"
: "${JENKINS_TOKEN:?Set JENKINS_TOKEN}"

WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

echo "📊 Comparing Jenkins #$JENKINS_BUILD vs GHA #$GHA_RUN for $REPO"

# Download Jenkins artifacts
echo "Downloading Jenkins artifacts..."
JOB_NAME=$(echo "$REPO" | tr '/' '-')
curl -s -u "$JENKINS_USER:$JENKINS_TOKEN" \
  "$JENKINS_URL/job/$JOB_NAME/$JENKINS_BUILD/artifact/*zip*/archive.zip" \
  -o "$WORK_DIR/jenkins.zip" 2>/dev/null || echo "No Jenkins artifacts"

# Download GHA artifacts
echo "Downloading GitHub Actions artifacts..."
gh run download "$GHA_RUN" --repo "$REPO" -D "$WORK_DIR/gha" 2>/dev/null || echo "No GHA artifacts"

# Compare
echo ""
echo "=== Comparison Results ==="

if [[ -f "$WORK_DIR/jenkins.zip" ]]; then
  unzip -q "$WORK_DIR/jenkins.zip" -d "$WORK_DIR/jenkins"
  JENKINS_FILES=$(find "$WORK_DIR/jenkins" -type f | wc -l)
else
  JENKINS_FILES=0
fi

GHA_FILES=$(find "$WORK_DIR/gha" -type f 2>/dev/null | wc -l || echo 0)

echo "Jenkins artifacts: $JENKINS_FILES files"
echo "GHA artifacts: $GHA_FILES files"

if [[ "$JENKINS_FILES" -eq "$GHA_FILES" ]]; then
  echo "✅ File count matches"
else
  echo "⚠️  File count mismatch"
fi
EOF
chmod +x scripts/validate-migration.sh

# ============================================================================
# scripts/cutover.sh
# ============================================================================
cat > scripts/cutover.sh << 'EOF'
#!/bin/bash
# Cutover script for Jenkins to GitHub Actions migration

set -euo pipefail

CMD="${1:-help}"
shift || true

case "$CMD" in
  disable-jenkins-triggers)
    echo "🔧 Disabling Jenkins webhooks..."
    echo "Manual step: Remove GitHub webhook from Jenkins or disable job triggers"
    echo "Jenkins URL: $JENKINS_URL"
    ;;
    
  enable-jenkins-triggers)
    REPO="${1:?Specify --repo}"
    echo "🔧 Re-enabling Jenkins for $REPO"
    echo "Manual step: Re-add GitHub webhook to Jenkins"
    ;;
    
  verify-gha-triggers)
    echo "✅ Verifying GitHub Actions triggers..."
    gh workflow list --repo "${1:-}" 2>/dev/null || echo "Specify repo with --repo"
    ;;
    
  archive-jenkins-jobs)
    echo "📦 Archiving Jenkins jobs..."
    echo "Manual step: Disable jobs in Jenkins UI or export configs"
    ;;
    
  rollback)
    if [[ "${1:-}" == "--all" ]]; then
      echo "🔄 Full rollback initiated"
      echo "1. Re-enable Jenkins webhooks"
      echo "2. Disable GitHub Actions workflows"
      echo "3. Notify teams"
    else
      REPO="${1:?Specify repo or --all}"
      echo "🔄 Rolling back $REPO"
      gh workflow disable --all --repo "$REPO" 2>/dev/null || true
      echo "Re-enable Jenkins webhook for $REPO"
    fi
    ;;
    
  *)
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  disable-jenkins-triggers    Disable Jenkins webhooks"
    echo "  enable-jenkins-triggers     Re-enable Jenkins for a repo"
    echo "  verify-gha-triggers         Check GHA workflows are active"
    echo "  archive-jenkins-jobs        Archive Jenkins job configs"
    echo "  rollback [--all|repo]       Rollback to Jenkins"
    ;;
esac
EOF
chmod +x scripts/cutover.sh

# ============================================================================
# workflows/reusable/ci-node.yml
# ============================================================================
cat > workflows/reusable/ci-node.yml << 'EOF'
name: Node.js CI

on:
  workflow_call:
    inputs:
      node-version:
        type: string
        default: '20'
      working-directory:
        type: string
        default: '.'

jobs:
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ${{ inputs.working-directory }}
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
          cache: 'npm'

      - run: npm ci
      - run: npm test
      - run: npm run build --if-present
EOF

# ============================================================================
# workflows/reusable/docker-build.yml
# ============================================================================
cat > workflows/reusable/docker-build.yml << 'EOF'
name: Docker Build and Push

on:
  workflow_call:
    inputs:
      image-name:
        required: true
        type: string
      registry:
        required: true
        type: string
      aws-region:
        type: string
        default: 'eu-west-2'
    secrets:
      AWS_ROLE_ARN:
        required: true
    outputs:
      image:
        value: ${{ jobs.build.outputs.image }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    outputs:
      image: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v4

      - uses: docker/setup-buildx-action@v3

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ inputs.aws-region }}

      - uses: aws-actions/amazon-ecr-login@v2

      - id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ inputs.registry }}/${{ inputs.image-name }}
          tags: |
            type=sha,prefix=
            type=ref,event=branch

      - uses: docker/build-push-action@v5
        with:
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
EOF

# ============================================================================
# workflows/reusable/deploy.yml
# ============================================================================
cat > workflows/reusable/deploy.yml << 'EOF'
name: Deploy

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      image:
        required: true
        type: string
      cluster-name:
        required: true
        type: string
      namespace:
        type: string
        default: 'default'
      aws-region:
        type: string
        default: 'eu-west-2'
    secrets:
      AWS_ROLE_ARN:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ inputs.aws-region }}

      - run: |
          aws eks update-kubeconfig --name ${{ inputs.cluster-name }} --region ${{ inputs.aws-region }}

      - run: |
          kubectl set image deployment/app app=${{ inputs.image }} -n ${{ inputs.namespace }}
          kubectl rollout status deployment/app -n ${{ inputs.namespace }} --timeout=5m
EOF

# ============================================================================
# actions/setup-tools/action.yml
# ============================================================================
cat > actions/setup-tools/action.yml << 'EOF'
name: 'Setup Common Tools'
description: 'Install commonly used development tools'

inputs:
  node:
    description: 'Node.js version'
    default: ''
  python:
    description: 'Python version'
    default: ''
  aws-cli:
    description: 'Install AWS CLI'
    default: 'false'
  kubectl:
    description: 'kubectl version'
    default: ''

runs:
  using: 'composite'
  steps:
    - if: inputs.node != ''
      uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node }}
        cache: 'npm'

    - if: inputs.python != ''
      uses: actions/setup-python@v5
      with:
        python-version: ${{ inputs.python }}

    - if: inputs.aws-cli == 'true'
      shell: bash
      run: |
        curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip -q awscliv2.zip && sudo ./aws/install && rm -rf awscliv2.zip aws/

    - if: inputs.kubectl != ''
      uses: azure/setup-kubectl@v4
      with:
        version: ${{ inputs.kubectl }}
EOF

# ============================================================================
# actions/notify-slack/action.yml
# ============================================================================
cat > actions/notify-slack/action.yml << 'EOF'
name: 'Notify Slack'
description: 'Send workflow notifications to Slack'

inputs:
  webhook-url:
    required: true
  status:
    required: true
  channel:
    default: ''

runs:
  using: 'composite'
  steps:
    - shell: bash
      env:
        SLACK_WEBHOOK: ${{ inputs.webhook-url }}
      run: |
        case "${{ inputs.status }}" in
          success) EMOJI="✅"; COLOR="good" ;;
          failure) EMOJI="❌"; COLOR="danger" ;;
          *) EMOJI="ℹ️"; COLOR="warning" ;;
        esac
        
        curl -s -X POST -H 'Content-type: application/json' \
          --data "{
            \"attachments\": [{
              \"color\": \"$COLOR\",
              \"text\": \"$EMOJI ${{ github.workflow }} ${{ inputs.status }}\",
              \"fields\": [
                {\"title\": \"Repository\", \"value\": \"${{ github.repository }}\", \"short\": true},
                {\"title\": \"Branch\", \"value\": \"${{ github.ref_name }}\", \"short\": true}
              ]
            }]
          }" "$SLACK_WEBHOOK"
EOF

# ============================================================================
# examples/workflow-caller.yml
# ============================================================================
cat > examples/workflow-caller.yml << 'EOF'
# Example: How to call reusable workflows from your repo
# Place this in your-repo/.github/workflows/ci.yml

name: CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  ci:
    uses: your-org/gha-workflows/.github/workflows/ci-node.yml@v1
    with:
      node-version: '20'

  build:
    needs: ci
    uses: your-org/gha-workflows/.github/workflows/docker-build.yml@v1
    with:
      image-name: my-app
      registry: 123456789012.dkr.ecr.eu-west-2.amazonaws.com
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}

  deploy:
    needs: build
    if: github.ref == 'refs/heads/main'
    uses: your-org/gha-workflows/.github/workflows/deploy.yml@v1
    with:
      environment: production
      image: ${{ needs.build.outputs.image }}
      cluster-name: prod-cluster
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
EOF

# ============================================================================
# .gitignore
# ============================================================================
cat > .gitignore << 'EOF'
# Terraform
*.tfstate
*.tfstate.*
.terraform/
*.tfvars
!*.tfvars.example

# Audit outputs
audit-results/
jenkins-audit-*/
migrations/

# IDE
.idea/
.vscode/
*.swp

# OS
.DS_Store
Thumbs.db

# Secrets (should never be committed)
*.pem
*.key
credentials.csv
EOF

echo ""
echo "✅ Repository created successfully!"
echo ""
echo "📁 Location: $TARGET_DIR"
echo "📛 Suggested repo name: jenkins-to-gha-migration"
echo ""
echo "Next steps:"
echo "  1. cd $TARGET_DIR"
echo "  2. git init"
echo "  3. git add ."
echo "  4. git commit -m 'Initial commit: Jenkins to GHA migration toolkit'"
echo "  5. gh repo create your-org/jenkins-to-gha-migration --private --source=."
echo ""
echo "Then follow docs/MIGRATION_GUIDE.md to begin migration."
EOF