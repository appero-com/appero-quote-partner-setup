#!/usr/bin/env bash
# Shared helpers for Appero Quote partner setup (Bash)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_ORG="${SF_TARGET_ORG:-}"

set_target_org() {
  if [[ -n "${1:-}" ]]; then
    TARGET_ORG="$1"
  fi
}

require_sf_cli() {
  if ! command -v sf >/dev/null 2>&1; then
    cat <<'EOF'
Salesforce CLI (sf) is not installed or not on PATH.

Install it using the official guide:
https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm
EOF
    exit 1
  fi

  local version
  version="$(sf version --json | python3 -c "import sys, json; print(json.load(sys.stdin)['result']['version'])")"
  echo "Using Salesforce CLI ${version}"
}

require_target_org() {
  if [[ -z "$TARGET_ORG" ]]; then
    cat <<'EOF'
No target org specified.

Authenticate your demo org first:
  sf org login web --alias my-demo-org

Then run setup with:
  ./scripts/setup.sh --target-org my-demo-org
EOF
    exit 1
  fi
}

require_python3() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo "Python 3 is required for the Bash setup script (JSON and XML generation)."
    exit 1
  fi
}

sf_json() {
  local output
  if ! output="$(sf "$@" --json 2>&1)"; then
    echo "sf command failed: sf $*""
    echo "$output"
    exit 1
  fi
  printf '%s' "$output"
}

get_running_user_context() {
  sf_json org display user --target-org "$TARGET_ORG"
}

show_org_info() {
  local org_json user_json
  org_json="$(sf_json org display --target-org "$TARGET_ORG")"
  user_json="$(get_running_user_context)"

  python3 - "$org_json" "$user_json" <<'PY'
import json, sys

org = json.loads(sys.argv[1])["result"]
user = json.loads(sys.argv[2])["result"]

print()
print("Target org summary")
print(f"  Alias:            {org.get('alias', '')}")
print(f"  Username:         {org.get('username', '')}")
print(f"  Org Id:           {org.get('id', '')}")
print(f"  Instance URL:     {org.get('instanceUrl', '')}")
print(f"  Profile:          {user.get('profileName', '')}")
print()
PY
}

test_user_permissions() {
  local user_json username query query_json
  user_json="$(get_running_user_context)"
  username="$(printf '%s' "$user_json" | python3 -c "import sys, json; print(json.load(sys.stdin)['result']['username'])")"

  query="SELECT Profile.Name, Profile.PermissionsInstallPackaging, Profile.PermissionsCustomizeApplication FROM User WHERE Username = '${username}'"
  query_json="$(sf_json data query --query "$query" --target-org "$TARGET_ORG")"

  python3 - "$query_json" "$username" <<'PY'
import json, sys

payload = json.loads(sys.argv[1])
username = sys.argv[2]
records = payload["result"]["records"]
if not records:
    raise SystemExit(f"Could not load permission data for user {username}")

profile = records[0]["Profile"]
missing = []
if not profile.get("PermissionsInstallPackaging"):
    missing.append("Install Packaged Components (PermissionsInstallPackaging)")
if not profile.get("PermissionsCustomizeApplication"):
    missing.append("Customize Application (PermissionsCustomizeApplication)")

if missing:
    print("The authenticated user is missing required permissions:")
    for item in missing:
        print(f"  - {item}")
    print("Use a System Administrator profile or an equivalent demo admin user.")
    raise SystemExit(1)

print("Permission checks passed for the running user.")
PY
}

read_json_config() {
  local relative_path="$1"
  local path="${REPO_ROOT}/${relative_path}"
  if [[ ! -f "$path" ]]; then
    echo "Missing config file: $path"
    exit 1
  fi
  python3 -c "import json, pathlib; print(pathlib.Path('$path').read_text())"
}

install_appero_package() {
  local package_id
  package_id="$(python3 -c "import json, pathlib; print(json.load(open('${REPO_ROOT}/config/package-version.json'))['packageVersionId'])")"

  if [[ "$package_id" == *PLACEHOLDER* ]] || [[ "$package_id" =~ ^04tX+$ ]]; then
    echo "Update config/package-version.json with the current Appero Quote package version Id (04t...)."
    exit 1
  fi

  echo "Installing Appero Quote package ${package_id} ..."
  sf package install \
    --package "$package_id" \
    --target-org "$TARGET_ORG" \
    --wait 30 \
    --no-prompt \
    --security-type AllUsers
}

assign_permission_sets() {
  local username
  username="$(get_running_user_context | python3 -c "import sys, json; print(json.load(sys.stdin)['result']['username'])")"

  python3 - "$REPO_ROOT/config/permsets.json" "$TARGET_ORG" "$username" <<'PY'
import json, subprocess, sys

config_path, target_org, username = sys.argv[1:4]
config = json.load(open(config_path))

for permset in config["permissionSets"]:
    if "PLACEHOLDER" in permset:
        raise SystemExit("Update config/permsets.json with namespaced permission set API names.")

    print(f"Assigning permission set {permset} to {username} ...")
    subprocess.run(
        [
            "sf", "org", "assign", "permset",
            "--name", permset,
            "--target-org", target_org,
            "--on-behalf-of", username,
        ],
        check=True,
    )
PY
}

deploy_flexipage_assignments() {
  python3 - "$REPO_ROOT" "$TARGET_ORG" <<'PY'
import json
import pathlib
import subprocess
import sys
import xml.sax.saxutils as xml_escape

repo_root = pathlib.Path(sys.argv[1])
target_org = sys.argv[2]

user = json.loads(subprocess.check_output(
    ["sf", "org", "display", "user", "--target-org", target_org, "--json"],
    text=True,
))["result"]
profile = user["profileName"]

config = json.load(open(repo_root / "config" / "flexipages.json"))
template = (repo_root / "metadata" / "templates" / "profile-action-override.xml.template").read_text()
generated_dir = repo_root / "metadata" / "generated"
applications_dir = generated_dir / "applications"

for app in config["apps"]:
    api_name = app["apiName"]
    if "PLACEHOLDER" in api_name:
        raise SystemExit("Update config/flexipages.json with namespaced app and FlexiPage API names.")

    if generated_dir.exists():
        for path in generated_dir.rglob("*"):
            if path.is_file():
                path.unlink()

    applications_dir.mkdir(parents=True, exist_ok=True)

    print(f"Retrieving Lightning app metadata: {api_name} ...")
    subprocess.run(
        [
            "sf", "project", "retrieve", "start",
            "--metadata", f"CustomApplication:{api_name}",
            "--output-dir", str(generated_dir),
            "--target-org", target_org,
            "--wait", "10",
        ],
        check=True,
    )

    app_file = applications_dir / f"{api_name}.app-meta.xml"
    if not app_file.exists():
        raise SystemExit(f"Retrieved app metadata not found: {app_file}")

    overrides = ""
    for assignment in app["assignments"]:
        if "PLACEHOLDER" in assignment["flexipage"]:
            raise SystemExit("Update config/flexipages.json with namespaced FlexiPage API names.")

        for form_factor in config["formFactors"]:
            overrides += (
                template
                .replace("{{FLEXIPAGE}}", xml_escape.escape(assignment["flexipage"]))
                .replace("{{FORM_FACTOR}}", xml_escape.escape(form_factor))
                .replace("{{OBJECT}}", xml_escape.escape(assignment["object"]))
                .replace("{{PROFILE}}", xml_escape.escape(profile))
            )

    content = app_file.read_text(encoding="utf-8")
    if "</CustomApplication>" not in content:
        raise SystemExit(f"Invalid CustomApplication metadata file: {app_file}")

    content = content.replace("</CustomApplication>", f"{overrides}</CustomApplication>")
    app_file.write_text(content, encoding="utf-8")

    print(f"Deploying FlexiPage assignments for {app['label']} ({profile}) ...")
    subprocess.run(
        [
            "sf", "project", "deploy", "start",
            "--source-dir", str(applications_dir),
            "--target-org", target_org,
            "--wait", "10",
        ],
        check=True,
    )
PY
}

import_demo_data() {
  local object_count
  object_count="$(python3 - "$REPO_ROOT" <<'PY'
import json
import sys
from pathlib import Path

plan = json.loads((Path(sys.argv[1]) / "data" / "import-plan.json").read_text(encoding="utf-8"))
if isinstance(plan, list):
    print(len(plan))
elif isinstance(plan, dict):
    print(len(plan.get("objects", [])))
else:
    print(0)
PY
)"

  if [[ "$object_count" -eq 0 ]]; then
    echo "Warning: data/import-plan.json has no import entries. Skipping data import."
    return 0
  fi

  echo "Importing demo data (${object_count} objects) ..."
  sf data import tree \
    --plan "${REPO_ROOT}/data/import-plan.json" \
    --target-org "$TARGET_ORG"
}

run_apex_script() {
  local relative_path="$1"
  local label="$2"

  echo "Running ${label} ..."
  sf apex run \
    --file "${REPO_ROOT}/${relative_path}" \
    --target-org "$TARGET_ORG"

  if [[ $? -ne 0 ]]; then
    echo "${label} failed."
    exit 1
  fi
}

invoke_post_setup_apex() {
  run_apex_script "scripts/apex/post-setup-custom-objects.apex" "post-setup custom objects Apex"
  run_apex_script "scripts/apex/post-setup-entities.apex" "post-setup setup entities Apex"
}

show_success_summary() {
  cat <<'EOF'

Appero Quote demo setup completed successfully.
Open these Lightning apps in your org:
  - Appero Quote
  - Appero Quote Setup

Note: FlexiPage assignment is not automated in v1. Assign record pages manually if needed.

EOF
}
