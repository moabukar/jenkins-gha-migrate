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
