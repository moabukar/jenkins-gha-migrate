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
