# Appero Quote Partner Demo Setup

Bootstrap kit for Salesforce ISV partners to prepare a demo org for **Appero Quote** using the Salesforce CLI.

Partners authenticate their own org manually, then run a single setup script. No scratch orgs and no full Salesforce DX app project.

## What this repository does

1. Installs the pinned Appero Quote package version
2. Assigns namespaced permission sets to the authenticated user
3. Imports demo data via `sf data import tree`
4. Runs two post-setup Apex scripts (custom objects, then setup entities) to resolve placeholders and finalize demo configuration

FlexiPage assignment for **Appero Quote** and **Appero Quote Setup** is **not included in v1** and must be done manually in the org until `config/flexipages.json` is finalized.

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
    flexipages.json         # FlexiPage config (reserved for a future release)
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

Before partners run setup, Appero maintains the config files below.

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

### `config/flexipages.json` (future)

Reserved for automated FlexiPage assignment. **Not used in v1.** When enabled, the setup script will retrieve package Lightning apps, add `profileActionOverrides` for the running user's profile, and deploy `CustomApplication` metadata.

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

## Limitations (v1)

- **Single run**: intended for a fresh demo setup, not repeated upgrades or resets
- **Running user only**: permission sets target the authenticated user
- **No FlexiPage automation**: assign record pages for Account, Opportunity, and Product2 manually in **Appero Quote** and **Appero Quote Setup**, or enable `Deploy-FlexipageAssignments` / `deploy_flexipage_assignments` once `config/flexipages.json` is complete
- **Manual release updates**: bump `packageVersionId` in config when Appero publishes a new version
- **Import plan required**: setup skips data import if `data/import-plan.json` has no entries

## Troubleshooting

| Issue | Likely cause |
|-------|----------------|
| Permission check fails | User profile lacks install/customize permissions |
| Package install fails | Invalid `04t` Id, missing license, or org restrictions |
| Data import skipped | `import-plan.json` is empty or missing entries |
| Post-setup Apex fails | Missing static resources, permissions, or placeholder data |
| Wrong record pages in apps | FlexiPage assignment not automated in v1 — configure manually in Setup |

## Support

For Appero Quote package licensing and AppExchange installation questions, contact Appero support.
