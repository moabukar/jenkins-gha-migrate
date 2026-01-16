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
