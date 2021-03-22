<#
.Description
This Stript reports or exports Virtual Network Details in all or just a single Subscriptions of a Tenant.
.PARAMETER TenantId
Determines which Azure Tenant shall be reported
.PARAMETER Subscription
To limit the report down to just a single Subscription.
.INPUTS
System.String
System.Boolean
.OUTPUTS
System.Management.Automation.PSCustomObject
.EXAMPLE
get_vnet_report.ps1 -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -Export
Export all Virtual Networks from all Subscriptions from the TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx to a CSV File
.EXAMPLE
get_vnet_report.ps1 -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -Export -Html
Export all Virtual Networks from all Subscriptions from the TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx to a Html File
.EXAMPLE
get_vnet_report.ps1 -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Prints all Virtual Networks from all Subscriptions:
Subscription            vNetName    addressPref1    addressPref2    CostCenter  PspElement
------------            --------    ------------    ------------    ----------  -----------
SUBSCRIPTION_NAME_123   vnet-123    10.0.0.0/24     192.10.10.0/24  123456789   X/YYY-ZZZ-000.01
SUBSCRIPTION_NAME_456   vnet-123    10.0.0.1/24     192.10.20.0/24  9879654321  X/YYY-ZZZ-000.02
SUBSCRIPTION_NAME_789   vnet-123    10.0.0.2/24     192.10.30.0/24  123987456   X/YYY-ZZZ-000.03
.EXAMPLE
get_vnet_report.ps1 -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -Subscription SUBSCRIPTION_NAME_123
Prints all Virtual Networks from a single Subscriptions:
Subscription            vNetName    addressPref1    addressPref2    CostCenter  PspElement
------------            --------    ------------    ------------    ----------  -----------
SUBSCRIPTION_NAME_123   vnet-123    10.0.0.0/24     192.10.10.0/24  123456789   X/YYY-ZZZ-000.01
.EXAMPLE
get_vnet_report.ps1 -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -Subscription SUBSCRIPTION_NAME_123 -Export
Export all Virtual Networks from a single Subscription from the TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx to a CSV File
.EXAMPLE
get_vnet_report.ps1 -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -Subscription SUBSCRIPTION_NAME_123 -Export -Html
Export all Virtual Networks from a single Subscription from the TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx to a HTML File

.NOTES
    Author: Rafael Camison
    Date:   Mar 17th, 2021
Check out https://github.com/lordisp/gist/blob/main/get_vnet_report.ps1 for the latest updates on this script

.LINK
https://github.com/lordisp/gist/issues

.LINK
https://docs.microsoft.com/powershell/azure/install-az-ps

.LINK
https://docs.microsoft.com/en-us/rest/api/virtualnetwork/virtualnetworks/listall
.LINK
https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_operators
#>
[CmdletBinding()]
param (
    [parameter(Mandatory = $true)]
    $TenantId,
    [parameter(Mandatory = $false)]
    $Subscription,
    [Switch]$Export,
    [Switch]$Html
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
$i = 0
$AzRestVirtualNetwork = @()
Clear-Host
foreach ($Subscription in $Subscriptions) {
    $Objects = Get-AzRestVirtualNetwork -SubscriptionId $Subscription.Id 
    foreach ($Object in $Objects) {
        $Current = [ordered]@{'Subscription' = $Subscription.Name; 'vNetName' = $Object.Name; 'addressPref1' = $Object.properties.addressSpace.addressPrefixes[0]; 'addressPref2' = $Object.properties.addressSpace.addressPrefixes[1]; 'CostCenter' = $Object.tags.cost_center; 'PspElement' = $Object.tags.psp_element; 'BusinessService' = $Object.tags.business_service; 'BusinessUnit' = $Object.tags.business_unit; 'MspSLA' = $Object.tags.msp_sla; 'Peering' = $Object.properties.virtualNetworkPeerings[0].name;'PeeringState' = $Object.properties.virtualNetworkPeerings[0].properties.peeringState;}
        $AzRestVirtualNetwork += New-Object PSObject -Property $Current
    }
    if ($Export) {
        Write-Progress -Activity "Fetching vNet Information from $($Subscription.Name)" -Status "Subsctiption $i out of $($Subscriptions.count)" -PercentComplete (($i / $Subscriptions.Count) * 100)  
        $i++
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
        if ($i -eq $Subscriptions.count) {
            Write-Host "Export Completed!" -ForegroundColor Green
            $filepath = Get-ChildItem "$($fileName)*" -File
            Write-Host "$($pwd)\$($filepath.Name)" -ForegroundColor Yellow
            & ".\$($filepath.Name)"
        }
    }
    if (!$export) {
        $AzRestVirtualNetwork
    }
}