param(
    [Alias('o')]
    [string]$TargetOrg
)

if (-not $TargetOrg) {
    Write-Error @"
No target org specified.

  sf org login web --alias my-demo-org
  .\scripts\setup.ps1 -TargetOrg my-demo-org
"@
    exit 1
}

if (-not (Get-Command sf -ErrorAction SilentlyContinue)) {
    Write-Error 'Salesforce CLI (sf) is not installed or not on PATH.'
    exit 1
}

$RepoRoot = Split-Path $PSScriptRoot -Parent
$PackageConfigPath = Join-Path $RepoRoot 'config\package-version.json'
$PermsetConfigPath = Join-Path $RepoRoot 'config\permsets.json'
$ImportPlanPath = Join-Path $RepoRoot 'data\import-plan.json'

$packageConfig = Get-Content $PackageConfigPath -Raw | ConvertFrom-Json
$packageId = $packageConfig.packageVersionId

if ($packageId -match 'PLACEHOLDER|^04tX+$') {
    Write-Error 'Update config/package-version.json with the current Appero Quote package version Id (04t...).'
    exit 1
}

$permsetConfig = Get-Content $PermsetConfigPath -Raw | ConvertFrom-Json
$userDisplay = sf org display user --target-org $TargetOrg
if ($LASTEXITCODE -ne 0) {
    Write-Error "Could not read user for org alias: $TargetOrg"
    exit 1
}

$username = ($userDisplay | Select-String 'Username').Line.Split(':', 2)[1].Trim()

Write-Host "Setting up Appero Quote demo for $username ($TargetOrg) ..."

Write-Host "Installing Appero Quote package $packageId ..."
sf package install --package $packageId --target-org $TargetOrg --wait 30 --no-prompt --security-type AllUsers
if ($LASTEXITCODE -ne 0) { exit 1 }

foreach ($permset in $permsetConfig.permissionSets) {
    Write-Host "Assigning permission set $permset ..."
    sf org assign permset --name $permset --target-org $TargetOrg --on-behalf-of $username
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

$importPlan = Get-Content $ImportPlanPath -Raw | ConvertFrom-Json
$importCount = if ($importPlan -is [System.Array]) { $importPlan.Count } else { 0 }

if ($importCount -gt 0) {
    Write-Host "Importing demo data ($importCount objects) ..."
    sf data import tree --plan $ImportPlanPath --target-org $TargetOrg
    if ($LASTEXITCODE -ne 0) { exit 1 }
} else {
    Write-Warning 'data/import-plan.json has no import entries. Skipping data import.'
}

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
Write-Host 'Note: FlexiPage assignment is not automated in v1. Assign record pages manually if needed.'
Write-Host ''
