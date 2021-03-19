[CmdletBinding()]
param (
    [parameter(Mandatory = $true)]
    $TenantId,
    [parameter(Mandatory = $false)]
    $Subscription,
    [Switch]$Export,
    [Switch]$html
)
$context = $null
$context = Get-AzContext
$tenantName = (Get-AzTenant -TenantId $TenantId).name
$fileName = $((Get-Date).ToString('yyyy-MM-dd-hh-mm')) + "-vNetReport_$tenantName"

if ($context) {
    Write-Host "You're logged in to Tenant $([char]034)$($tenantName)$([char]034) as $($context.Account.id)" -ForegroundColor Green
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
    return $Query.value 
}
$Subscriptions = Get-AzSubscription -SubscriptionName $Subscription -TenantId $TenantId | Where-Object { $_.State -eq 'Enabled' -and $_.name -ne 'Zugriff auf Azure Active Directory' -and $_.name -ne 'Access to Azure Active Directory' }
$i = 1
$AzRestVirtualNetwork = @()
Clear-Host
foreach ($Subscription in $Subscriptions) {
    if ($Export) {
        Write-Progress -Activity "Fetching vNet Information from $($Subscription.Name)" -Status "Subsctiption $i out of $($Subscriptions.count)" -PercentComplete (($i / $Subscriptions.Count) * 100)  
        $i++
        if ($i -eq $Subscriptions.count) {
            Write-Host "Export Completed!" -ForegroundColor Green
            $filepath = Get-ChildItem $fileName*
            Write-Host "$($pwd)\$($filepath.Name)" -ForegroundColor Yellow
        }
    }
    $Objects = Get-AzRestVirtualNetwork -SubscriptionId $Subscription.Id 
    foreach ($Object in $Objects) {
        $Current = [ordered]@{'Subscription' = $Subscription.Name; 'vNetName' = $Object.Name; 'addressPref1' = $Object.properties.addressSpace.addressPrefixes[0]; 'addressPref2' = $Object.properties.addressSpace.addressPrefixes[1]; 'CostCenter' = $Object.tags.cost_center; 'PspElement' = $Object.tags.psp_element; }
        $AzRestVirtualNetwork += New-Object PSObject -Property $Current
    }
    if ($Export) {
        if ($Html) {
            $a = "<style>"
            $a = $a + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;font-family:arial}"
            $a = $a + "TH{border-width: 1px;padding: 5px;border-style: solid;border-color: black;}"
            $a = $a + "TD{border-width: 1px;padding: 5px;border-style: solid;border-color: black;}"
            $a = $a + "</style>"
            $AzRestVirtualNetwork  | ConvertTo-Html -Head $a | Out-file ".\$fileName.html"
        }
        else {
            $AzRestVirtualNetwork | Export-CSV ".\$fileName.csv" -Delimiter ';' -force -notypeinformation -Append
        }
    }
    if (!$export) {
        $AzRestVirtualNetwork
    }
}