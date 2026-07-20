# Export CSV of Okta groups, flag groups that might be used as exemption for MFA (using a keyword list).
# Requires an Okta API token.
# Test first, use at your own risk.

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$OktaDomain,

    [Parameter(Mandatory)]
    [string]$ApiKey,

    [Parameter()]
    [string]$OutputPath
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

# --- Data Collection ---

Write-Host "Collecting all groups..." -ForegroundColor Cyan
$groups = Invoke-OktaPaginatedGet -Uri "$baseUrl/api/v1/groups?limit=200"
Write-Host "Found $($groups.Count) groups." -ForegroundColor Green

# --- Flag Detection ---

$flagKeywords = @('mfa', 'bypass', 'temp', 'temporary', 'test', 'exempt', 'exception', 'exclude', 'no-mfa', 'nomfa', 'skip', 'override', 'breakglass', 'break-glass', 'emergency')
$flagPattern = [regex]::new(($flagKeywords | ForEach-Object { [regex]::Escape($_) }) -join '|', 'IgnoreCase, Compiled')

function Test-Flagged {
    param([string]$Name, [string]$Description)
    if ($Name -and $flagPattern.IsMatch($Name)) { return $true }
    if ($Description -and $flagPattern.IsMatch($Description)) { return $true }
    return $false
}

function Get-MatchedKeywords {
    param([string]$Text)
    if (-not $Text) { return @() }
    $found = $flagPattern.Matches($Text)
    return @($found | ForEach-Object { $_.Value.ToLower() } | Select-Object -Unique)
}

# --- Classification ---

Write-Host "Classifying groups..." -ForegroundColor Cyan
$timestamp = Get-Date -Format "yyyyMMdd_HHmm"

$results = [System.Collections.Generic.List[PSCustomObject]]::new()
foreach ($g in $groups) {
    $name = $g.profile.name
    $desc = $g.profile.description
    $flagged = Test-Flagged -Name $name -Description $desc
    $keywords = if ($flagged) {
        $allText = "$name $desc"
        (Get-MatchedKeywords $allText) -join "; "
    } else { "" }

    $results.Add([PSCustomObject]@{
        Name                  = $name
        Description           = $desc
        Type                  = $g.type
        Flagged               = $flagged
        MatchedKeywords       = $keywords
        Created               = $g.created
        LastUpdated           = $g.lastUpdated
        LastMembershipUpdated = $g.lastMembershipUpdated
        Id                    = $g.id
    })
}

$flaggedCount = ($results | Where-Object { $_.Flagged }).Count
Write-Host "Flagged: $flaggedCount, Clean: $($results.Count - $flaggedCount)" -ForegroundColor Yellow

# --- CSV Export ---

if (-not $OutputPath) {
    $OutputPath = "OktaGroupReport_$timestamp.csv"
}
$results | Sort-Object -Property @{Expression={$_.Flagged}; Descending=$true}, Name |
    Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
Write-Host "Report saved to: $OutputPath ($($results.Count) groups)" -ForegroundColor Green
