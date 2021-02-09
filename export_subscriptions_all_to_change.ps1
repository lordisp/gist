# Login Function (needed only locally)
Function Login
{
    $needLogin = $true

    # checking the Az connection if login is needed
    Try 
    {
        $content = Get-AzContext
        if ($content) 
        {
            $needLogin = ([string]::IsNullOrEmpty($content.Account))
        } 
    } 
    Catch 
    {
        if ($_ -like "*Login-AzAccount to login*") 
        {   
            $needLogin = $true
        } 
        else 
        {
            Write-Host "You are already logged in to Azure, that's good."
            throw
        }
    }

    if ($needLogin)
    {
        Write-Host "You need to login to Azure"
        Login-AzAccount
    }

    # Checking the Azure AD connection and if login is needed
    #try { 
    #    Get-AzureADTenantDetail 
    #}
    #catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] { 
    #    Write-Host "You're not connected to the Azure AD."
    #    Connect-AzureAD
    #}

}

#checking if you are on Azure Shell
if ( (Get-Module | where-Object {$_.Name -like "AzureAD.Standard.Preview"}).Count ) {
    Write-Host "You are on Azure Shell"
}
else {
    Write-Host "You are working locally"
    # checking if you have the needed modules installed
    # check for and install the AzureAD if needed
    Import-Module AzureAD -ErrorAction SilentlyContinue | Out-Null 
    If ( !(Get-Module | where-Object {$_.Name -like "AzureAD"}).Count ) { Install-Module AzureAD -scope CurrentUser }

    # check for and install the Az if needed
    Import-Module Az.Resources -ErrorAction SilentlyContinue | Out-Null 
    If ( !(Get-Module | where-Object {$_.Name -like "Az.Resources"}).Count ) { Install-Module Az -scope CurrentUser}

    # Loggin in to Azure (if needed)
    Login
}

#Setting the current date and time for folder creating
$currentDate = $((Get-Date).ToString('yyyy-MM-dd--hh-mm')) + "_subscriptions_all"

#creating a sub folder for the output.
Write-Host "Creating a Sub Folder for the output files"
Try {
    New-Item -ItemType Directory -Path ".\$currentDate" | Out-Null
    # setting the path
    $outputPath = ".\$currentDate"
} 
Catch {
    Write-Output "Failed to create the output folder, please check your permissions"
}

<#
#creating a sub folder for the groups.
Write-Host "Creating a Sub Folder for the groups output files"
Try {
    New-Item -ItemType Directory -Path ".\$currentDate\groups"  | Out-Null
    # setting the path
    $groupsPath = ".\$currentDate\groups"
} 
Catch {
    Write-Output "Failed to create the groups sub folder, please check your permissions"
}

#creating a sub folder for the subscriptions one by one.
Write-Host "Creating a Sub Folder for the subscriptions one by one output files"
Try {
    New-Item -ItemType Directory -Path ".\$currentDate\subscriptions_one_by_one"  | Out-Null
    # setting the path
    $subsPath = ".\$currentDate\subscriptions_one_by_one"
} 
Catch {
    Write-Output "Failed to create the groups sub folder, please check your permissions"
}
#>

# Export Role Assignments for all subscriptions the user has access to

    $AllSubscriptions = @()
	$counter=0
    $subs = Get-AzSubscription #| Where-Object {$_.Name -notlike "*_MS_*"}
    $subs = $subs | sort-object Name
	$subs = $subs | sort-object TenantId
    #Loop through each Azure subscription user has access to
    Foreach ($sub in $subs) {
        #$SubName = $sub.Name
        if ($sub.Name -notlike "Access to Azure Active Directory*" -And $sub.Name -notlike "Zugriff auf Azure Active Directory*") { # You can't assign roles in Access to Azure Active Directory subscriptions
            #Set-AzContext -SubscriptionId $sub.id
            $tenantName = $sub.TenantId


            #Write-Host "Getting Infos on $subname"
            #Write-Host ""
            #Try {
                #############################################################################################################################
                #### Modify this line to filter what you want in your results, currently only Owners or Admins will be expoted.
                #############################################################################################################################
                #$Current = @($sub.name, $sub.id, $sub.state, $tenantName)

				$Current = [ordered]@{'SubscriptionName' = $sub.name; 'SubscriptionID' = $sub.id; 'SubscriptionStatus' = $sub.state; 'Tenant' =  $tenantName}

                $AllSubscriptions += New-Object PSObject -Property $Current
				Write-Host $sub.name
				$counter++ 
            #} 
            #Catch {
            #    Write-Output "Failed to get Infos on $subname"
            #}
        }
    }
	
	Write-Host -ForegroundColor Yellow "`nAnzahl Subscriptions: $counter`n"
    #Export All Role Assignments in to a single CSV file
    $AllSubscriptions | Export-CSV "$outputPath\$currentDate.csv" -Delimiter ';' -force -notypeinformation

    # HTML report
    $a = "<style>"
    $a = $a + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;font-family:arial}"
    $a = $a + "TH{border-width: 1px;padding: 5px;border-style: solid;border-color: black;}"
    $a = $a + "TD{border-width: 1px;padding: 5px;border-style: solid;border-color: black;}"
    $a = $a + "</style>"
    $AllSubscriptions | ConvertTo-Html -Head $a| Out-file "$outputPath\$currentDate.html"