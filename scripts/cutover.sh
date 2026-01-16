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
