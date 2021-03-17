$context = $null
$context = Get-AzContext
if ($context) {
    Write-Host "You're' logged in" -ForegroundColor Green
}
else {
    Write-Host "You're not logged in to Azure" -ForegroundColor Red
    $context = Connect-AzAccount 
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
    $Query = Invoke-RestMethod -Method Get -Uri $ApiUri -Headers $headers
    ForEach ($Result in $Query.value) {
        [PSCustomObject]@{
            vNetName        = $Result.Name
            <# vNetId          = $Result.id #>
            addressPrefixes = $Result.properties.addressSpace.addressPrefixes
            subnets         = $Result.properties.subnets.name 
            addressPrefix   = $Result.properties.subnets.properties.addressPrefix
        }
    } 

    <# return $Query.value | select -First 1 #>
}
#$Subscriptions = Get-AzSubscription 
Get-AzRestVirtualNetwork -SubscriptionId '18d6c26e-6e4c-4d49-9849-e8d15fb21b08'
