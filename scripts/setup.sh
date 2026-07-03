#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_ORG=""

usage() {
  cat <<'EOF'
Usage: ./scripts/setup.sh --target-org <alias>

Example:
  sf org login web --alias my-demo-org
  ./scripts/setup.sh --target-org my-demo-org
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-org|-o)
      TARGET_ORG="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$TARGET_ORG" ]]; then
  echo "No target org specified."
  usage
  exit 1
fi

if ! command -v sf >/dev/null 2>&1; then
  echo "Salesforce CLI (sf) is not installed or not on PATH."
  exit 1
fi

PACKAGE_ID="$(grep -o '"packageVersionId"[[:space:]]*:[[:space:]]*"[^"]*"' \
  "${REPO_ROOT}/config/package-version.json" | sed -E 's/.*"([^"]+)".*/\1/')"

if [[ -z "$PACKAGE_ID" ]] || [[ "$PACKAGE_ID" == *PLACEHOLDER* ]] || [[ "$PACKAGE_ID" =~ ^04tX+$ ]]; then
  echo "Update config/package-version.json with the current Appero Quote package version Id (04t...)."
  exit 1
fi

echo "Setting up Appero Quote demo for org ${TARGET_ORG} ..."

echo "Installing Appero Quote package ${PACKAGE_ID} ..."
sf package install \
  --package "$PACKAGE_ID" \
  --target-org "$TARGET_ORG" \
  --wait 30 \
  --no-prompt \
  --security-type AllUsers

echo "Assigning permission sets ..."
sf org assign permset \
  --name sf42_quotefx__apoQuoteUser \
  --target-org "$TARGET_ORG"
sf org assign permset \
  --name sf42_quotefx__apoQuoteAdmin \
  --target-org "$TARGET_ORG"
sf org assign permset \
  --name sf42_quotefx__apperoQuoteLightning \
  --target-org "$TARGET_ORG"

echo "Deploying partner metadata (static resources, record pages, app assignments) ..."
sf project deploy start \
  --source-dir "${REPO_ROOT}/metadata" \
  --target-org "$TARGET_ORG"

IMPORT_COUNT="$(grep -c '"sobject"' "${REPO_ROOT}/data/import-plan.json" || true)"
if [[ "$IMPORT_COUNT" -gt 0 ]]; then
  echo "Importing demo data (${IMPORT_COUNT} objects) ..."
  sf data import tree \
    --plan "${REPO_ROOT}/data/import-plan.json" \
    --target-org "$TARGET_ORG"

  echo "Creating pricebook entries ..."
  sf apex run \
    --file "${REPO_ROOT}/scripts/apex/create-pricebook-entries.apex" \
    --target-org "$TARGET_ORG"
else
  echo "Warning: data/import-plan.json has no import entries. Skipping data import."
fi

echo "Creating quote setup parameters ..."
sf apex run \
  --file "${REPO_ROOT}/scripts/apex/setup-quote-parameters.apex" \
  --target-org "$TARGET_ORG"

echo "Running post-setup custom objects Apex ..."
sf apex run \
  --file "${REPO_ROOT}/scripts/apex/post-setup-custom-objects.apex" \
  --target-org "$TARGET_ORG"

echo "Running post-setup setup entities Apex ..."
sf apex run \
  --file "${REPO_ROOT}/scripts/apex/post-setup-entities.apex" \
  --target-org "$TARGET_ORG"

cat <<'EOF'

Appero Quote demo setup completed successfully.
Open these Lightning apps in your org:
  - Appero Quote
  - Appero Quote Setup

Note: FlexiPage assignment is automated via metadata deploy for Account, Opportunity, and Product2.

EOF
