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
