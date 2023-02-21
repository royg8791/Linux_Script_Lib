# Creates file with List including USERs that didn't LOGON in the past 90 DAYS
# the list refers to AD (in egged) and Exchange Online (365)

$userName = 'powershell@Egged.co.il'

$securePwd = "Qar^P:'!!Q"

$Creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $userName, (ConvertTo-SecureString -String $securePwd -AsPlainText -Force)

Connect-ExchangeOnline -Credential $Creds

# Output File
$output_file = "users_to_disable.csv"
# Headers
# write-output "User_Principal_Name`tLast_Logon_Time`tNotes`tDisplay_Name" > $output_file
Write-Output "SamAccountName" > $output_file

# Time Frame to Exclude
$90Days = ((Get-Date).AddDays(-90)).Date

# Get list of users from AD that didn't connect in the past 90 Days
$ADInactiveLast90Days = Get-ADUser -Filter {EmployeeID -ne 'null' -and EmailAddress -ne 'null' -and LastLogonDate -lt $90Days
                        -and Enabled -eq 'True' -and PasswordNeverExpires -eq 'False' -and mailnickname -ne 'Museum_Egged' -and mailnickname -ne 'Somech'} -Properties * |
                        Select-Object SamAccountName,EmailAddress,UserPrincipalName,EmployeeID,LastLogonDate,displayname | Sort-Object LastLogonDate

# Check if AD list (from above) didn't connect to Exchange Online (Microsoft) in past 90 Days
$ADInactiveLast90Days | ForEach-Object {
    $UPN = $_.UserPrincipalName
    $SAN = $_.SamAccountName
    if (Get-ExoMailbox -Filter "UserPrincipalName -EQ '$UPN'") {
        $LLT = (Get-ExoMailboxStatistics -Identity "$UPN" -PropertySets All |
        Where-Object LastLogonTime -LE $90Days).LastLogonTime
        # $DN = $_.displayname
        # if ($LLT) {Write-Output "$UPN`t$LLT`t`t$DN" >> $output_file}
        if ($LLT) {Write-Output "$SAN" >> $output_file}
    }else {
        $LLT = $_.LastLogonDate
        # $DN = $_.displayname
        # write-output "$UPN`t$LLT`t**NO_365_MAILBOX`t$DN" >> $output_file
        write-output "$SAN" >> $output_file
    }
}

##AFTER APPROVING THE INACTIVE USERS LIST - DISABLE THEM##

Import-Csv -Path $output_file |
ForEach-Object {Get-ADUser -Identity $_.SamAccountName |
    Disable-ADAccount}
