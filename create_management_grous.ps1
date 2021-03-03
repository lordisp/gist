[CmdletBinding()]
param (
    [string]$parenManagementGroup,
    [string]$managementGroupName,
    [string]$tenantId
)

if(!$parenManagementGroup){
    $parenManagementGroup = read-host -Prompt "Please enter the exsiting ManagementGroup-Id, that act as Parent for the new ManagementGroup."
}

if(!$managementGroupName){
    $managementGroupName = read-host -Prompt "Please enter a Name for the new ManagementGroup you like to create."
}

if(!$tenantId){
    $tenantId = read-host -Prompt "Please enter the taget Tenant Id for the new Management Group."
}

<# Do not change anything below #>

Set-AzContext -TenantId $tenantId | Out-Null

$parentObject = Get-AzManagementGroup -GroupId $parenManagementGroup -WarningAction SilentlyContinue

$newParent = New-AzManagementGroup -GroupName $managementGroupName -DisplayName $managementGroupName -ParentObject $parentObject -WarningAction SilentlyContinue

$prodGroup = New-AzManagementGroup -GroupName "$($managementGroupName)-Prod" -DisplayName "Prod" -ParentObject $newParent -WarningAction SilentlyContinue

$nonProdGroup = New-AzManagementGroup -GroupName "$($managementGroupName)-NonProd" -DisplayName "NonProd" -ParentObject $newParent -WarningAction SilentlyContinue

Write-Output "New Management Group Structure has been created for Management Group '$($managementGroupName)'"
Write-Output "$($prodGroup.DisplayName) with the Id $($prodGroup.Name)"
Write-Output "$($nonProdGroup.DisplayName) with the Id $($nonProdGroup.Name)"

