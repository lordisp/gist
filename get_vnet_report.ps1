[CmdletBinding()]
param (
    [parameter(Mandatory = $true)]
    $TenantId,
    [parameter(Mandatory = $false)]
    $Subscription,
    [Switch]$Export
)
$context = $null
$context = Get-AzContext
$tenantName = (Get-AzTenant -TenantId $TenantId).name
$fileName = $((Get-Date).ToString('yyyy-MM-dd-hh-mm')) + "-vNetReport_$tenantName.csv"

if ($context) {
    Write-Host "You're' logged in" -ForegroundColor Green
}
else {
    Write-Host "You're not logged in to Azure" -ForegroundColor Yellow
    $context = Connect-AzAccount -Tenant $TenantId
}
if ($context.Tenant.Id -ne $TenantId) {
    $context = Connect-AzAccount -Tenant $TenantId -WarningAction SilentlyContinue
}
function Get-AzRestVirtualNetwork {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        $SubscriptionId
    )
    $Token = Get-AzAccessToken
    $ApiUri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Network/virtualNetworks?api-version=2020-11-01"
    $headers = @{
        'Content-Type'  = 'application/json';
        'Authorization' = "Bearer" + " " + "$($Token.Token)";
    }
    try {
        $Query = Invoke-RestMethod -Method Get -Uri $ApiUri -Headers $headers -ErrorAction SilentlyContinue
    }
    catch {
        Write-Error "Error with Subscription $($SubscriptionId)"
        Write-Error $_
    }
    
    ForEach ($Result in $Query.value) {
        [PSCustomObject]@{
            vNetName        = $Result.Name
            addressPrefixes = $Result.properties.addressSpace.addressPrefixes
        }
    } 

    return $Query.value 
}
$Subscriptions = Get-AzSubscription -SubscriptionName $Subscription -TenantId $TenantId | Where-Object { $_.State -eq 'Enabled' -and $_.name -ne 'Zugriff auf Azure Active Directory' -and $_.name -ne 'Access to Azure Active Directory' }

foreach ($Subscription in $Subscriptions) {
    $AzRestVirtualNetwork = Get-AzRestVirtualNetwork -SubscriptionId $Subscription.Id | Select-Object @{n = 'Subscription'; e = { $Subscription.Name } }, `
        vNetName, `
    @{n = 'addressPref1'; e = { $_.addressPrefixes[0] } }, `
    @{n = 'addressPref2'; e = { $_.addressPrefixes[1] } } | `
        Where-Object { $_.vNetName.Length -gt 0 }
    if ($Export) {
        $AzRestVirtualNetwork | Export-CSV ".\$fileName" -Delimiter ';' -force -notypeinformation -Append
    }
    $AzRestVirtualNetwork
}