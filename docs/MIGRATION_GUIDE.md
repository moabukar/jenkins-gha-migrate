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
