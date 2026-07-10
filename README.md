# Appero Quote Partner Demo Setup

Use this repository to set up a Salesforce org with **Appero Quote** and ready-to-use demo data in a few steps. Authenticate your org with the Salesforce CLI, run one setup script, and open the Appero Quote apps.

No terminal experience? Follow each step literally — including the copy-and-paste notes below.

Replace **`MY-ALIAS`** everywhere below with a short name for your org (for example `appero-demo`). Use the same alias for login and for the setup script.

**Before you start:** a dedicated demo org, the org username (see step 3), the Salesforce CLI installed (step 2), and about 20 minutes.

## 1. Get the repository

Clone with Git **or** download and unzip the ZIP — whichever you prefer.

**Option A — Git clone**

```bash
git clone https://github.com/appero-com/appero-quote-partner-setup.git
cd appero-quote-partner-setup
```

**Option B — Download ZIP**

1. Download: [appero-quote-partner-setup (main branch ZIP)](https://github.com/appero-com/appero-quote-partner-setup/archive/refs/heads/main.zip)
2. **Unzip** the downloaded file. You should see a folder named `appero-quote-partner-setup-main`.
3. **Open a terminal in that folder** — the command line where you will paste the setup commands:

   - **Windows:** open the folder in File Explorer, click the address bar, type `powershell`, and press Enter. On Windows 11 you can also right-click the folder and choose **Open in Terminal**.
   - **Mac:** right-click the folder, hover over **Quick Actions**, and choose **New Terminal at Folder**. Or open Terminal and type `cd `, then drag the folder onto the Terminal window and press Enter.
   - **Linux:** open a terminal and run `cd` followed by the full path to the folder.

## 2. Prerequisites

### Salesforce CLI

Install the [Salesforce CLI](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm) if you do not have it yet. This kit requires **Salesforce CLI v2** (`@salesforce/cli`); use the latest stable release if you can.

Verify the installation — copy the command below, paste it into your terminal, and press **Enter**:

```bash
sf version
```

- **Installed:** the terminal prints a line with version numbers (for example `@salesforce/cli/2.x`).
- **Not installed:** you see `command not found` or similar — install the CLI using the link above, **close and reopen** your terminal, then run `sf version` again.

### Org and user

Use a **dedicated demo org**, not a production or customer org.

**Supported org types**

- Developer Edition
- Sandbox
- Trial or partner demo org
- Scratch org (if it is already connected to the Salesforce CLI)

The user who runs setup needs **admin-level access** in that org — for example permission to install packages, customize the application, and deploy metadata. Run setup as the user who will present or use the demo; permission sets are assigned to that user only.

## 3. Authorize your org

Run this once per org. Copy the command, paste it into your terminal, and press **Enter**. A browser window opens for Salesforce login.

```bash
sf org login web --alias MY-ALIAS
```

> **Use your org username, not necessarily your work email.** For Developer Edition, trial, or partner demo orgs, the login username is often different from your usual email address. Check the welcome or signup email for the exact Salesforce username (for example `name@example.com.partner`). After you log in successfully, you can close the browser and return to the terminal.

## 4. Run setup

Open a terminal in the repository folder (see step 1), then run the command for your operating system.

### Windows (PowerShell)

```powershell
.\scripts\setup.ps1 -TargetOrg MY-ALIAS
```

If PowerShell blocks the script, try Git Bash (below) or run `Unblock-File .\scripts\setup.ps1` once.

### macOS / Linux (Bash)

First time only, make the script executable:

```bash
chmod +x scripts/setup.sh
```

Then run setup:

```bash
./scripts/setup.sh --target-org MY-ALIAS
```

### Windows (Git Bash)

If PowerShell is blocked by antivirus or policy:

```bash
./scripts/setup.sh --target-org MY-ALIAS
```

Setup typically takes **10–20 minutes**, depending on your org and network. Most of that time is the Appero Quote package install.

## 5. After setup

1. Log in to your Salesforce org (same user who ran setup).
2. Open the **Appero Quote** app for quoting and opportunities.
3. Open **Appero Quote Setup** for products, templates, and configuration.
4. Explore the sample account **John Doe Inc.** and the related opportunity to start a demo.

## Good to know

- **One-time demo setup** — intended for a fresh demo org, not for upgrading an existing Appero Quote installation.
- **Running user** — permission sets and group membership apply to the user who executed the script.
- **Demo org only** — do not run this against production or live customer orgs.
- **Re-running setup** — not supported as a standard workflow; use a fresh demo org if you need a clean state.

## Troubleshooting

| Issue | What to try |
|-------|-------------|
| PowerShell script blocked | Use Git Bash and `setup.sh`, or `Unblock-File` on `scripts/setup.ps1` |
| `sf` command not found | Install the Salesforce CLI and restart your terminal |
| Package install fails | Confirm the org user can install packages and that Appero Quote is licensed for the org |
| Permission set assignment fails | Ensure package install finished successfully; re-run setup only on a clean org if needed |
| Deploy or import errors | Confirm the running user has admin-level access; check CLI output for the failing step |

For Appero Quote licensing and package questions, contact **Appero support**.

## What this setup provides

After a successful run, your org includes:

- **Appero Quote** installed and configured for demo use
- **Permission sets** assigned so you can use the quote apps immediately
- **Sample account, contacts, products, and pricing** for CPQ-style demonstrations
- **Quote templates** with line items, bundles, add-ons, and discount examples
- **English quote styling** with letterhead and email template defaults
- **Record pages** for Account, Opportunity, and Product tuned for the Appero Quote apps
- **Appero Quote** and **Appero Quote Setup** Lightning apps ready to open

You can start demonstrating quote creation, product configuration, and document output without manual org preparation.
