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
