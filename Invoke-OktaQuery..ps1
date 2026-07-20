# Export CSV report of data from Okta, supply parameter corresponding to the type of report you need.
# Requires an Okta API token.
# Test first, use at your own risk.

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$OktaDomain,

    [Parameter(Mandatory)]
    [string]$ApiKey,

    [Parameter(Mandatory)]
    [ValidateSet("UserLogs", "UserApps", "AllApps", "AllDevices", "UserDevices", "AllUsers")]
    [string]$Mode,

    [Parameter()]
    [string]$UserLogin,

    [Parameter()]
    [int]$LogHours = 48,

    [Parameter()]
    [switch]$ResolveUsers
)

$ErrorActionPreference = "Stop"

if ($OktaDomain -notmatch "^https?://") {
    $OktaDomain = "https://$OktaDomain"
}
$baseUrl = $OktaDomain.TrimEnd("/")
$headers = @{
    "Authorization" = "SSWS $ApiKey"
    "Accept"        = "application/json"
    "Content-Type"  = "application/json"
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmm"

function Invoke-OktaPaginatedGet {
    param([string]$Uri)

    $results = @()
    $nextUri = $Uri

    while ($nextUri) {
        $response = Invoke-WebRequest -Uri $nextUri -Headers $headers -Method Get -UseBasicParsing
        $results += ($response.Content | ConvertFrom-Json)

        $linkHeader = $response.Headers["Link"]
        $nextUri = $null

        if ($linkHeader) {
            $links = if ($linkHeader -is [array]) { $linkHeader } else { @($linkHeader) }
            foreach ($link in $links) {
                if ($link -match '<([^>]+)>;\s*rel="next"') {
                    $nextUri = $Matches[1]
                }
            }
        }
    }

    return $results
}

function Get-OktaUserByLogin {
    param([string]$Login)

    $encoded = [System.Web.HttpUtility]::UrlEncode($Login)
    $uri = "$baseUrl/api/v1/users/$encoded"
    try {
        $response = Invoke-WebRequest -Uri $uri -Headers $headers -Method Get -UseBasicParsing
        return ($response.Content | ConvertFrom-Json)
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 404) {
            throw "No user found with login: $Login"
        }
        throw
    }
}

function Export-ToCsv {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [object[]]$Data
    )

    $fileName = "${Name}_${timestamp}.csv"
    $Data | Export-Csv -Path $fileName -NoTypeInformation -Encoding UTF8
    Write-Host "Exported $($Data.Count) record(s) to $fileName" -ForegroundColor Green
}

switch ($Mode) {
    "UserLogs" {
        if (-not $UserLogin) { throw "UserLogin is required for mode: UserLogs" }

        $user = Get-OktaUserByLogin -Login $UserLogin
        $userId = $user.id
        $since = (Get-Date).AddHours(-$LogHours).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.000Z")

        Write-Host "Retrieving logs for $UserLogin (ID: $userId) since $since ..." -ForegroundColor Cyan

        $uri = "$baseUrl/api/v1/logs?filter=actor.id eq `"$userId`"&since=$since&sortOrder=DESCENDING&limit=100"
        $logs = Invoke-OktaPaginatedGet -Uri $uri

        $results = $logs | ForEach-Object {
            [PSCustomObject]@{
                Time        = $_.published
                EventType   = $_.eventType
                DisplayMsg  = $_.displayMessage
                Outcome     = $_.outcome.result
                Target      = ($_.target | ForEach-Object { $_.displayName }) -join ", "
            }
        }

        Export-ToCsv -Name "UserLogs_$($UserLogin -replace '@','_at_')" -Data $results
    }

    "UserApps" {
        if (-not $UserLogin) { throw "UserLogin is required for mode: UserApps" }

        $user = Get-OktaUserByLogin -Login $UserLogin
        $userId = $user.id

        Write-Host "Retrieving app assignments for $UserLogin (ID: $userId) ..." -ForegroundColor Cyan

        $uri = "$baseUrl/api/v1/apps?filter=user.id eq `"$userId`"&expand=user/$userId&limit=200"
        $apps = Invoke-OktaPaginatedGet -Uri $uri

        if (-not $apps -or $apps.Count -eq 0) {
            $uri = "$baseUrl/api/v1/users/$userId/appLinks"
            $appLinks = Invoke-OktaPaginatedGet -Uri $uri

            $results = $appLinks | ForEach-Object {
                [PSCustomObject]@{
                    AppName   = $_.appName
                    Label     = $_.label
                    LinkUrl   = $_.linkUrl
                    SortOrder = $_.sortOrder
                }
            }
        }
        else {
            $results = $apps | ForEach-Object {
                [PSCustomObject]@{
                    Id          = $_.id
                    Name        = $_.name
                    Label       = $_.label
                    Status      = $_.status
                    SignOn      = $_.signOnMode
                    Activated   = $_.activated
                    LastUpdated = $_.lastUpdated
                }
            }
        }

        Export-ToCsv -Name "UserApps_$($UserLogin -replace '@','_at_')" -Data $results
    }

    "AllApps" {
        Write-Host "Retrieving all applications in the org ..." -ForegroundColor Cyan

        $uri = "$baseUrl/api/v1/apps?limit=200"
        $apps = Invoke-OktaPaginatedGet -Uri $uri

        $results = $apps | ForEach-Object {
            [PSCustomObject]@{
                Id          = $_.id
                Name        = $_.name
                Label       = $_.label
                Status      = $_.status
                SignOn      = $_.signOnMode
                Created     = $_.created
                Activated   = $_.activated
                LastUpdated = $_.lastUpdated
            }
        }

        Export-ToCsv -Name "AllApps" -Data $results
    }

    "AllDevices" {
        Write-Host "Retrieving all devices in the org ..." -ForegroundColor Cyan

        $uri = "$baseUrl/api/v1/devices?limit=200"
        $devices = Invoke-OktaPaginatedGet -Uri $uri

        $results = $devices | ForEach-Object {
            $obj = [ordered]@{
                Id               = $_.id
                Name             = $_.profile.displayName
                Model            = $_.profile.model
                SerialNumber     = $_.profile.serialNumber
                Platform         = $_.profile.platform
                Status           = $_.status
                ResourceType     = $_.resourceType
                ManagementStatus = $_.managementStatus
                Created          = $_.created
            }

            if ($ResolveUsers) {
                $userDisplay = ""
                if ($_._links -and $_._links.users) {
                    $usersUri = $_._links.users.href
                    if ($usersUri) {
                        $deviceUsers = Invoke-OktaPaginatedGet -Uri $usersUri
                        $userDisplay = ($deviceUsers | ForEach-Object {
                            if ($_.user -and $_.user.profile) { $_.user.profile.email }
                            elseif ($_.profile) { $_.profile.email }
                        }) -join ", "
                    }
                }
                $obj["Users"] = $userDisplay
            }

            [PSCustomObject]$obj
        }

        Export-ToCsv -Name "AllDevices" -Data $results
    }

    "UserDevices" {
        if (-not $UserLogin) { throw "UserLogin is required for mode: UserDevices" }

        $user = Get-OktaUserByLogin -Login $UserLogin
        $userId = $user.id

        Write-Host "Retrieving devices for $UserLogin (ID: $userId) ..." -ForegroundColor Cyan

        $uri = "$baseUrl/api/v1/users/$userId/devices"
        $devices = Invoke-OktaPaginatedGet -Uri $uri

        $results = $devices | ForEach-Object {
            [PSCustomObject]@{
                Id               = $_.id
                Name             = $_.profile.displayName
                Model            = $_.profile.model
                SerialNumber     = $_.profile.serialNumber
                Platform         = $_.profile.platform
                Status           = $_.status
                ResourceType     = $_.resourceType
                ManagementStatus = $_.managementStatus
                Created          = $_.created
            }
        }

        Export-ToCsv -Name "UserDevices_$($UserLogin -replace '@','_at_')" -Data $results
    }

    "AllUsers" {
        Write-Host "Retrieving all users in the org ..." -ForegroundColor Cyan

        $uri = "$baseUrl/api/v1/users?limit=200"
        $users = Invoke-OktaPaginatedGet -Uri $uri

        $results = $users | ForEach-Object {
            [PSCustomObject]@{
                Id          = $_.id
                Email       = $_.profile.email
                FirstName   = $_.profile.firstName
                LastName    = $_.profile.lastName
                Status      = $_.status
                Title       = $_.profile.title
                Department  = $_.profile.department
                Manager     = $_.profile.manager
                Created     = $_.created
                LastLogin   = $_.lastLogin
                LastUpdated = $_.lastUpdated
            }
        }

        Export-ToCsv -Name "AllUsers" -Data $results
    }
}
