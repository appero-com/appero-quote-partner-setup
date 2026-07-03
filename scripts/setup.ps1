param(
    [Alias('o')]
    [string]$TargetOrg
)

if (-not $TargetOrg) {
    Write-Error @"
No target org specified.

  sf org login web --alias MY-ALIAS
  .\scripts\setup.ps1 -TargetOrg MY-ALIAS
"@
    exit 1
}

if (-not (Get-Command sf -ErrorAction SilentlyContinue)) {
    Write-Error 'Salesforce CLI (sf) is not installed or not on PATH.'
    exit 1
}

$RepoRoot = Split-Path $PSScriptRoot -Parent
$PackageConfigPath = Join-Path $RepoRoot 'config\package-version.json'
$ImportPlanPath = Join-Path $RepoRoot 'data\import-plan.json'
$MetadataPath = Join-Path $RepoRoot 'metadata'
$CreatePricebookEntriesApexPath = Join-Path $RepoRoot 'scripts\apex\create-pricebook-entries.apex'

$packageConfig = Get-Content $PackageConfigPath -Raw | ConvertFrom-Json
$packageId = $packageConfig.packageVersionId

if ($packageId -match 'PLACEHOLDER|^04tX+$') {
    Write-Error 'Update config/package-version.json with the current Appero Quote package version Id (04t...).'
    exit 1
}

Write-Host "Setting up Appero Quote demo for org $TargetOrg ..."

# TIMING (remove before release)
$setupStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host "Installing Appero Quote package $packageId ..."
sf package install --package $packageId --target-org $TargetOrg --wait 30 --no-prompt --security-type AllUsers
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host 'Assigning permission sets ...'
sf org assign permset --name sf42_quotefx__apoQuoteUser --target-org $TargetOrg
if ($LASTEXITCODE -ne 0) { exit 1 }
sf org assign permset --name sf42_quotefx__apoQuoteAdmin --target-org $TargetOrg
if ($LASTEXITCODE -ne 0) { exit 1 }
sf org assign permset --name sf42_quotefx__apperoQuoteLightning --target-org $TargetOrg
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host 'Deploying partner metadata (static resources, record pages, app assignments) ...'
sf project deploy start --source-dir $MetadataPath --target-org $TargetOrg
if ($LASTEXITCODE -ne 0) { exit 1 }

$importPlan = Get-Content $ImportPlanPath -Raw | ConvertFrom-Json
$importCount = if ($importPlan -is [System.Array]) { $importPlan.Count } else { 0 }

if ($importCount -gt 0) {
    Write-Host "Importing demo data ($importCount objects) ..."
    sf data import tree --plan $ImportPlanPath --target-org $TargetOrg
    if ($LASTEXITCODE -ne 0) { exit 1 }

    Write-Host 'Creating pricebook entries ...'
    sf apex run --file $CreatePricebookEntriesApexPath --target-org $TargetOrg
    if ($LASTEXITCODE -ne 0) { exit 1 }
} else {
    Write-Warning 'data/import-plan.json has no import entries. Skipping data import.'
}

Write-Host 'Creating quote setup parameters ...'
sf apex run --file (Join-Path $RepoRoot 'scripts\apex\setup-quote-parameters.apex') --target-org $TargetOrg
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host 'Running post-setup custom objects Apex ...'
sf apex run --file (Join-Path $RepoRoot 'scripts\apex\post-setup-custom-objects.apex') --target-org $TargetOrg
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host 'Running post-setup setup entities Apex ...'
sf apex run --file (Join-Path $RepoRoot 'scripts\apex\post-setup-entities.apex') --target-org $TargetOrg
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host ''
Write-Host 'Appero Quote demo setup completed successfully.'
Write-Host 'Open these Lightning apps in your org:'
Write-Host '  - Appero Quote'
Write-Host '  - Appero Quote Setup'
Write-Host ''

# TIMING (remove before release)
Write-Host ("Setup completed in {0:N0} seconds." -f $setupStopwatch.Elapsed.TotalSeconds)
Write-Host ''
