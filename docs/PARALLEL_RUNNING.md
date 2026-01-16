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
