# Shared helpers for Appero Quote partner setup (PowerShell)

$ErrorActionPreference = 'Stop'

$Script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Script:TargetOrg = $env:SF_TARGET_ORG

function Set-TargetOrg {
    param([string]$OrgAlias)
    if ($OrgAlias) {
        $Script:TargetOrg = $OrgAlias
    }
}

function Require-SfCli {
    if (-not (Get-Command sf -ErrorAction SilentlyContinue)) {
        throw @"
Salesforce CLI (sf) is not installed or not on PATH.

Install it using the official guide:
https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm
"@
    }

    $version = (sf version --json | ConvertFrom-Json).result.version
    Write-Host "Using Salesforce CLI $version"
}

function Require-TargetOrg {
    if (-not $Script:TargetOrg) {
        throw @"
No target org specified.

Authenticate your demo org first:
  sf org login web --alias my-demo-org

Then run setup with:
  .\scripts\setup.ps1 -TargetOrg my-demo-org
"@
    }
}

function Invoke-SfJson {
    param(
        [string[]]$Arguments
    )

    $output = & sf @Arguments --json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "sf command failed: sf $($Arguments -join ' ')`n$output"
    }

    return ($output | ConvertFrom-Json)
}

function Get-RunningUserContext {
    $response = Invoke-SfJson @(
        'org', 'display', 'user',
        '--target-org', $Script:TargetOrg
    )

    return $response.result
}

function Show-OrgInfo {
    $org = Invoke-SfJson @(
        'org', 'display',
        '--target-org', $Script:TargetOrg
    ).result

    $user = Get-RunningUserContext

    Write-Host ''
    Write-Host 'Target org summary'
    Write-Host "  Alias:            $($org.alias)"
    Write-Host "  Username:         $($org.username)"
    Write-Host "  Org Id:           $($org.id)"
    Write-Host "  Instance URL:     $($org.instanceUrl)"
    Write-Host "  Profile:          $($user.profileName)"
    Write-Host ''
}

function Test-UserPermissions {
    $user = Get-RunningUserContext
    $username = $user.username

    $query = @"
SELECT Profile.Name,
       Profile.PermissionsInstallPackaging,
       Profile.PermissionsCustomizeApplication,
       Profile.PermissionsModifyAllData
FROM User
WHERE Username = '$username'
"@

    $response = Invoke-SfJson @(
        'data', 'query',
        '--query', $query,
        '--target-org', $Script:TargetOrg
    )

    $record = $response.result.records[0]
    if (-not $record) {
        throw "Could not load permission data for user $username"
    }

    $missing = @()
    if (-not $record.Profile.PermissionsInstallPackaging) {
        $missing += 'Install Packaged Components (PermissionsInstallPackaging)'
    }
    if (-not $record.Profile.PermissionsCustomizeApplication) {
        $missing += 'Customize Application (PermissionsCustomizeApplication)'
    }

    if ($missing.Count -gt 0) {
        throw @"
The authenticated user is missing required permissions:
  - $($missing -join "`n  - ")

Use a System Administrator profile or an equivalent demo admin user.
"@
    }

    Write-Host 'Permission checks passed for the running user.'
}

function Read-JsonConfig {
    param([string]$RelativePath)

    $path = Join-Path $Script:RepoRoot $RelativePath
    if (-not (Test-Path $path)) {
        throw "Missing config file: $path"
    }

    return (Get-Content $path -Raw | ConvertFrom-Json)
}

function Install-ApperoPackage {
    $config = Read-JsonConfig 'config/package-version.json'
    $packageId = $config.packageVersionId

    if ($packageId -match 'PLACEHOLDER|^04tX+$') {
        throw 'Update config/package-version.json with the current Appero Quote package version Id (04t...).'
    }

    Write-Host "Installing Appero Quote package $packageId ..."
    & sf package install `
        --package $packageId `
        --target-org $Script:TargetOrg `
        --wait 30 `
        --no-prompt `
        --security-type AllUsers

    if ($LASTEXITCODE -ne 0) {
        throw 'Package installation failed.'
    }
}

function Assign-PermissionSets {
    $config = Read-JsonConfig 'config/permsets.json'
    $username = (Get-RunningUserContext).username

    foreach ($permset in $config.permissionSets) {
        if ($permset -match 'PLACEHOLDER') {
            throw 'Update config/permsets.json with namespaced permission set API names.'
        }

        Write-Host "Assigning permission set $permset to $username ..."
        & sf org assign permset `
            --name $permset `
            --target-org $Script:TargetOrg `
            --on-behalf-of $username

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to assign permission set: $permset"
        }
    }
}

function Escape-XmlAttribute {
    param([string]$Value)

    return $Value `
        -replace '&', '&amp;' `
        -replace '<', '&lt;' `
        -replace '>', '&gt;' `
        -replace '"', '&quot;' `
        -replace "'", '&apos;'
}

function Get-ProfileActionOverrideBlock {
    param(
        [string]$Template,
        [string]$Flexipage,
        [string]$FormFactor,
        [string]$Object,
        [string]$Profile
    )

    return $Template `
        -replace '\{\{FLEXIPAGE\}\}', (Escape-XmlAttribute $Flexipage) `
        -replace '\{\{FORM_FACTOR\}\}', (Escape-XmlAttribute $FormFactor) `
        -replace '\{\{OBJECT\}\}', (Escape-XmlAttribute $Object) `
        -replace '\{\{PROFILE\}\}', (Escape-XmlAttribute $Profile)
}

function Deploy-FlexipageAssignments {
    $flexipageConfig = Read-JsonConfig 'config/flexipages.json'
    $user = Get-RunningUserContext
    $profile = $user.profileName

    $generatedDir = Join-Path $Script:RepoRoot 'metadata/generated'
    $applicationsDir = Join-Path $generatedDir 'applications'
    New-Item -ItemType Directory -Force -Path $applicationsDir | Out-Null

    $templatePath = Join-Path $Script:RepoRoot 'metadata/templates/profile-action-override.xml.template'
    $template = Get-Content $templatePath -Raw

    foreach ($app in $flexipageConfig.apps) {
        if ($app.apiName -match 'PLACEHOLDER') {
            throw 'Update config/flexipages.json with namespaced app and FlexiPage API names.'
        }

        Write-Host "Retrieving Lightning app metadata: $($app.apiName) ..."
        if (Test-Path $generatedDir) {
            Get-ChildItem $generatedDir -Recurse -File | Remove-Item -Force
        }
        New-Item -ItemType Directory -Force -Path $applicationsDir | Out-Null

        & sf project retrieve start `
            --metadata "CustomApplication:$($app.apiName)" `
            --output-dir $generatedDir `
            --target-org $Script:TargetOrg `
            --wait 10

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to retrieve CustomApplication: $($app.apiName)"
        }

        $appFile = Join-Path $applicationsDir "$($app.apiName).app-meta.xml"
        if (-not (Test-Path $appFile)) {
            throw "Retrieved app metadata not found: $appFile"
        }

        $overrides = ''
        foreach ($assignment in $app.assignments) {
            if ($assignment.flexipage -match 'PLACEHOLDER') {
                throw 'Update config/flexipages.json with namespaced FlexiPage API names.'
            }

            foreach ($formFactor in $flexipageConfig.formFactors) {
                $overrides += Get-ProfileActionOverrideBlock `
                    -Template $template `
                    -Flexipage $assignment.flexipage `
                    -FormFactor $formFactor `
                    -Object $assignment.object `
                    -Profile $profile
            }
        }

        $content = Get-Content $appFile -Raw
        $content = $content -replace '</CustomApplication>', "$overrides</CustomApplication>"
        Set-Content -Path $appFile -Value $content -Encoding utf8NoBOM

        Write-Host "Deploying FlexiPage assignments for $($app.label) ($profile) ..."
        & sf project deploy start `
            --source-dir $applicationsDir `
            --target-org $Script:TargetOrg `
            --wait 10

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to deploy FlexiPage assignments for $($app.apiName)"
        }
    }
}

function Import-DemoData {
    $planPath = Join-Path $Script:RepoRoot 'data/import-plan.json'
    $plan = Read-JsonConfig 'data/import-plan.json'

    if (-not $plan.objects -or $plan.objects.Count -eq 0) {
        Write-Warning 'data/import-plan.json still contains a placeholder. Skipping data import.'
        return
    }

    Write-Host 'Importing demo data ...'
    & sf data import tree `
        --plan $planPath `
        --target-org $Script:TargetOrg

    if ($LASTEXITCODE -ne 0) {
        throw 'Demo data import failed.'
    }
}

function Invoke-PostSetupApex {
    $apexFile = Join-Path $Script:RepoRoot 'scripts/apex/post-setup.apex'

    Write-Host 'Running post-setup Apex ...'
    & sf apex run `
        --file $apexFile `
        --target-org $Script:TargetOrg

    if ($LASTEXITCODE -ne 0) {
        throw 'Post-setup Apex failed.'
    }
}

function Show-SuccessSummary {
    $flexipageConfig = Read-JsonConfig 'config/flexipages.json'

    Write-Host ''
    Write-Host 'Appero Quote demo setup completed successfully.'
    Write-Host 'Open these Lightning apps in your org:'
    foreach ($app in $flexipageConfig.apps) {
        Write-Host "  - $($app.label)"
    }
    Write-Host ''
}
