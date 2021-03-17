param (
    [parameter(Mandatory)]
    $AADEmailAdress
)
function Get-EmailValidation {
    param([string]$EmailAddress)

    try {
        $null = [mailaddress]$EmailAddress
        return $true
    }
    catch {
        return $false
    }
}
function Get-RandomCharacter($length, $characters) {
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
    $private:ofs = ""
    return [String]$characters[$random]
}
function Get-RandomPassword {
    $password = Get-RandomCharacter -length 5 -characters 'abcdefghiklmnoprstuvwxyz'
    $password += Get-RandomCharacter -length 1 -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
    $password += Get-RandomCharacter -length 1 -characters '1234567890'
    $password += Get-RandomCharacter -length 1 -characters '!"§$%&/()=?}][{@#*+'
}
function Get-ScrambleString([string]$inputString) {
    $characterArray = $inputString.ToCharArray()
    $scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length
    $outputString = -join $scrambledStringArray
    return $outputString
}
$context = $null
try {
    $context = Get-AzureADCurrentSessionInfo -ErrorAction SilentlyContinue
}
catch {
    Write-Host "You're curenntly not connected to Azure Active Directory. Please Login..." -ForegroundColor Yellow
}
if (!$context) {
    try {
        $context = Connect-AzureAD
    }
    catch {
        Write-Host "Login Failed!" -ForegroundColor Red
        exit 0
    }
    
}
$password = Get-RandomCharacter -length 8 -characters 'abcdefghiklmnoprstuvwxyz'
$password += Get-RandomCharacter -length 3 -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
$password += Get-RandomCharacter -length 2 -characters '1234567890'
$password += Get-RandomCharacter -length 2 -characters '!"§$%&/()=?}][{@#*+'

$emailIsValid = Get-EmailValidation -EmailAddress $AADEmailAdress
if ($emailIsValid) {
    $ADUser = Get-AzureADUser -SearchString $AADEmailAdress
}
else {
    Write-Host "$([char]034)$($AADEmailAdress)$([char]034) is not a valid Email-Address Format!" -ForegroundColor Red
}
if ($ADUser) {
    $adminAccountUserPrincipalSearchString = ($ADUser.userPrincipalName -split ("@"))[0]
    $AadUser = Get-AzureADUser -Filter "startswith(userPrincipalName,'adm_$($adminAccountUserPrincipalSearchString)')"
}
else {
    Write-Host "A user, with the Email-Address $([char]034)$($AADEmailAdress)$([char]034) could not be found!" -ForegroundColor Red
    exit 0
}
if ($AadUser) {
    Write-Host "Admin Account ($($AadUser.userPrincipalName)) already available!" -ForegroundColor Yellow
    exit 0
}
$action = Read-Host "$($ADUser.GivenName) $($ADUser.Surname) $([char]034)$($AADEmailAdress)$([char]034) does not have an Admin Account yet. You what to create one? (Yes / No = Default)"
if ($action.ToLower() -like 'y*') {
    $PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
    $genaratedPassword = Get-ScrambleString -inputString $password
    $PasswordProfile.Password = $genaratedPassword
    $PasswordProfile.ForceChangePasswordNextLogin = $true

    if ($ADUser.GivenName) {
        $GivenName = (Get-Culture).TextInfo.ToTitleCase($ADUser.GivenName.ToLower())
    }
    if ($ADUser.Surname) {
        $Surname = (Get-Culture).TextInfo.ToTitleCase($ADUser.Surname.ToLower())
    }
    if (((($adminAccountUserPrincipalSearchString -split ('#'))[0] -split ('_'))[0]) -and (!$GivenName) -and (!$Surname)) {
        $AdminAccountUserPrincipal = (($adminAccountUserPrincipalSearchString -split ('#'))[0] -split ('_'))[0]
        $CompanyDomain = (($adminAccountUserPrincipalSearchString -split ('#'))[0] -split ('_'))[1]
        $CompanyName = (Get-Culture).TextInfo.ToTitleCase($CompanyDomain.Substring(0, $CompanyDomain.lastIndexOf('.')).ToLower())
        $UserPrincipalName = "adm_$($AdminAccountUserPrincipal)@$($context.TenantDomain)".ToLower()
        $mailNickname = "adm_$($AdminAccountUserPrincipal)".ToLower()
        $OtherMails = $ADUser.OtherMails
    }
    else {
        $UserPrincipalName = "adm_$($GivenName).$($Surname)@$($context.TenantDomain)".ToLower()
        $mailNickname = "adm_$($GivenName).$($Surname)"
        $OtherMails = $ADUser.UserPrincipalName.ToLower()
        $CompanyName = $ADUser.CompanyName
    }
    if ($adminAccountUserPrincipalSearchString -match 'EXT') {
        $ext = '#EXT' 
    }
    else {
        $ext = $null
    }
    if ($CompanyName) {
        $DisplayName = $ADUser.DisplayName + " ($($CompanyName)) - Admin$($ext)"
    }
    else {
        $DisplayName = $ADUser.DisplayName + " - Admin$($ext)"
    }
    
    try {

        $Account = New-AzureADUser `
            -UserPrincipalName $UserPrincipalName.ToLower() `
            -DisplayName $DisplayName `
            -mailNickname $mailNickname `
            -PasswordProfile $PasswordProfile `
            -GivenName $GivenName `
            -Surname $Surname `
            -Mobile $ADUser.Mobile `
            -TelephoneNumber $ADUser.TelephoneNumber  `
            -OtherMails $OtherMails `
            -Department $ADUser.Department `
            -CompanyName $CompanyName `
            -Country $ADUser.Country `
            -PhysicalDeliveryOfficeName $ADUser.PhysicalDeliveryOfficeName `
            -StreetAddress $ADUser.StreetAddress `
            -PostalCode $ADUser.PostalCode `
            -AccountEnabled $true
        Write-Host "Admin account successfully created!" -ForegroundColor green
        Write-Host "UserPrincipalName: $($Account.UserPrincipalName)" -ForegroundColor Yellow
        Write-Host "Temporary Password: $($genaratedPassword)" -ForegroundColor Yellow
        Write-Host "DisplayName: $($Account.DisplayName)" -ForegroundColor Yellow
        Write-Host "ObjectId: $($Account.ObjectId)" -ForegroundColor Yellow
        Write-Host "Please sigin to https://myaccount.microsoft.com/ to change your password and setup MFA." -ForegroundColor Yellow

    }
    catch {
        Write-Host "An error occurred:" -ForegroundColor Red
        Write-Host $_ -ForegroundColor Red
    }
}