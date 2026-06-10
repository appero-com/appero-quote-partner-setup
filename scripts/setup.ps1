[CmdletBinding()]
param(
    [Alias('o')]
    [string]$TargetOrg
)

. "$PSScriptRoot/lib/common.ps1"

Set-TargetOrg -OrgAlias $TargetOrg

try {
    Require-SfCli
    Require-TargetOrg
    Show-OrgInfo
    Test-UserPermissions
    Install-ApperoPackage
    Assign-PermissionSets
    # FlexiPage assignment skipped in v1 — enable Deploy-FlexipageAssignments when config/flexipages.json is ready.
    Import-DemoData
    Invoke-PostSetupApex
    Show-SuccessSummary
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
