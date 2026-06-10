#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

TARGET_ORG_ARG=""

print_usage() {
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
      TARGET_ORG_ARG="$2"
      shift 2
      ;;
    --help|-h)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      print_usage
      exit 1
      ;;
  esac
done

set_target_org "$TARGET_ORG_ARG"

require_sf_cli
require_python3
require_target_org
show_org_info
test_user_permissions
install_appero_package
assign_permission_sets
# FlexiPage assignment skipped in v1 — enable deploy_flexipage_assignments when config/flexipages.json is ready.
import_demo_data
invoke_post_setup_apex
show_success_summary
