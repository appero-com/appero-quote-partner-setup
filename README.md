# Appero Quote Partner Demo Setup

Bootstrap kit for Salesforce ISV partners to prepare a demo org for **Appero Quote** using the Salesforce CLI.

Partners authenticate their own org manually, then run a single setup script. No scratch orgs, no full Salesforce DX app project, and no manual FlexiPage assignment steps.

## What this repository does

1. Installs the pinned Appero Quote package version
2. Assigns namespaced permission sets to the authenticated user
3. Activates package FlexiPages for **Appero Quote** and **Appero Quote Setup** for the running user's profile on:
   - Account
   - Opportunity
   - Product2
4. Imports demo data via `sf data import tree`
5. Runs two post-setup Apex scripts (custom objects, then setup entities) to resolve placeholders and finalize demo configuration

## Prerequisites

### Salesforce CLI

Install the Salesforce CLI if it is not already available:

- [Salesforce CLI Setup Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference.htm)

Verify installation:

```bash
sf version
```

### Authenticated demo org (non-scratch)

This kit targets orgs you already have access to, such as:

- Developer Edition
- Sandbox
- Trial / partner demo org

Authenticate the org before running setup:

```bash
sf org login web --alias my-demo-org
```

The authenticated user should have a profile with at least:

- **Install Packaged Components**
- **Customize Application**

The setup script checks these permissions and exits with a clear message if they are missing.

### Bash-only extra dependency

The macOS/Linux script (`scripts/setup.sh`) requires **Python 3** for JSON and metadata generation. Windows PowerShell does not require Python.

## Quick start

### Windows (PowerShell)

```powershell
sf org login web --alias my-demo-org
.\scripts\setup.ps1 -TargetOrg my-demo-org
```

### macOS / Linux (Bash)

```bash
chmod +x scripts/setup.sh
sf org login web --alias my-demo-org
./scripts/setup.sh --target-org my-demo-org
```

## Repository layout

```text
appero-quote-partner-setup/
  config/
    package-version.json    # Appero updates the 04t... Id per release
    permsets.json           # Namespaced permission set API names
    flexipages.json         # App + FlexiPage API names per object
  data/
    import-plan.json        # sf data import tree plan (used by setup scripts)
    *.json                  # Demo data files in sObject tree format
  metadata/
    generated/              # Created at runtime (gitignored)
    templates/              # FlexiPage assignment XML template
  scripts/
    setup.ps1               # Windows entry point
    setup.sh                # macOS/Linux entry point
    lib/                    # Shared setup logic
    apex/post-setup-custom-objects.apex  # Placeholder resolution on package objects
    apex/post-setup-entities.apex      # Public group setup (separate transaction)
  sfdx-project.json         # Minimal project file for metadata deploy only
```

This is **not** a full SFDX application repository. There is no `force-app/`, LWC source, or scratch org workflow.

## Configuration (maintained by Appero)

Before partners run setup, Appero maintains three config files.

### `config/package-version.json`

```json
{
  "packageVersionId": "04tXXXXXXXXXXXXXXXX"
}
```

Update `packageVersionId` when a new subscriber package version is published.

### `config/permsets.json`

List namespaced permission set API names from the installed package:

```json
{
  "namespace": "sf42_quotefx",
  "permissionSets": [
    "sf42_quotefx__apoQuoteUser",
    "sf42_quotefx__apoQuoteAdmin",
    "sf42_quotefx__apperoQuoteLightning"
  ]
}
```

### `config/flexipages.json`

Defines FlexiPage assignments for both Lightning apps. There are **no record-type-specific** assignments.

Replace all `PLACEHOLDER` values with API names from your golden demo org:

- Managed Lightning app API names (`CustomApplication`)
- Managed FlexiPage API names (`FlexiPage`)

The setup script:

1. Retrieves each app from the target org after package install
2. Adds `profileActionOverrides` for the running user's profile
3. Deploys the updated `CustomApplication` metadata

This is the supported way to automate Lightning record page activation per app and profile when the package ships FlexiPages only.

### Demo data files

The `data/` folder contains:

- **`import-plan.json`** — import plan consumed by `sf data import tree`. Each entry lists an sObject, its JSON file(s), and `saveRefs` / `resolveRefs` flags for cross-file reference resolution.
- **Numbered `*.json` files** — records in sObject tree format.

When you refresh demo data from a golden org, update the JSON files and verify `import-plan.json` still lists the correct files in dependency order.

If a field stores Salesforce Ids that cannot be resolved during import, keep placeholder tokens in the JSON and resolve them in `scripts/apex/post-setup-custom-objects.apex`.

## Setup flow

```text
Validate CLI + target org
        |
        v
Show org summary + check user permissions
        |
        v
Install Appero Quote package (04t...)
        |
        v
Assign permission sets to running user
        |
        v
Retrieve package Lightning apps
Generate profileActionOverrides (Account, Opportunity, Product2)
Deploy CustomApplication metadata
        |
        v
Import demo data (tree import)
        |
        v
Run post-setup custom objects Apex
        |
        v
Run post-setup setup entities Apex
```

## Post-setup Apex scripts

Post-setup runs as **two separate anonymous Apex scripts** to avoid mixed DML errors between package custom objects and setup entities (`Group`, `GroupMember`).

### `scripts/apex/post-setup-custom-objects.apex`

Runs after data import. Currently:

1. Creates letterhead `Document` records from package static resources
2. Resolves quote style page placeholders (`Placeholder1stPage`, `Placeholder2ndPage`)
3. Resolves product group placeholders on `sf42_quotefx__SF42_GenLineItem__c` line items

### `scripts/apex/post-setup-entities.apex`

Runs in a second transaction immediately after the custom-objects script:

1. Creates the `QuoteAdmin` public group
2. Adds the **authenticated running user** to that group

No deployed Apex class is required for partner setup.

## Customizing post-setup Apex

Edit the two scripts above to adjust placeholder mappings, demo settings, or group setup behavior.

## Capturing FlexiPage API names from a golden org

After configuring demo apps correctly in a reference org:

```bash
sf data query --query "SELECT DeveloperName, MasterLabel FROM FlexiPage WHERE NamespacePrefix = 'sf42_quotefx'" --target-org golden-org

sf project retrieve start --metadata "CustomApplication:sf42_quotefx__Your_App_Api_Name" --target-org golden-org
```

Use the retrieved app and FlexiPage API names in `config/flexipages.json`.

## Limitations (v1)

- **Single run**: intended for a fresh demo setup, not repeated upgrades or resets
- **Running user only**: permission sets and FlexiPage assignments target the authenticated user
- **Manual release updates**: bump `packageVersionId` in config when Appero publishes a new version
- **Import plan required**: setup skips data import if `data/import-plan.json` has no entries

## Troubleshooting

| Issue | Likely cause |
|-------|----------------|
| Permission check fails | User profile lacks install/customize permissions |
| Package install fails | Invalid `04t` Id, missing license, or org restrictions |
| App retrieve fails | Wrong app API name in `config/flexipages.json` |
| FlexiPage deploy fails | Wrong FlexiPage API name or profile name with special characters |
| Data import skipped | `import-plan.json` is empty or missing entries |
| Post-setup Apex fails | Placeholder resolution logic not yet implemented |

## Support

For Appero Quote package licensing and AppExchange installation questions, contact Appero support.
