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
