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
function Get-RandomCharacters($length, $characters) { 
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length } 
    $private:ofs = "" 
    return [String]$characters[$random]
}
function Get-RandomPassword {
    $password = Get-RandomCharacters -length 5 -characters 'abcdefghiklmnoprstuvwxyz'
    $password += Get-RandomCharacters -length 1 -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
    $password += Get-RandomCharacters -length 1 -characters '1234567890'
    $password += Get-RandomCharacters -length 1 -characters '!"§$%&/()=?}][{@#*+'    
}
function Get-ScrambleString([string]$inputString) {     
    $characterArray = $inputString.ToCharArray()   
    $scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length     
    $outputString = -join $scrambledStringArray
    return $outputString 
}
$password = Get-RandomCharacters -length 5 -characters 'abcdefghiklmnoprstuvwxyz'
$password += Get-RandomCharacters -length 1 -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
$password += Get-RandomCharacters -length 1 -characters '1234567890'
$password += Get-RandomCharacters -length 1 -characters '!"§$%&/()=?}][{@#*+'

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

    $GivenName = (Get-Culture).TextInfo.ToTitleCase($ADUser.GivenName.ToLower())
    $Surname = (Get-Culture).TextInfo.ToTitleCase($ADUser.Surname.ToLower())
    $UserPrincipalName = "adm_$($GivenName).$($Surname)@lufthansagroup.onmicrosoft.com".ToLower()
    $DisplayName = $ADUser.DisplayName + " - Admin"
    try {

        $Account = New-AzureADUser `
            -UserPrincipalName $UserPrincipalName.ToLower() `
            -DisplayName $DisplayName `
            -mailNickname "adm_$($GivenName).$($Surname)".ToLower() `
            -PasswordProfile $PasswordProfile `
            -GivenName $GivenName `
            -Surname $Surname `
            -Mobile $ADUser.Mobile `
            -TelephoneNumber $ADUser.TelephoneNumber  `
            -OtherMails $ADUser.UserPrincipalName.ToLower() `
            -Department $ADUser.Department `
            -CompanyName $ADUser.CompanyName `
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
        Write-Host "Please sigin to https://myaccount.microsoft.com/ to change to password and setup MFA." -ForegroundColor Yellow
        
    }
    catch {
        Write-Host "An error occurred:" -ForegroundColor Red
        Write-Host $_ -ForegroundColor Red
    }
}