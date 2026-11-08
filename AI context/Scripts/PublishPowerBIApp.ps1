<#
.SYNOPSIS
    Publishes a .pbix to one or more Power BI Service workspaces (report overwrite).

.DESCRIPTION
    Import/overwrite of the report (.pbix) into each of the target workspaces
    (New-PowerBIReport, ConflictAction = CreateOrOverwrite). By default it
    publishes to both project workspaces: "Executive Dashboards" (interactive
    viewers) and "Subscribtions" (a separate PPU workspace for emailing
    with an attachment - the subscription is configured in it separately, manually, see
    end-user-subscribe in the Power BI documentation). These are TWO independent copies
    of the report and dataset - refresh/data source credentials are configured
    in each workspace separately, publishing does not carry them over.

    WARNING: The App update is NOT automated: the public Power BI REST API has no
    endpoint for it (verified against the official Microsoft documentation - only
    Deployment Pipelines can do this via updateAppSettings, a separate
    Premium/Fabric feature). After publishing the report you must manually click "Update app"
    in the Power BI Service.

    Authentication is interactive (Connect-PowerBIServiceAccount), the login window
    opens on every run. Service Principal is a separate setup for
    the future (replacing Connect-PowerBIServiceAccount with
    Connect-PowerBIServiceAccount -ServicePrincipal -Credential ...).

.NOTES
    Requires the MicrosoftPowerBIMgmt module (installed automatically if
    missing, -Scope CurrentUser, no administrator rights needed).
#>

[CmdletBinding()]
param(
    # Workspace names in the Power BI Service (as shown in the UI).
    # The report is published to each of them in turn.
    [string[]] $WorkspaceNames = @("Executive Dashboards", "Subscribtions"),

    # Path to the ready .pbix (built from the PBIP via Power BI Desktop, Save As).
    [string] $PbixPath = "C:\Users\ayrat\OneDrive\$(-join [char[]](0x414,0x43E,0x43A,0x443,0x43C,0x435,0x43D,0x442,0x44B))\ClientA\Semantic Model\Semantic Model.pbix",  # Cyrillic "Documents" folder name built from char codes to keep this file pure ASCII

    # The name under which the report will appear/be updated in the workspace.
    # If not specified - the .pbix file name without the extension is used.
    [string] $ReportName,

    # Skip the interactive confirmation before publishing.
    [switch] $Force
)

$ErrorActionPreference = 'Stop'

# --- 0. Input validation ------------------------------------------------

if (-not (Test-Path -LiteralPath $PbixPath)) {
    throw "File not found: $PbixPath"
}

if (-not $ReportName) {
    $ReportName = [System.IO.Path]::GetFileNameWithoutExtension($PbixPath)
}

$workspaceList = $WorkspaceNames -join "', '"
if (-not $Force) {
    $answer = Read-Host "Publish '$PbixPath' as '$ReportName' to workspace(s): '$workspaceList'? (update the App manually afterwards) (y/N)"
    if ($answer -notin @('y', 'Y', 'yes', 'Yes')) {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return
    }
}

# --- 1. Module and connection ---------------------------------------------------

if (-not (Get-Module -ListAvailable -Name MicrosoftPowerBIMgmt)) {
    Write-Host "Module MicrosoftPowerBIMgmt not found - installing (CurrentUser)..." -ForegroundColor Cyan
    Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser -Force -AllowClobber
}

Import-Module MicrosoftPowerBIMgmt -ErrorAction Stop

Write-Host "Opening the Power BI sign-in window..." -ForegroundColor Cyan
Connect-PowerBIServiceAccount | Out-Null

# --- 2-3. Find workspaces + publish the .pbix to each of them -------------------
#
# Each workspace gets its own INDEPENDENT copy of the report/dataset - publish
# does not link them to each other (refresh, data source credentials,
# subscriptions are configured in each workspace separately, manually).

foreach ($name in $WorkspaceNames) {
    Write-Host "--- Workspace: $name ---" -ForegroundColor Cyan

    $workspaces = Get-PowerBIWorkspace -Name $name
    if (-not $workspaces) {
        Write-Host "Workspace '$name' not found (or no access) - skipping." -ForegroundColor Red
        continue
    }
    if (@($workspaces).Count -gt 1) {
        Write-Host "Found several workspaces named '$name' - specify by Id, skipping. Candidates:`n$($workspaces | Format-Table Id, Name | Out-String)" -ForegroundColor Red
        continue
    }
    $workspace = $workspaces
    Write-Host "Workspace found: $($workspace.Name) [$($workspace.Id)]" -ForegroundColor Green

    Write-Host "Publishing '$PbixPath' -> '$ReportName' ..." -ForegroundColor Cyan
    $report = New-PowerBIReport `
        -Path $PbixPath `
        -Name $ReportName `
        -WorkspaceId $workspace.Id `
        -ConflictAction CreateOrOverwrite

    Write-Host "Report published: $($report.Name) [$($report.Id)] to '$($workspace.Name)'." -ForegroundColor Green
}

# --- 4. Update App ---------------------------------------------------------------
#
# WARNING: The public Power BI REST API has NO endpoint for programmatically updating
# an App (verified against the official Microsoft documentation, 2026-09-06 - sections
# "Apps" and "Groups" contain only workspace read/settings operations, no
# "UpdateApp"/"PublishApp"). Previously there was a call here to a made-up, non-existent
# endpoint groups/{id}/UpdateApp - hence the 404, not a permissions bug.
#
# The only officially documented way to automate specifically
# an App update - Deployment Pipelines (Premium/Fabric), via the parameter
# options.updateAppSettings when deploying a stage. This is a separate feature that requires setting up
# dev/test/prod workspaces, not included here.
#
# So the final step is manual: the "Update app" button in each workspace,
# where there is an App (Executive Dashboards). "Subscribtions" does not need an App -
# emailing goes through a subscription on the report itself, not through the App.

Write-Host "Done. If any of the workspaces has an App - update it manually with the 'Update app' button in the Power BI Service." -ForegroundColor Yellow
