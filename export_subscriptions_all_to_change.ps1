Function Login {
    $needLogin = $true
    Try {
        $content = Get-AzContext
        if ($content) {
            $needLogin = ([string]::IsNullOrEmpty($content.Account))
        } 
    } 
    Catch {
        if ($_ -like "*Login-AzAccount to login*") {   
            $needLogin = $true
        } 
        else {
            Write-Host "You are already logged in to Azure, that's good."
            throw
        }
    }
    if ($needLogin) {
        Write-Host "You need to login to Azure"
        Login-AzAccount
    }
}
if ( (Get-Module | where-Object { $_.Name -like "AzureAD.Standard.Preview" }).Count ) {
    Write-Host "You are on Azure Shell"
}
else {
    Write-Host "You are working locally"
    Import-Module AzureAD -ErrorAction SilentlyContinue | Out-Null 
    If ( !(Get-Module | where-Object { $_.Name -like "AzureAD" }).Count ) { Install-Module AzureAD -scope CurrentUser }
    Import-Module Az.Resources -ErrorAction SilentlyContinue | Out-Null 
    If ( !(Get-Module | where-Object { $_.Name -like "Az.Resources" }).Count ) { Install-Module Az -scope CurrentUser }
    Login
}
$currentDate = $((Get-Date).ToString('yyyy-MM-dd--hh-mm')) + "_subscriptions_all"
Write-Host "Creating a Sub Folder for the output files"
Try {
    New-Item -ItemType Directory -Path ".\$currentDate" | Out-Null
    $outputPath = ".\$currentDate"
} 
Catch {
    Write-Output "Failed to create the output folder, please check your permissions"
}
$AllSubscriptions = @()
$counter = 0
$subs = Get-AzSubscription 
$subs = $subs | sort-object Name
$subs = $subs | sort-object TenantId
Foreach ($sub in $subs) {
    if ($sub.Name -notlike "Access to Azure Active Directory*" -And $sub.Name -notlike "Zugriff auf Azure Active Directory*") {
        $tenantName = $sub.TenantId
        $Current = [ordered]@{'SubscriptionName' = $sub.name; 'SubscriptionID' = $sub.id; 'SubscriptionStatus' = $sub.state; 'Tenant' = $tenantName }
        $AllSubscriptions += New-Object PSObject -Property $Current
        Write-Host $sub.name
        $counter++ 
    }
}
Write-Host -ForegroundColor Yellow "`nAnzahl Subscriptions: $counter`n"
$AllSubscriptions | Export-CSV "$outputPath\$currentDate.csv" -Delimiter ';' -force -notypeinformation
$a = "<style>"
$a = $a + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;font-family:arial}"
$a = $a + "TH{border-width: 1px;padding: 5px;border-style: solid;border-color: black;}"
$a = $a + "TD{border-width: 1px;padding: 5px;border-style: solid;border-color: black;}"
$a = $a + "</style>"
$AllSubscriptions | ConvertTo-Html -Head $a | Out-file "$outputPath\$currentDate.html"