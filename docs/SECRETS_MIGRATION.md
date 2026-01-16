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
